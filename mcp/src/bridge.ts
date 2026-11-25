import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { fileURLToPath } from "node:url";
import { errorCodes, validateArguments } from "./contracts.js";

export class BridgeError extends Error {
  constructor(readonly code: string) { super(code); }
}

const frameLimit = 256 * 1024;

export class ReadOnlyBridge {
  private child?: ChildProcessWithoutNullStreams;
  private closed = false;
  private ready = false;
  private nextId = 0;
  private outstanding = 0;
  private queue: Promise<void> = Promise.resolve();
  private exited: Promise<void> = Promise.resolve();
  private pending?: {
    id: string;
    resolve: (value: unknown) => void;
    reject: (error: Error) => void;
    timer: NodeJS.Timeout;
  };

  constructor(private readonly env: NodeJS.ProcessEnv = process.env) {}

  private start(): ChildProcessWithoutNullStreams {
    if (this.closed) throw new BridgeError("session_lost");
    if (this.child) return this.child;
    const child = spawn("pwsh", [
      "-NoLogo", "-NoProfile", "-NonInteractive", "-File",
      fileURLToPath(new URL("../bridge/ReadOnlyHost.ps1", import.meta.url)),
    ], { stdio: "pipe", windowsHide: true, env: this.env });
    this.child = child;
    this.exited = new Promise((resolve) => child.once("close", resolve));
    let buffer = "";
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      buffer += chunk;
      let newline: number;
      while ((newline = buffer.indexOf("\n")) !== -1) {
        const line = buffer.slice(0, newline);
        buffer = buffer.slice(newline + 1);
        if (Buffer.byteLength(line + "\n") > frameLimit) {
          this.stop("invalid_response");
          return;
        }
        this.receive(line);
        if (this.closed) return;
      }
      if (Buffer.byteLength(buffer) > frameLimit) this.stop("invalid_response");
    });
    // PowerShell diagnostics can contain session material; never forward them to a client.
    child.stderr.resume();
    child.on("error", () => this.stop("session_lost"));
    child.on("exit", () => this.stop("session_lost"));
    child.stdin.on("error", () => this.stop("session_lost"));
    return child;
  }

  private receive(line: string): void {
    const envelope = (() => {
      try { return JSON.parse(line) as unknown; }
      catch { return undefined; }
    })();
    if (!envelope || typeof envelope !== "object" || Array.isArray(envelope)) {
      this.stop("invalid_response");
      return;
    }
    const value = envelope as Record<string, unknown>;
    const keys = Object.keys(value).sort().join(",");
    const valid = typeof value.id === "string" && typeof value.ok === "boolean" &&
      (value.ok ? keys === "data,id,ok" : keys === "error,id,ok" &&
        typeof value.error === "string" && errorCodes.has(value.error));
    if (!valid || !this.pending || value.id !== this.pending.id) {
      this.stop("invalid_response");
      return;
    }
    const pending = this.pending;
    this.pending = undefined;
    clearTimeout(pending.timer);
    this.ready = true;
    if (value.ok) pending.resolve(value.data);
    else {
      pending.reject(new BridgeError(String(value.error)));
      if (value.error === "not_connected") this.stop("session_lost");
    }
  }

  private stop(code: string): void {
    this.closed = true;
    const child = this.child;
    this.child = undefined;
    const pending = this.pending;
    this.pending = undefined;
    if (pending) {
      clearTimeout(pending.timer);
      pending.reject(new BridgeError(code));
    }
    child?.kill();
  }

  async invoke(operation: string, args: Record<string, string>, signal?: AbortSignal): Promise<unknown> {
    try { validateArguments(operation, args); }
    catch (error) {
      throw new BridgeError(error instanceof Error ? error.message : "invalid_arguments");
    }
    if (this.closed) throw new BridgeError("session_lost");
    if (signal?.aborted) throw new BridgeError("request_cancelled");
    if (this.outstanding >= 8) throw new BridgeError("server_busy");
    // Queue deadlines include the first sign-in, even for calls queued behind it.
    const deadline = Date.now() + (!this.ready ? 360_000 : 60_000);
    this.outstanding++;
    const run = async () => {
      if (this.closed) throw new BridgeError("session_lost");
      if (signal?.aborted) throw new BridgeError("request_cancelled");
      const remaining = deadline - Date.now();
      if (remaining <= 0) {
        this.stop("session_timed_out");
        throw new BridgeError("session_timed_out");
      }
      const child = this.start();
      const id = String(++this.nextId);
      const cancel = () => this.stop("request_cancelled");
      signal?.addEventListener("abort", cancel, { once: true });
      try {
        if (signal?.aborted) {
          cancel();
          throw new BridgeError("request_cancelled");
        }
        return await new Promise<unknown>((resolve, reject) => {
          const timer = setTimeout(() => this.stop("session_timed_out"), remaining);
          this.pending = { id, resolve, reject, timer };
          child.stdin.write(`${JSON.stringify({ id, operation, args })}\n`, (error) => {
            if (error) this.stop("session_lost");
          });
        });
      } finally {
        signal?.removeEventListener("abort", cancel);
      }
    };
    const result = this.queue.then(run);
    this.queue = result.then(() => {}, () => {});
    return result.finally(() => { this.outstanding--; });
  }

  async close(): Promise<void> {
    this.stop("session_lost");
    await this.exited;
  }
}
