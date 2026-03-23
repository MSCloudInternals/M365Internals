# Known Issues And Follow-Up Items

This file tracks the currently known limitations, tenant-specific quirks, and follow-up items discovered while building and validating the Microsoft 365 admin-center cmdlets.

Last updated: 2026-03-23

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

## Request Helper Limitations

- `Invoke-M365RestMethod` was updated to handle omitted `-Headers` and `POST` requests with no body.
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

## Top-Level Settings: Known Issues And Follow-Up

### Search & intelligence

- `/admin/api/searchadminapi/configurations` still returns `503` in direct PowerShell reads.
- The grouped cmdlet currently surfaces this section as unavailable or error detail instead of failing the aggregate.
- Follow-up: identify whether this endpoint needs a different header set, route context, method, or preflight sequence.

### Integrated apps

- The landing page is backed by `fd/addins` endpoints and is working in current validation.
- No blocking issue is known right now, but additional app-management actions were not modeled because the current scope is read-only coverage.

### Directory sync errors

- `Directory sync errors` requires `POST /admin/api/dirsyncerrors/listdirsyncerrors`.
- `GET` returns `400`.
- Follow-up: if pagination or filtering becomes necessary later, capture the exact request body and paging semantics from the portal.

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

## Recommended Follow-Up Order

1. Stabilize `Search & intelligence` `Configurations` endpoint access.
2. Revisit `Account Linking` to determine whether a reproducible direct read exists.
3. Capture the full `pay-as-you-go telemetry` request body and surrounding workflow.
4. Improve cookie-import and non-passkey validation reliability for `Connect-M365Portal`.
5. Continue validating tenant-dependent or informational pages across additional tenants before promoting them beyond informational wrappers.