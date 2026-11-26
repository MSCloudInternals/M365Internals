import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { createInterface } from 'node:readline';
import { setTimeout as delay } from 'node:timers/promises';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { Worker } from '../server.mjs';
import { z } from 'zod';

const fixture = fileURLToPath(new URL('./portal-fixture.psm1', import.meta.url));
const server = fileURLToPath(new URL('../server.mjs', import.meta.url));
const clientEnv = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('MSCI_')));

async function start(t, env = {}) {
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [server],
    env: { ...clientEnv, ...env },
    stderr: 'pipe',
  });
  let stderr = '';
  transport.stderr?.on('data', (chunk) => { stderr += chunk.toString(); });
  const client = new Client({ name: 'integration-fixture', version: '1.0.0' });
  t.after(async () => {
    await client.close();
    assert.doesNotMatch(stderr, /fixture.secret|fixture.*canary/);
  });
  await client.connect(transport);
  return client;
}

const call = (client, name, args = {}) => client.callTool({ name, arguments: args });
const verified = { connected: true, accountVerification: 'Verified', resourceTenantVerification: 'Verified' };

test('lists schemas without importing modules or starting sign-in', async (t) => {
  const client = await start(t, { MSCI_M365_MODULE: '/unavailable/module.psd1' });
  const { tools } = await client.listTools();
  assert.equal(tools.length, 5);
  assert.ok(tools.every(({ name }) => name.startsWith('m365_')));
  assert.deepEqual((await call(client, 'm365_status')).structuredContent, {
    connected: false, accountVerification: 'Unknown', resourceTenantVerification: 'Unknown',
  });
  assert.equal((await call(client, 'm365_domains')).isError, true);
});

test('isolates services, opaque cursors, failed reconnects and session drift over stdio', async (t) => {
  const temp = await mkdtemp(join(tmpdir(), 'msci-mcp-test-'));
  t.after(() => rm(temp, { recursive: true, force: true }));
  const fail = join(temp, 'fail-next');
  const client = await start(t, {
    MSCI_M365_MODULE: fixture, MSCI_M365_AUTH: 'passkey', MSCI_M365_PASSKEY: join(temp, 'unused'),
    MSCI_PURVIEW_MODULE: fixture, MSCI_PURVIEW_PROFILE: fail,
  });
  const { tools } = await client.listTools();
  assert.equal(tools.length, 11);
  assert.ok(tools.find(({ name }) => name === 'purview_audit_history').inputSchema.properties.cursor);
  assert.equal((await call(client, 'm365_connect', { key: 'client-supplied' })).isError, true);
  assert.deepEqual((await call(client, 'm365_connect')).structuredContent, verified);
  assert.deepEqual((await call(client, 'purview_connect')).structuredContent, verified);
  assert.equal((await call(client, 'purview_device_health')).structuredContent.last30Days, 5);
  assert.equal((await call(client, 'm365_current_user')).structuredContent.principalName, 'admin@example.test');
  assert.equal((await call(client, 'm365_domains')).structuredContent.items[0].name, 'example.test');
  assert.deepEqual((await call(client, 'm365_domains')).structuredContent.items, []);

  const first = (await call(client, 'purview_audit_history', { limit: 1 })).structuredContent;
  assert.equal(first.items[0].id, 'first');
  assert.match(first.nextCursor, /^[a-f0-9]{32}$/);
  assert.doesNotMatch(JSON.stringify(first), /fixture.secret/);
  await writeFile(fail, '');
  const failed = await call(client, 'purview_connect');
  assert.equal(failed.isError, true);
  assert.doesNotMatch(JSON.stringify(failed), /canary/);
  assert.deepEqual((await call(client, 'purview_status')).structuredContent, verified);
  assert.equal((await call(client, 'purview_audit_history', { cursor: first.nextCursor, limit: 1 })).isError, true);
  const next = (await call(client, 'purview_audit_history', { cursor: first.nextCursor })).structuredContent;
  assert.equal(next.items[0].id, 'second');
  assert.equal(next.nextCursor, null);
  assert.equal((await call(client, 'purview_audit_history', { cursor: first.nextCursor })).isError, true);

  const pending = (await call(client, 'purview_audit_history', { limit: 1 })).structuredContent;
  await rm(fail);
  assert.deepEqual((await call(client, 'purview_connect')).structuredContent, verified);
  assert.equal((await call(client, 'purview_audit_history', { cursor: pending.nextCursor })).isError, true);
  assert.equal((await call(client, 'purview_ediscovery_cases', { caseId: 'drift' })).isError, true);
  assert.equal((await call(client, 'purview_status')).structuredContent.connected, false);
  assert.deepEqual((await call(client, 'm365_status')).structuredContent, verified);
  assert.equal((await call(client, 'm365_disconnect')).structuredContent.connected, false);
  assert.equal((await call(client, 'm365_current_user')).isError, true);
});

