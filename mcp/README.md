# Microsoft Cloud Internals MCP

The local stdio server exposes a curated set of read-only M365 and Purview tools. Each provider uses its own PowerShell process and portal session. The client can request a connection using operator-supplied settings, then call the tool catalog. Tenant text in tool results is untrusted data.

## Run

Use Node.js 20 or later and PowerShell 7. Run `npm ci` here. Configure your client to run Node with an absolute path to `server.mjs`. For example, supply a configuration like this through your MCP client.

```json
{
  "mcpServers": {
    "mscloudinternals": {
      "command": "node",
      "args": ["/absolute/path/to/M365Internals/mcp/server.mjs"],
      "env": {
        "MSCI_M365_AUTH": "passkey",
        "MSCI_M365_PASSKEY": "/private/path/to/admin.passkey",
        "MSCI_PURVIEW_MODULE": "/absolute/path/to/PurviewInternals/PurviewInternals/PurviewInternals.psd1",
        "MSCI_PURVIEW_PROFILE": "/private/path/to/purview-browser-profile"
      }
    }
  }
}
```

| Setting | Use |
| --- | --- |
| `MSCI_M365_AUTH` | `browser` by default, `passkey`, `sso` for Windows, or `off`. |
| `MSCI_M365_MODULE` | Optional absolute manifest path. Defaults to the module in the server checkout. |
| `MSCI_M365_PASSKEY` | Absolute local credential file path for passkey mode. Keep this file private. |
| `MSCI_M365_PROFILE`, `MSCI_M365_BROWSER` | Optional dedicated profile and browser for browser or SSO mode. |
| `MSCI_PURVIEW_MODULE` | Absolute manifest path. Supplying this enables the Purview tools. |
| `MSCI_PURVIEW_PROFILE`, `MSCI_PURVIEW_BROWSER` | Optional dedicated profile and browser for Purview sign-in. |
| `MSCI_M365_TENANT`, `MSCI_PURVIEW_TENANT` | Optional expected tenant GUID. Each provider checks it against its verified route. |
| `MSCI_PWSH` | PowerShell executable or absolute executable path. Defaults to `pwsh`. |

Call `m365_connect` or `purview_connect` before reads. Listing tools and reading connection status require no sign-in. A failed reconnect preserves the old worker. Successful reconnect, disconnect and interrupted worker operations discard the affected worker's local state. Keep the two browser profiles separate if using browser sign-in for both.

## Tools

| Tool | Result |
| --- | --- |
| `m365_status`, `purview_status` | Local connection and identity verdicts. |
| `m365_connect`, `purview_connect` | Verified connection using local configuration. |
| `m365_disconnect`, `purview_disconnect` | Releases the local session. |
| `m365_current_user` | Admin portal principal ID, display name and UPN. |
| `m365_domains` | Domain names, up to 50. |
| `purview_device_health` | The five standard device health counters. |
| `purview_audit_history` | Existing job metadata, up to 25 per page. |
| `purview_ediscovery_cases` | Case ID, name, status and type, up to 25. |

For audit history, provide an optional `limit` on the first call. If the result has a `nextCursor`, pass it alone as `cursor` on the next call. Each cursor is local to one verified worker and expires after ten minutes. The service's continuation value remains in the worker.

## Verify

Run `npm test` for the offline stdio integration suite. Run `npm run test:live` with one or both providers explicitly configured for a lab. Set `MSCI_LIVE_REQUIRE_AUDIT_CONTINUATION=1` in a lab with enough existing jobs to require distinct IDs across two pages. The live command prints only outcome and row counts. The auth flow can open a browser when needed.

## Lab qualification

The Linux stdio smoke run used M365 software-passkey authentication and the established Purview Edge profile. Both providers verified the account and tenant on the sessions used for their reads. M365 returned its current principal and three domains. Purview returned five device counters, two eDiscovery cases and two distinct audit job IDs across a live continuation. The smoke output recorded counts and verdicts only. Windows SSO and cold browser sign-in remain unqualified for the MCP.
