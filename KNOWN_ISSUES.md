# Known Issues And Follow-Up Items

This file tracks the currently known limitations, tenant-specific quirks, and follow-up items discovered while building and validating the Microsoft 365 admin-center cmdlets.

Last updated: 2026-03-24

## Connection And Bootstrap

- Admin portal sign-in is not fully established after `/landing` alone. Successful automation still depends on the post-landing browser-style navigation sequence and portal-context setup.
- `UserLoginRef=/homepage` is established during `GET https://admin.cloud.microsoft/login?ru=%2Fadminportal%3Fref%3D%2Fhomepage`.
- `s.UserTenantId` is not reliable as the canonical tenant identifier in newer sessions.
  - It may be absent.
  - It may be present but contain an opaque non-GUID value.
  - The effective tenant GUID should continue to be derived from validated bootstrap content such as `ClassicModernAdminDataStream` or `ShellInfo`.
- If the post-landing bootstrap sequence misses the `POST /api/instrument/logclient` step or calls `ClassicModernAdminDataStream` in the wrong state, PowerShell can receive a `200` HTML error shell instead of the expected bootstrap content.
- ESTS-cookie reuse is still sensitive to the admin-bound portal handoff.
  - A generic Graph or CLI-style ESTS reuse path can still hit `AADSTS50058` during admin authorize.
  - The working software-passkey path succeeds because it preserves the admin portal bootstrap flow on the same Entra session.

## Session Reuse And Validation

- Direct browser-cookie exports have been less reliable for PowerShell reuse than live passkey-backed sessions.
- Live passkey-backed validation has been the most reliable test path so far for confirming real admin-center reads.
- Cookie-based validation should continue to be treated as best-effort unless a more durable cookie import/bootstrap flow is implemented later.

## Live Validation Status

- The public cmdlet surface was exercised successfully in five authenticated live validation batches on 2026-03-24.
- The most significant live issues uncovered during that sweep were fixed in the module rather than suppressed in the harness.
- Validation scripts currently live under `TestResults/` because they are intended as repo-maintainer assets, not public module content.
- The standard repository Pester run is now fully clean after the follow-on analyzer cleanup work.
- A final rerun of all five live validation batches also completed successfully after the cleanup pass.

## Request Helper Limitations

- `Invoke-M365AdminRestMethod` was updated to handle omitted `-Headers` and `POST` requests with no body.
- Additional `fd/msgraph` endpoints may still require extra headers beyond the default same-origin request shape.
  - Known example: Microsoft Edge device inventory is reliable with `ConsistencyLevel=eventual` and `?$count=true&$top=1`.
  - Future Graph-proxy work should validate whether `x-adminapp-request`, `ConsistencyLevel`, or other specialized headers are required.

## Top-Level Settings Routes Confirmed Live

- Domains: `#/Domains`
- Search & intelligence: `#/MicrosoftSearch`
- Org settings: `#/Settings/...`
- Microsoft 365 Backup: `#/Settings/enhancedRestore`
- Integrated apps: `#/Settings/IntegratedApps`
- Directory sync errors: `#/dirsyncobjecterrors`
- Viva: `#/viva`
- Partner relationships: `#/partners`
- Microsoft Edge: `#/Edge`

## Copilot Routes Confirmed Live

- Overview: `#/copilot/overview`
- Security: `#/copilot/scc`
- Usage: `#/copilot/usage`
- About: `#/copilot/discover`
- Connectors: `#/copilot/connectors`
- Billing & usage: `#/copilot/managecost`
- Settings: `#/copilot/settings/Optimize`

## Agents Routes Confirmed Live

- Overview: `#/agents/overview`
- All agents: `#/agents/all`
- All agents map frontier: `#/agents/all/map`
- All agents requests: `#/agents/all/requested`
- All agents catalog: `#/agents/all/agent-catalog`
- Tools: `#/agents/tools`
- Settings: `#/agents/settings`
- Settings templates: `#/agents/settings/templates`

