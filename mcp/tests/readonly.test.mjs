import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { readFileSync } from "node:fs";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { createServer } from "../dist/index.js";
import { BridgeError, ReadOnlyBridge } from "../dist/bridge.js";
import { inputSchema, outputSchema, tools, validateArguments } from "../dist/contracts.js";

const hostPath = fileURLToPath(new URL("../bridge/ReadOnlyHost.ps1", import.meta.url));
const fixturePath = fileURLToPath(new URL("./fixtures/FakeM365.psm1", import.meta.url));
const env = (fixture = "normal") => ({
  ...process.env,
  M365_MCP_AUTH: "software-passkey",
  M365_MCP_PASSKEY_FILE: fixturePath,
  M365_MCP_FIXTURE: fixture,
});

class Host {
  constructor(fixture = "normal", overrides = {}) {
    this.child = spawn("pwsh", [
      "-NoLogo", "-NoProfile", "-NonInteractive", "-File", hostPath, "-ModulePath", fixturePath,
    ], { stdio: "pipe", windowsHide: true, env: { ...env(fixture), ...overrides } });
    this.closed = once(this.child, "close");
    this.lines = createInterface({ input: this.child.stdout })[Symbol.asyncIterator]();
    this.stderr = "";
    this.child.stderr.setEncoding("utf8").on("data", (chunk) => { this.stderr += chunk; });
    this.id = 0;
  }
  async raw(request) {
    this.child.stdin.write(`${typeof request === "string" ? request : JSON.stringify(request)}\n`);
    const line = await this.lines.next();
    assert.equal(line.done, false, `Host exited: ${this.stderr}`);
    assert.ok(Buffer.byteLength(line.value + "\n") <= 256 * 1024);
    return JSON.parse(line.value);
  }
  async invoke(operation, args) {
    const response = await this.raw({ id: String(++this.id), operation, args });
    if (!response.ok) throw new BridgeError(response.error);
    return response.data;
  }
  async close() {
    this.child.stdin.end();
    await this.closed;
    assert.equal(this.child.exitCode, 0);
    assert.doesNotMatch(this.stderr, /synthetic private|synthetic credential|synthetic sensitive/);
  }
}

