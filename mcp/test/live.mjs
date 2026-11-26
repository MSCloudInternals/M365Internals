import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const wantM365 = Boolean(process.env.MSCI_M365_AUTH && process.env.MSCI_M365_AUTH !== 'off');
const wantPurview = Boolean(process.env.MSCI_PURVIEW_MODULE);
if (!wantM365 && !wantPurview) {
  console.error('Configure at least one lab provider before running the live smoke test.');
  process.exit(1);
}
const env = { ...process.env };
if (!wantM365) env.MSCI_M365_AUTH = 'off';
const client = new Client({ name: 'mscloudinternals-live-smoke', version: '1.0.0' });
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [fileURLToPath(new URL('../server.mjs', import.meta.url))],
  env,
  stderr: 'ignore',
});
let phase = 'initialize';

async function call(name, args = {}) {
  phase = name;
  const result = await client.callTool({ name, arguments: args }, undefined, { timeout: 165000 });
  if (result.isError) {
    const code = (() => {
      try {
        const value = JSON.parse(result.content[0]?.text ?? '{}').code;
        return typeof value === 'string' && /^[a-z_]{1,40}$/.test(value) ? value : 'tool_error';
      } catch { return 'tool_error'; }
    })();
    throw new Error(code);
  }
  return result.structuredContent;
}

const verify = (status) => {
  assert.equal(status.connected, true);
  assert.equal(status.accountVerification, 'Verified');
  assert.equal(status.resourceTenantVerification, 'Verified');
};
const receipt = {};
try {
  await client.connect(transport);
  if (wantM365) {
    verify(await call('m365_connect'));
    const user = await call('m365_current_user');
    const domains = await call('m365_domains', { limit: 5 });
    verify(await call('m365_status'));
    receipt.m365 = { verified: true, principalPresent: Boolean(user.id), domainRows: domains.items.length };
  }
  if (wantPurview) {
    verify(await call('purview_connect'));
    const device = await call('purview_device_health');
    const cases = await call('purview_ediscovery_cases', { limit: 5 });
    const first = await call('purview_audit_history', { limit: 1 });
    const second = first.nextCursor ? await call('purview_audit_history', { cursor: first.nextCursor }) : null;
    verify(await call('purview_status'));
    const firstId = first.items[0]?.id;
    const secondId = second?.items[0]?.id;
    const distinct = Boolean(firstId && secondId && firstId !== secondId);
    if (process.env.MSCI_LIVE_REQUIRE_AUDIT_CONTINUATION === '1') {
      phase = 'purview_audit_continuation';
      assert.ok(second && distinct);
    }
    receipt.purview = {
      verified: true,
      deviceCounts: Object.values(device).filter(Number.isInteger).length,
      caseRows: cases.items.length,
      auditFirstRows: first.items.length,
      auditContinuation: Boolean(second),
      auditSecondRows: second?.items.length ?? 0,
      distinctAuditJobs: second ? distinct : null,
    };
  }
  console.log(JSON.stringify(receipt));
} catch (error) {
  const code = /^[a-z_]{1,40}$/.test(error.message) ? error.message : 'smoke_failed';
  console.error(JSON.stringify({ phase, code }));
  process.exitCode = 1;
} finally {
  await client.close();
}