## Agents: Known Issues And Follow-Up

- `POST /admin/api/agentusers/metrics` is part of the live Agents overview experience.
- The live browser request body is `{"tenantMetricRequests":[{"type":"assistedHours","grain":"rolling30Days"}]}`.
- In the current tenant, the successful replay returns `{"agentMetrics":[],"tenantMetrics":[]}`.
- The surrounding `fd/addins/api/apps/insight` payload already exposes the overview summary data that matters for read-only coverage: total agents, blocked agents, orphaned agents, and builder/app-type breakdowns.
- `Get-M365AdminAgentOverview` now exposes a derived `Summary` result based on that GET-backed data, so the unresolved POST is not currently required for useful read coverage.

## Copilot: Known Issues And Follow-Up

- `fd/purview/apiproxy/cpm/v1.0/Tenant/AIBaselineSummary` requires Purview-specific headers beyond the default same-origin portal request shape.
- Browser review showed the successful request includes headers such as `tenantid`, `x-tid`, `client-type=purview`, `x-clientpage=/`, `client-version`, `x-tabvisible`, and `client-request-id`.
- The grouped Copilot cmdlets now send that Purview request shape for `AIBaselineSummary`.

## Top-Level Settings: Known Issues And Follow-Up

### Search & intelligence

- `/admin/api/searchadminapi/configurations` still returns `503` in both direct PowerShell reads and live in-browser fetches.
- `/admin/api/searchadminapi/firstrunexperience/get` is a POST-backed endpoint. The live portal sends an array of feature names and returns `200` in this tenant when that body is preserved.
- `/admin/api/searchadminapi/Qnas` is also POST-backed. The live portal sends `{"ServiceType":"Bing","Filter":"Published"}` and the current tenant returns `404` for that published Bing payload.
- The grouped cmdlet should preserve those POST request shapes and only surface tenant-specific unavailability when the portal itself does.
- Follow-up: determine whether additional `Qnas` filter/service combinations are used in other tenants.

### Integrated apps

- The landing page is backed by `fd/addins` endpoints and is working in current validation.
- No blocking issue is known right now, but additional app-management actions were not modeled because the current scope is read-only coverage.

### Directory sync errors

- `Directory sync errors` requires `POST /admin/api/dirsyncerrors/listdirsyncerrors`.
- `GET` returns `400`.
- Follow-up: if pagination or filtering becomes necessary later, capture the exact request body and paging semantics from the portal.

### Domains

- `Get-M365AdminDomain -Dependencies` can return `400` for valid domains in otherwise healthy sessions.
- The cmdlet now returns a structured `M365Admin.UnavailableResult` for this tenant-specific behavior when the endpoint itself does not provide usable data.
- Follow-up: validate whether other tenants expose broader `Dependencies` support or whether additional request context is required.

### Viva

- The top-level Viva page successfully loads:
  - `/admin/api/viva/modules`
  - `/admin/api/viva/roles`
  - `/admin/api/viva/glint/lookupClient`
  - `/admin/api/tenant/accountSkus`
- No blocking issue is known right now.

### Partner relationships

- In the current tenant, the page is delegated-partner oriented.
- Grouping `DAP` and `GDAP` partner client lists is the stable read model so far.
- Follow-up: if other partner-relationship sub-surfaces appear in different tenants, capture and model them separately.

### Microsoft 365 Backup

- The current grouped read model is valid and confirmed live.
- Azure subscription permissions are per-subscription and require follow-on calls.
- Follow-up: if broader backup-management surfaces are needed later, capture any additional settings pages beyond the currently modeled feature state and restore status.

### Tenant relationships

- `userSyncApps/outboundDetails` can return `400` when outbound synchronization is not configured for the tenant.
- `Get-M365AdminTenantRelationship` now treats this as a tenant-specific unavailable sub-result instead of failing the grouped collaboration view.
- Follow-up: validate the successful response shape in a tenant with outbound sync enabled.