async function session(t, bridge) {
  const server = createServer(bridge);
  const client = new Client({ name: "offline-tests", version: "1.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await server.connect(serverTransport);
  await client.connect(clientTransport);
  t.after(async () => { await client.close(); await server.close(); });
  return client;
}

const cases = tools.flatMap((tool) => tool.sections ?
  Object.entries(tool.sections).map(([section, path]) => ({ tool, args: { section }, path })) :
  [{ tool, args: tool.domain ? { domain: "example.com" } : {}, path: tool.path + (tool.domain ? "?domainName=example.com" : "") }]);

test("catalog contains nine named tools and only existing module GET routes", () => {
  assert.equal(tools.length, 9);
  assert.equal(new Set(tools.map((tool) => tool.operation)).size, tools.length);
  assert.equal(new Set(tools.map((tool) => tool.name)).size, tools.length);
  const moduleFiles = [
    "Get-M365AdminCompanySetting", "Get-M365AdminSecuritySetting", "Get-M365AdminReportSetting",
    "Get-M365AdminTenantSetting", "Get-M365AdminService", "Get-M365AdminAgentTool",
    "Get-M365AdminCopilotPinPolicy", "Get-M365AdminDomain",
  ].map((name) => readFileSync(new URL(`../../M365Internals/functions/${name}.ps1`, import.meta.url), "utf8")).join("\n");
  for (const { path } of cases) {
    assert.match(path, /^\/admin\/api\//);
    assert.ok(moduleFiles.includes(path.split("?")[0]), `No existing module route for ${path}`);
  }
  assert.ok(cases.every(({ path }) => !/CheckDns|Export|optIn|GetGroups/i.test(path)));
});

for (let pass = 1; pass <= 2; pass++) {
  test(`fresh offline MCP session ${pass} exercises every tool and section`, { timeout: 60_000 }, async (t) => {
    const host = new Host();
    t.after(() => host.close());
    const client = await session(t, host);
    const catalog = await client.listTools();
    assert.equal(catalog.tools.length, tools.length);
    for (const item of catalog.tools) {
      assert.equal(item.annotations.readOnlyHint, true);
      assert.equal(item.annotations.destructiveHint, false);
      assert.equal(item.annotations.openWorldHint, true);
      assert.equal(item.inputSchema.additionalProperties, false);
      assert.ok(item.outputSchema);
    }
    for (const { tool, args, path } of cases) {
      const result = await client.callTool({ name: tool.name, arguments: args });
      assert.equal(result.isError, undefined, `${tool.name}: ${JSON.stringify(result.content)}`);
      const data = outputSchema.parse(result.structuredContent);
      assert.equal(data.surface, tool.operation);
      assert.equal(data.section, args.section ?? null);
      assert.equal(data.status, "ok");
      assert.equal(data.truncated, false);
      assert.equal(data.data.uri, `https://admin.cloud.microsoft${path}`);
      assert.equal(data.data.method, "Get");
      assert.equal(data.data.observed, "2026-01-01T00:00:00Z");
      assert.equal(data.data.items.length, 1);
      if (/datalocation/i.test(path)) assert.match(data.data.context, /DataLocation$/);
      assert.deepEqual(JSON.parse(result.content[0].text), data);
    }
  });
}

test("TypeScript rejects writes, unknown operations, extra keys, wrong casing and unsafe domains", () => {
  for (const operation of ["set_security_setting", "invoke_rest", "Security_Setting", "__proto__"]) {
    assert.throws(() => validateArguments(operation, {}), /operation_not_allowed/);
  }
  for (const args of [
    { section: "SecurityDefaults", uri: "https://example.com" },
    { Section: "SecurityDefaults" }, { section: "securitydefaults" }, { section: 1 },
    { section: "All" }, null, [],
  ]) assert.throws(() => validateArguments("security_setting", args), /invalid_arguments/);
  for (const domain of ["https://example.com", "example.com?x=1", "../example.com", "a;Write-Host", "-a.com", "a..com", "localhost", "a.com\n", "x".repeat(254), "a.1", "a_b.com"]) {
    assert.equal(inputSchema(tools.find((tool) => tool.domain)).safeParse({ domain }).success, false, domain);
  }
  assert.deepEqual(validateArguments("domain_records", { domain: "EXAMPLE.com" }), { domain: "EXAMPLE.com" });
});

test("PowerShell independently rejects invalid requests before authentication", { timeout: 30_000 }, async (t) => {
  const host = new Host("auth-failure");
  t.after(() => host.close());
  for (const [operation, args, error] of [
    ["set_security_setting", {}, "operation_not_allowed"],
    ["invoke_rest", { uri: "https://example.com" }, "operation_not_allowed"],
    ["Security_Setting", {}, "operation_not_allowed"],
    ["security_setting", { section: "All" }, "invalid_arguments"],
    ["security_setting", { section: "securitydefaults" }, "invalid_arguments"],
    ["security_setting", { Section: "SecurityDefaults" }, "invalid_arguments"],
    ["security_setting", { section: "SecurityDefaults", tenantId: "synthetic" }, "invalid_arguments"],
    ["security_setting", { section: 1 }, "invalid_arguments"],
    ["security_setting", null, "invalid_arguments"],
    ["security_setting", [], "invalid_arguments"],
    ["domains", { Force: true }, "invalid_arguments"],
    ["domain_records", { domain: "example.com?x=1" }, "invalid_arguments"],
    ["domain_records", { domain: "a.com\n" }, "invalid_arguments"],
    ["domain_records", { domain: "https://example.com" }, "invalid_arguments"],
  ]) {
    const response = await host.raw({ id: "1", operation, args });
    assert.equal(response.error, error);
  }
  for (const request of [
    "{", "[]", "null", { id: 1, operation: "domains", args: {} },
    { id: "1", Operation: "domains", args: {} }, { id: "1", operation: "domains", args: {}, extra: true },
    { id: "1\n", operation: "domains", args: {} }, "x".repeat(8193),
  ]) assert.equal((await host.raw(request)).error, "invalid_request");
  assert.equal(host.stderr, "", "Invalid requests must not trigger authentication");
});

for (const [fixture, check] of [
  ["empty-array", (value) => assert.deepEqual(value.data, [])],
  ["empty-object", (value) => assert.deepEqual(value.data, {})],
  ["null", (value) => { assert.equal(value.status, "unavailable"); assert.equal(value.data, null); }],
  ["false", (value) => assert.equal(value.data, false)],
  ["zero", (value) => assert.equal(value.data, 0)],
  ["large-page", (value) => { assert.equal(value.data.length, 50); assert.equal(value.truncated, true); }],
  ["large-object", (value) => { assert.equal(Object.keys(value.data).length, 50); assert.equal(value.truncated, true); }],
  ["long-text", (value) => { assert.equal(value.data.text.length, 500); assert.equal(value.truncated, true); }],
  ["deep", (value) => { assert.equal(value.data.a.b.c.d, null); assert.equal(value.truncated, true); }],
  ["redaction", (value) => {
    assert.equal(value.truncated, true);
    assert.deepEqual(value.data, { enabled: true, PasswordValidityPeriod: 90, nested: { name: "safe" } });
  }],
  ["node-budget", (value) => assert.equal(value.truncated, true)],
]) {
  test(`bounded output: ${fixture}`, { timeout: 20_000 }, async (t) => {
    const host = new Host(fixture);
    t.after(() => host.close());
    check(outputSchema.parse(await host.invoke("domains", {})));
  });
}

for (const [fixture, code] of [
  ["html", "invalid_response"], ["html-json", "invalid_response"],
  ["malformed", "invalid_response"], ["blank", "invalid_response"],
  ["status-201", "invalid_response"], ["too-large", "invalid_response"],
  ["oversized-frame", "invalid_response"], ["error-payload", "upstream_failed"],
  ["http-404", "not_found"], ["http-302", "upstream_failed"],
  ["http-500", "upstream_failed"], ["exception", "upstream_failed"],
  ["auth-failure", "not_connected"],
]) {
  test(`sanitized failure: ${fixture}`, { timeout: 20_000 }, async (t) => {
    const host = new Host(fixture);
    t.after(() => host.close());
    await assert.rejects(host.invoke("domains", {}), { message: code });
    await assert.rejects(host.invoke("domains", {}), { message: code });
  });
}

for (const status of [401, 403]) {
  test(`HTTP ${status} revokes the session without bootstrap retry`, { timeout: 20_000 }, async (t) => {
    const host = new Host(`http-${status}`);
    t.after(() => host.close());
    await assert.rejects(host.invoke("domains", {}), { message: "not_connected" });
    await assert.rejects(host.invoke("domains", {}), { message: "not_connected" });
  });
}

test("MCP rejects invalid arguments without invoking the bridge", async (t) => {
  let invoked = 0;
  const client = await session(t, { invoke: async () => { invoked++; throw new Error("must not run"); } });
  for (const args of [{ section: "All" }, { section: "Profile", extra: true }, { section: 1 }]) {
    const result = await client.callTool({ name: "m365_get_company_setting", arguments: args });
    assert.equal(result.isError, true);
  }
  assert.equal(invoked, 0);
});

test("MCP rejects wrong-surface and malformed output and sanitizes unexpected exceptions", async (t) => {
  for (const value of [
    { surface: "wrong", section: null, status: "ok", truncated: false, data: {} },
    { surface: "domains", section: "wrong", status: "ok", truncated: false, data: {} },
    { surface: "domains", section: null, status: "ok", truncated: false, data: { text: "x".repeat(501) } },
    { surface: "domains", section: null, status: "unavailable", truncated: false, data: {} },
  ]) {
    const client = await session(t, { invoke: async () => value });
    const result = await client.callTool({ name: "m365_list_domains", arguments: {} });
    assert.equal(result.isError, true);
    assert.equal(result.content[0].text, "invalid_response");
  }
  const client = await session(t, { invoke: async () => { throw new Error("synthetic sensitive detail"); } });
  const result = await client.callTool({ name: "m365_list_domains", arguments: {} });
  assert.equal(result.content[0].text, "operation_failed");
});

test("production stdio starts without auth, lists tools and fails closed on reads", { timeout: 120_000 }, async (t) => {
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [fileURLToPath(new URL("../dist/index.js", import.meta.url))],
    env: { ...process.env, M365_MCP_AUTH: "", M365_MCP_PASSKEY_FILE: "" },
    stderr: "pipe",
  });
  const client = new Client({ name: "stdio-smoke", version: "1.0.0" });
  t.after(() => client.close());
  await client.connect(transport);
  assert.equal((await client.listTools()).tools.length, 9);
  for (const expected of ["not_connected", "session_lost"]) {
    const result = await client.callTool({ name: "m365_list_domains", arguments: {} }, undefined, { timeout: 370_000 });
    assert.equal(result.isError, true);
    assert.equal(result.content[0].text, expected);
  }
});

test("production bridge bounds the queue and cleans up after active cancellation", { timeout: 30_000 }, async () => {
  const bridge = new ReadOnlyBridge({ ...process.env, M365_MCP_AUTH: "", M365_MCP_PASSKEY_FILE: "" });
  const controller = new AbortController();
  const first = bridge.invoke("domains", {}, controller.signal);
  const queued = Array.from({ length: 7 }, () => bridge.invoke("domains", {}));
  await assert.rejects(bridge.invoke("domains", {}), { message: "server_busy" });
  controller.abort();
  await assert.rejects(first, (error) => ["request_cancelled", "session_lost"].includes(error.message));
  await Promise.all(queued.map((promise) => assert.rejects(promise, { message: "session_lost" })));
  await bridge.close();
  await assert.rejects(bridge.invoke("domains", {}), { message: "session_lost" });
});

test("production bridge does not start a process for invalid or pre-cancelled requests", async () => {
  const bridge = new ReadOnlyBridge({ ...process.env, M365_MCP_AUTH: "" });
  await assert.rejects(bridge.invoke("invoke_rest", {}), { message: "operation_not_allowed" });
  await assert.rejects(bridge.invoke("domains", { extra: "value" }), { message: "invalid_arguments" });
  await assert.rejects(bridge.invoke("domains", {}, AbortSignal.abort()), { message: "request_cancelled" });
  await bridge.close();
});