test('worker rejects extra result fields and abandons a cancelled exchange', async (t) => {
  const temp = await mkdtemp(join(tmpdir(), 'msci-worker-test-'));
  t.after(() => rm(temp, { recursive: true, force: true }));
  const script = join(temp, 'fake.ps1');
  await writeFile(script, [
    '$request = ConvertFrom-Json ([Console]::ReadLine())',
    "if ($request.operation -eq 'slow') { Start-Sleep -Seconds 30 }",
    "[Console]::WriteLine((@{id=$request.id;ok=$true;data=@{allowed='yes';Token='secret-fixture'}} | ConvertTo-Json -Compress))",
  ].join('\n'));
  const cfg = { pwsh: 'pwsh', module: fixture, auth: 'browser' };
  const schema = z.object({ allowed: z.string() }).strict();
  const malformed = new Worker('m365', cfg, script);
  t.after(() => malformed.close());
  await assert.rejects(malformed.request('read', {}, schema, 5000), /^Error: response_invalid$/);
  assert.equal(malformed.closed, true);

  const slow = new Worker('m365', cfg, script);
  t.after(() => slow.close());
  const controller = new AbortController();
  const request = slow.request('slow', {}, schema, 5000, controller.signal);
  controller.abort();
  await assert.rejects(request, /^Error: cancelled$/);
  await assert.rejects(slow.request('read', {}, schema, 5000), /^Error: worker_unavailable$/);

  const timed = new Worker('m365', cfg, script);
  t.after(() => timed.close());
  await assert.rejects(timed.request('slow', {}, schema, 50), /^Error: timeout$/);
  assert.equal(timed.closed, true);
});

test('stdin EOF releases a connected stdio server', { timeout: 10000 }, async (t) => {
  const child = spawn(process.execPath, [server], {
    env: { ...clientEnv, MSCI_M365_MODULE: fixture, MSCI_M365_AUTH: 'passkey', MSCI_M365_PASSKEY: fixture },
    stdio: ['pipe', 'pipe', 'ignore'],
  });
  t.after(() => child.kill());
  const lines = createInterface({ input: child.stdout })[Symbol.asyncIterator]();
  const send = (message) => child.stdin.write(JSON.stringify({ jsonrpc: '2.0', ...message }) + '\n');
  send({ id: 1, method: 'initialize', params: { protocolVersion: '2025-03-26', capabilities: {}, clientInfo: { name: 'eof-test', version: '1' } } });
  assert.equal(JSON.parse((await lines.next()).value).id, 1);
  send({ method: 'notifications/initialized' });
  send({ id: 2, method: 'tools/call', params: { name: 'm365_connect', arguments: {} } });
  const reply = JSON.parse((await lines.next()).value);
  assert.equal(reply.id, 2);
  assert.deepEqual(reply.result.structuredContent, verified);
  const exited = once(child, 'exit');
  child.stdin.end();
  const [code] = await exited;
  assert.equal(code, 0);
});

test('worker cancellation terminates a spawned process in its group', { skip: process.platform !== 'linux', timeout: 10000 }, async (t) => {
  const temp = await mkdtemp(join(tmpdir(), 'msci-group-test-'));
  t.after(() => rm(temp, { recursive: true, force: true }));
  const marker = join(temp, 'pid');
  const script = join(temp, 'descendant.ps1');
  await writeFile(script, [
    '$null = [Console]::ReadLine()',
    "$child = Start-Process -FilePath '/bin/sleep' -ArgumentList '60' -PassThru",
    "[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'pid'), [string]$child.Id)",
    'Start-Sleep -Seconds 60',
  ].join('\n'));
  const worker = new Worker('m365', { pwsh: 'pwsh', module: fixture, auth: 'browser' }, script);
  t.after(() => worker.close());
  const controller = new AbortController();
  const result = worker.request('slow', {}, z.object({}), 8000, controller.signal);
  const rejection = assert.rejects(result, /^Error: cancelled$/);
  let pid;
  for (let i = 0; i < 50 && !pid; i++) {
    try { pid = Number(await readFile(marker, 'utf8')); }
    catch { await delay(50); }
  }
  assert.ok(pid);
  controller.abort();
  await rejection;
  for (let i = 0; i < 50; i++) {
    let state;
    try { state = (await readFile('/proc/' + pid + '/stat', 'utf8')).split(') ')[1][0]; }
    catch (error) { if (error.code === 'ENOENT') return; throw error; }
    if (state === 'Z') return;
    await delay(50);
  }
  assert.fail('worker descendant remained running');
});
