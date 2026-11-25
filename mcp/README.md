# Read-only M365Internals MCP (0.1.0)

An optional **local, single-operator stdio server** for Microsoft 365 admin-center configuration reads. It uses the repository's portal authentication in a dedicated PowerShell process; it is not a Graph API server, a command runner, or a shared service.

The design follows [MSCloudInternals/XDRInternals#134](https://github.com/MSCloudInternals/XDRInternals/pull/134), but targets admin configuration rather than Defender investigations. No tenant mutation tools are exposed.

## Tools

| Tool | Exact input and scope |
| --- | --- |
| `m365_get_company_setting` | `section`: Profile, HelpDesk, ReleaseTrack, SendFromAddress, Theme, Tile |
| `m365_get_security_setting` | `section`: SecurityDefaults, PasswordPolicy, GuestUserPolicy, GuestAccess, TenantLockbox, IdleSessionTimeout, PrivacyPolicy, BingDataCollection |
| `m365_get_report_setting` | `section`: TenantConfiguration, ProductivityScoreConfig, ProductivityScoreCustomerOption |
| `m365_get_tenant_setting` | `section`: AccountSkus, O365ActivationUserCounts, ReportsPrivacyEnabled, DataLocationAndCommitments, LocalDataLocation |
| `m365_get_service_setting` | `section`: ModernAuth, Planner, Todo, VivaInsights, SearchIntelligenceAnalytics |
| `m365_list_agent_mcp_servers` | No arguments; registered agent MCP server inventory |
| `m365_get_copilot_pin_policy` | No arguments; current pin policy |
| `m365_list_domains` | No arguments; domain inventory |
| `m365_get_domain_records` | `domain`: one ASCII DNS name, at most 253 characters; use punycode for internationalized names |

Section names are case-sensitive; additional arguments and `All` are rejected. The nine tools cover 31 fixed routes/sections recorded in [`tools.json`](tools.json). There are no user-controlled URLs, tenant IDs, HTTP methods, request bodies, scripts, credentials or file paths in the MCP tool surface. DNS health/troubleshooting probes, exports, user/group searches, arbitrary queries, and all setters are deliberately excluded.

## Setup

Requires **Node.js 22+**, **PowerShell 7.5+** (`pwsh` on `PATH`), and this repository checkout. PowerShell 7.5 is required to preserve JSON date strings without converting their representation. From the repository root:

```powershell
npm ci --prefix mcp
npm run build --prefix mcp
npm test --prefix mcp
```

Configure a trusted client's **local** MCP settings using absolute paths. Do not commit this configuration or a passkey:

```json
{
  "mcpServers": {
    "m365internals-readonly": {
      "command": "node",
      "args": ["C:\\src\\M365Internals\\mcp\\dist\\index.js"],
      "env": {
        "M365_MCP_AUTH": "software-passkey",
        "M365_MCP_PASSKEY_FILE": "C:\\private\\operator.passkey"
      }
    }
  }
}
```

On Linux/macOS, substitute native absolute paths. This initial version supports **operator-configured software-passkey authentication only** through `Connect-M365PortalBySoftwarePasskey`, including the module's existing Key Vault-backed passkey support. It does not create a passkey, offer model-visible sign-in, reuse another PowerShell session, or launch a browser. Interactive browser authentication is deferred rather than shipping without validated browser-profile/process-tree cleanup.

Protect the passkey and checkout with operator-only write access. Use a dedicated least-privileged account with access to the selected admin-center surfaces, and review client approvals and data handling before connecting. The first valid read signs in; listing tools does not authenticate. Without the explicit authentication mode and an existing absolute passkey path, reads return `not_connected`. No credentials, cookies or authentication output are returned to MCP.

The first read and calls queued during sign-in have a six-minute deadline. Later reads have a 60-second deadline including queue time and a 45-second HTTP timeout. At most eight calls can be outstanding. Cancellation of an active request, a deadline, malformed host protocol, or HTTP 401/403 closes the dedicated session; restart the MCP server to sign in again. HTTP 404 returns `not_found` without revoking the session. No automatic sign-in or bootstrap retry is performed for a read. Normal stdin EOF and client shutdown terminate the PowerShell host.

Allow at least 370 seconds for the first tool call in the client's timeout settings; module import and authentication can exceed a client's default 60-second timeout.

## Result contract

Every successful tool returns the same structured snapshot in `structuredContent` and JSON text:

```json
{
  "surface": "security_setting",
  "section": "SecurityDefaults",
  "status": "ok",
  "truncated": false,
  "data": { "enabled": true }
}
```

`data` preserves the portal's JSON shape, not the module's friendly PowerShell formatting. Portal setting schemas differ and are undocumented; this version bounds JSON structurally rather than promising field-level compatibility. No compliance conclusions are generated.

- Strings are capped at 500 characters, arrays and objects at 50 entries, property names at 80 characters, and nesting at four levels below the payload root.
- A snapshot has at most 2,048 JSON nodes and a serialized host frame limit of 256 KiB. Oversized frames fail with `invalid_response`, rather than silently returning an empty success.
- Common credential-named fields are omitted (including token, cookie, password, secret and private-key fields). This is best-effort minimization, **not a guarantee that the remaining data is non-sensitive**.
- `truncated: true` signals omitted entries, fields, deep values, redaction or shortened text. These are incomplete snapshots, not exhaustive inventories. There is no auto-pagination.
- JSON `null` yields `status: unavailable` and `data: null`. Empty arrays/objects, `false` and zero remain valid `ok` results. Blank responses, HTML, malformed JSON and error envelopes are failures.

Each tool issues one fixed GET against `https://admin.cloud.microsoft`, using current portal cookies/headers and the existing DataLocation header profile where needed. Requests do not use the getters' caches, auto-healing bootstrap or public Microsoft Graph APIs. Redirects are disabled. HTTP bodies above 1 MiB are rejected before JSON parsing, **after receipt**; the module's HTTP client still buffers the upstream response. Limits bound model-visible output, not server-side retrieval size or tenant inventory completeness.

Errors are stable codes, never raw upstream exceptions: `invalid_request`, `invalid_arguments`, `operation_not_allowed`, `not_connected`, `not_found`, `invalid_response`, `upstream_failed`, `operation_failed`, `session_lost`, `session_timed_out`, `server_busy`, or `request_cancelled`. MCP schema validation may also return the SDK's invalid-input error. Optional or permission-restricted portal routes may fail; failures are not evidence that a setting is disabled.

## Validation

`npm test --prefix mcp` is offline: it explicitly disables real authentication in production-process checks and uses a synthetic PowerShell module for upstream tests. It exercises every tool and every section through MCP and the actual PowerShell host in two fresh sessions, plus input rejection, exact GET routes, bounded/redacted outputs, malformed responses, HTTP failures, session revocation and lifecycle behavior. Fixtures contain no tenant data. CI runs these checks on Windows and Linux and audits runtime dependencies.

Live validation is **opt-in**, not part of CI or the default test suite. From a trusted local PowerShell session:

```powershell
$env:M365_MCP_AUTH = 'software-passkey'
$env:M365_MCP_PASSKEY_FILE = 'C:\private\operator.passkey'
$env:M365_MCP_TEST_DOMAIN = 'example.com' # Optional: a domain in your tenant
npm run test:live --prefix mcp
```

The harness reads one representative section for each tool. Domain records are explicitly skipped unless the operator supplies a domain. To exercise all 31 routes/sections, also set `$env:M365_MCP_LIVE_ALL_SECTIONS = '1'`. Run the command again for a second fresh sign-in. Output is limited to tool names, status/truncation and aggregate counts; payloads, identifiers, credential paths and raw exceptions are not printed. Any failed read makes the run fail. A successful empty or unavailable response is not populated-record coverage.

This version has offline Windows verification; **authenticated live behavior and macOS support have not been verified**. Existing module route coverage is not a substitute for an authenticated MCP smoke pass.

## Trust boundaries and residual risks

The TypeScript server and PowerShell host each validate exact tool arguments against the same reviewed route manifest. The host checks arguments **before authentication**, accepts only fixed operations, and independently constructs GET requests. The manifest, host and module are trusted local code; someone able to change the checkout can change the server's capabilities. The PowerShell `-ModulePath` parameter exists for direct offline host tests and is not available through the production bridge or MCP tools.

Read-only is an intended operation boundary, not an authorization system. Authentication can generate sign-in/audit events and maintain in-memory session state. GET endpoints are undocumented and can change behavior. The server does not independently attest or rebind the authenticated account/tenant, and no tool can select another tenant.

All tenant-provided strings and URLs are untrusted evidence, including names, themes, help-desk text and registered MCP server addresses. Never follow their instructions or automatically connect to returned URLs. Tenant configuration may be confidential even after redaction and may enter the AI provider's context/retention systems. Keep read approvals enabled and do not attach this server to agents with unreviewed external-send tools.

There is no listening port, HTTP transport, multi-user authorization or shared proxy support. Cookies remain in the dedicated PowerShell process, not a server-managed profile or credential cache. Normal shutdown/cancellation kills that host. External hard kills bypass cleanup; OS crash dumps and external Key Vault/Azure CLI credential caches are outside this server's control.

To add a surface, review its actual portal semantics, add only an exact GET route to the manifest, update this tool table and offline fixtures/tests, and run the full MCP suite and runtime audit. Do not automatically expose new module cmdlets or treat a `Get-` name as proof that an operation is read-only.
