import { existsSync } from "node:fs";
import { isAbsolute } from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { outputSchema, tools } from "../dist/contracts.js";

async function main() {
  const keyFile = process.env.M365_MCP_PASSKEY_FILE;
  if (process.env.M365_MCP_AUTH !== "software-passkey" || !keyFile || !isAbsolute(keyFile) || !existsSync(keyFile)) {
    throw new Error("live_auth_not_configured");
  }
  const client = new Client({ name: "m365-readonly-live-smoke", version: "0.1.0" });
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [fileURLToPath(new URL("../dist/index.js", import.meta.url))],
    env: { ...process.env },
    stderr: "pipe",
  });
  // Never forward upstream errors, sign-in output or tenant payloads to saved test output.
  transport.stderr?.resume();
  let failed = 0;
  let skipped = 0;
  let passed = 0;
  try {
    await client.connect(transport);
    const catalog = await client.listTools();
    if (catalog.tools.length !== tools.length) throw new Error("catalog_mismatch");
    for (const tool of tools) {
      if (tool.domain && !process.env.M365_MCP_TEST_DOMAIN) {
        console.log(`${tool.name}: skipped (no operator-supplied test domain)`);
        skipped++;
        continue;
      }
      const sections = Object.keys(tool.sections ?? {});
      const argumentsList = tool.sections ?
        (process.env.M365_MCP_LIVE_ALL_SECTIONS === "1" ? sections : sections.slice(0, 1)).map((section) => ({ section })) :
        [tool.domain ? { domain: process.env.M365_MCP_TEST_DOMAIN } : {}];
      for (const args of argumentsList) {
        const result = await client.callTool({ name: tool.name, arguments: args }, undefined, { timeout: 370_000 });
        if (result.isError) {
          console.log(`${tool.name}: error`);
          failed++;
          continue;
        }
        const data = outputSchema.parse(result.structuredContent);
        console.log(`${tool.name}: ${data.status}; truncated=${data.truncated}`);
        passed++;
      }
    }
  } finally {
    await client.close();
  }
  console.log(`read smoke: passed=${passed}; failed=${failed}; skipped=${skipped}`);
  if (failed) process.exitCode = 1;
}

main().catch(() => {
  console.error("Live smoke failed. Verify local authentication, access and server prerequisites; no tenant details were logged.");
  process.exitCode = 1;
});
