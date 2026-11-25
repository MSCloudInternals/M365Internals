import assert from "node:assert/strict";
import childProcess from "node:child_process";
import { EventEmitter } from "node:events";
import { syncBuiltinESMExports } from "node:module";
import { PassThrough } from "node:stream";
import test from "node:test";
import { ReadOnlyBridge } from "../dist/bridge.js";

function fakeProcess(t, respond) {
  let child;
  const replacement = t.mock.method(childProcess, "spawn", () => {
    child = new EventEmitter();
    child.stdout = new PassThrough();
    child.stderr = new PassThrough();
    child.stdin = new PassThrough();
    child.killed = false;
    child.kill = () => {
      if (!child.killed) {
        child.killed = true;
        child.emit("exit", null, "SIGTERM");
        child.emit("close", null, "SIGTERM");
      }
      return true;
    };
    child.stdin.on("data", (chunk) => {
      const request = JSON.parse(chunk.toString());
      respond?.(child, request);
    });
    return child;
  });
  syncBuiltinESMExports();
  t.after(() => {
    replacement.mock.restore();
    syncBuiltinESMExports();
  });
  return () => child;
}

const turn = () => new Promise((resolve) => setImmediate(resolve));

test("bridge accepts fragmented JSON frames and serializes concurrent calls", async (t) => {
  let active = 0;
  let maxActive = 0;
  fakeProcess(t, (child, request) => {
    active++;
    maxActive = Math.max(maxActive, active);
    const response = JSON.stringify({ id: request.id, ok: true, data: { synthetic: true } }) + "\n";
    child.stdout.write(response.slice(0, 9));
    setImmediate(() => { active--; child.stdout.write(response.slice(9)); });
  });
  const bridge = new ReadOnlyBridge({});
  const results = await Promise.all(Array.from({ length: 8 }, () => bridge.invoke("domains", {})));
  assert.equal(maxActive, 1);
  assert.equal(results.length, 8);
  assert.ok(results.every((result) => result.synthetic));
  await bridge.close();
});

for (const [label, frame] of [
  ["malformed JSON", () => "{\n"],
  ["non-object", () => "null\n"],
  ["wrong ID", () => '{"id":"wrong","ok":true,"data":null}\n'],
  ["extra key", (id) => JSON.stringify({ id, ok: true, data: null, extra: true }) + "\n"],
  ["wrong ok type", (id) => JSON.stringify({ id, ok: "true", data: null }) + "\n"],
  ["unknown error", (id) => JSON.stringify({ id, ok: false, error: "synthetic private detail" }) + "\n"],
  ["oversized complete frame", () => `"${"x".repeat(256 * 1024)}"\n`],
  ["oversized unterminated frame", () => "x".repeat(256 * 1024 + 1)],
]) {
  test(`bridge closes on ${label}`, async (t) => {
    const current = fakeProcess(t, (child, request) => child.stdout.write(frame(request.id)));
    const bridge = new ReadOnlyBridge({});
    await assert.rejects(bridge.invoke("domains", {}), { message: "invalid_response" });
    assert.equal(current().killed, true);
    await assert.rejects(bridge.invoke("domains", {}), { message: "session_lost" });
    await bridge.close();
  });
}

test("bridge revokes after not_connected but not after a not_found response", async (t) => {
  let calls = 0;
  const current = fakeProcess(t, (child, request) => {
    calls++;
    child.stdout.write(JSON.stringify({ id: request.id, ok: false, error: calls === 1 ? "not_found" : "not_connected" }) + "\n");
  });
  const bridge = new ReadOnlyBridge({});
  await assert.rejects(bridge.invoke("domains", {}), { message: "not_found" });
  assert.equal(current().killed, false);
  await assert.rejects(bridge.invoke("domains", {}), { message: "not_connected" });
  assert.equal(current().killed, true);
  await bridge.close();
});

test("bridge kills the active process and rejects queued work on cancellation", async (t) => {
  const current = fakeProcess(t);
  const bridge = new ReadOnlyBridge({});
  const controller = new AbortController();
  const active = assert.rejects(bridge.invoke("domains", {}, controller.signal), { message: "request_cancelled" });
  const queued = assert.rejects(bridge.invoke("domains", {}), { message: "session_lost" });
  await turn();
  controller.abort();
  await Promise.all([active, queued]);
  assert.equal(current().killed, true);
  await bridge.close();
});

test("bridge enforces the six-minute first-call deadline", async (t) => {
  t.mock.timers.enable({ apis: ["Date", "setTimeout"] });
  const current = fakeProcess(t);
  const bridge = new ReadOnlyBridge({});
  const result = assert.rejects(bridge.invoke("domains", {}), { message: "session_timed_out" });
  await turn();
  t.mock.timers.tick(360_001);
  await result;
  assert.equal(current().killed, true);
  await bridge.close();
});

test("bridge enforces the 60-second read deadline after startup", async (t) => {
  t.mock.timers.enable({ apis: ["Date", "setTimeout"] });
  let calls = 0;
  const current = fakeProcess(t, (child, request) => {
    if (++calls === 1) child.stdout.write(JSON.stringify({ id: request.id, ok: true, data: null }) + "\n");
  });
  const bridge = new ReadOnlyBridge({});
  await bridge.invoke("domains", {});
  const result = assert.rejects(bridge.invoke("domains", {}), { message: "session_timed_out" });
  await turn();
  t.mock.timers.tick(60_001);
  await result;
  assert.equal(current().killed, true);
  await bridge.close();
});

test("calls queued during sign-in retain the six-minute deadline", async (t) => {
  t.mock.timers.enable({ apis: ["Date", "setTimeout"] });
  let firstId;
  const current = fakeProcess(t, (child, request) => {
    if (!firstId) firstId = request.id;
    else child.stdout.write(JSON.stringify({ id: request.id, ok: true, data: null }) + "\n");
  });
  const bridge = new ReadOnlyBridge({});
  const first = bridge.invoke("domains", {});
  await turn();
  const queued = bridge.invoke("domains", {});
  t.mock.timers.tick(61_000);
  current().stdout.write(JSON.stringify({ id: firstId, ok: true, data: null }) + "\n");
  assert.deepEqual(await Promise.all([first, queued]), [null, null]);
  assert.equal(current().killed, false);
  await bridge.close();
});

test("expired queued work revokes the process instead of leaving a usable session", async (t) => {
  t.mock.timers.enable({ apis: ["Date", "setTimeout"] });
  let activeId;
  let calls = 0;
  const current = fakeProcess(t, (child, request) => {
    if (++calls === 1) child.stdout.write(JSON.stringify({ id: request.id, ok: true, data: null }) + "\n");
    else activeId = request.id;
  });
  const bridge = new ReadOnlyBridge({});
  await bridge.invoke("domains", {});
  const active = bridge.invoke("domains", {});
  await turn();
  const queued = assert.rejects(bridge.invoke("domains", {}), { message: "session_timed_out" });
  t.mock.timers.setTime(60_001);
  current().stdout.write(JSON.stringify({ id: activeId, ok: true, data: null }) + "\n");
  await active;
  await queued;
  assert.equal(current().killed, true);
  await bridge.close();
});

test("bridge closes on process failure without leaking the exception", async (t) => {
  const current = fakeProcess(t);
  const bridge = new ReadOnlyBridge({});
  const result = assert.rejects(bridge.invoke("domains", {}), { message: "session_lost" });
  await turn();
  current().emit("error", new Error("synthetic private process error"));
  await result;
  await bridge.close();
});