### User settings

- `Get-M365AdminUserSetting` is not a uniform GET-based surface.
- Live validation confirmed these POST-backed request shapes:
  - `ContextualAlerts` with an empty object body
  - `ListUsers` with the standard list payload body
  - `Roles` with the current user principal body when available
  - `TokenWithExpiry` with `application/x-www-form-urlencoded` audience data
- `TokenWithExpiry` is audience-sensitive and now exposes `-TokenAudience` so callers can request a brokered token for the intended resource.
- Follow-up: capture additional audiences that are consistently accepted across tenants.

### Microsoft Edge

- The top-level page is backed by a mix of policy, extension-management, and Graph-proxy device inventory endpoints.
- `Edge site list notifications` can return `404` in a healthy tenant and session.
- Grouped reads should continue treating site-list notifications as optional.
- Device inventory is more reliable via `/fd/msgraph/v1.0/devices?$count=true&$top=1` with `ConsistencyLevel=eventual` than via a raw `/$count` call.

## Org Settings: Known Issues And Follow-Up

### Informational Or Static Pages In This Tenant

- `Sales / VivaSales`
- `Microsoft Azure Information Protection`
- `What's new in Microsoft 365`
- `Keyboard shortcuts`

These behaved as informational or static pages in the current tenant rather than exposing stable dedicated settings APIs.

### Weakly Mapped Or Unstable Surfaces

- `Account Linking / EnterpriseMicrosoftRewards`
  - Route is known.
  - A stable reproducible same-origin read has not been found outside the live portal interaction flow.
- `News`
  - The stable implementation should continue using the three search-admin news endpoints.
  - The direct `/fd/bfb/api/v3/office/switch/feature` path returned `503` during direct probing.
- `Pay-as-you-go telemetry`
  - Earlier GET-style probing was misleading.
  - The observed portal pattern is `POST /admin/api/km/setting/telemetry`, which returns `204`.
  - Follow-up: capture the exact request body and surrounding portal workflow if real telemetry semantics are needed.

### Tenant-Dependent Optional Payloads

- `Ownerless group policy` can return `404 ObjectNotFound` when the policy has not been initialized in the tenant.
- Grouped reads should continue treating this as optional rather than as a hard failure.

## Testing And Validation Gaps

- Live cmdlet validation with the software passkey has been stronger than saved-cookie validation.
- Some full-suite terminal captures were incomplete during interactive runs, even when targeted cmdlet validation passed.
- Follow-up: improve deterministic scripted validation output for larger test batches so full-run results are easier to persist and review.

## Output Model And UX Polish

- Public output objects are more consistent now, but some families still differ in how much shaping they apply.
- `PSTypeName` coverage and standardized unavailable results were expanded during the current polish pass.
- Remaining follow-up is mostly about finishing consistency across older or still-raw cmdlets rather than establishing the pattern for the first time.
- Follow-up: continue expanding `PSTypeName` coverage where outputs are still anonymous composites.
- Follow-up: continue standardizing `All` behavior so each family is clearly either page-oriented or leaf-oriented.
- Follow-up: expand `-Raw` only where a stable leaf payload bundle exists and improves discoverability.
- Follow-up: continue reviewing `Name` values to prefer concise labels that still align with the portal mental model.

## Recommended Follow-Up Order

1. Stabilize `Search & intelligence` `Configurations` endpoint access.
2. Revisit `Account Linking` to determine whether a reproducible direct read exists.
3. Capture the full `pay-as-you-go telemetry` request body and surrounding workflow.
4. Improve cookie-import and non-passkey validation reliability for `Connect-M365Portal`.
5. Continue validating tenant-dependent or informational pages across additional tenants before promoting them beyond informational wrappers.
6. Continue polishing remaining older cmdlets so output shaping and custom formatting are consistent across the module.