# XDRInternals surface registry porting plan

This branch adds a registry-backed portal surface discovery system to **M365Internals**. The same capability should port well to **XDRInternals**, which already appears to have analogous repo areas:

- `XDRInternals/`
- `XDRay/`
- `XDRay Firefox/`
- `build/`
- `tests/`

## What exists here now

The canonical source of truth is **not** a loose URL list. It is a registry that stores:

- tracked request prefixes
- header profiles
- normalized request templates
- browser capture plans
- discovery routes
- route interaction recipes
- interactive-only / partially known surfaces
- write probe plans
- role / license / tenant-optional hints

## Key files to study in this branch

- `build/metadata/portal-surface-registry.json`
- `build/PortalSurfaceRegistry.ps1`
- `build/capture-portal-surface-discovery.spec.js`
- `build/run-edge-portal-surface-discovery.ps1`
- `build/capture-agent-copilot-browser-endpoints.spec.js`
- `build/live-discover-settings-write-routes.ps1`
- `build/live-discover-remaining-agent-copilot-routes.ps1`
- `build/Sync-CmdletDocumentation.ps1`
- `M365Ray/background.js`
- `M365Ray/panel.js`
- `M365Ray Firefox/background.js`
- `M365Ray Firefox/panel.js`
- `M365Ray/TrackedRequestPrefixes.json`
- `M365Ray Firefox/TrackedRequestPrefixes.json`
- `tests/general/PortalSurfaceRegistry.Tests.ps1`
- `tests/general/SyncCmdletDocumentation.Tests.ps1`
- `README.md`
- `M365Ray/README.md`

## Important implementation points

1. `build/PortalSurfaceRegistry.ps1` validates and projects the registry into:
   - browser capture plans
   - discovery plans
   - write probe plans
   - tracked prefix artifacts
   - mapping overrides
2. `build/run-edge-portal-surface-discovery.ps1`:
   - generates the discovery plan
   - runs Playwright route discovery
   - executes route interaction recipes
   - writes normalized snapshots
   - diffs against the previous run
   - stores timestamped history artifacts
3. The browser extensions load tracked prefixes from generated JSON instead of hardcoding them in JS.
4. The live write-probe scripts consume registry-backed probe definitions instead of embedded arrays.

## Expected XDRInternals deliverables

1. An XDR-specific registry file.
2. A helper/projection PowerShell layer equivalent to `PortalSurfaceRegistry.ps1`.
3. Playwright-based route discovery with interaction recipes and snapshot/diff/history output.
4. Generated tracked-prefix artifacts for `XDRay` and `XDRay Firefox`.
5. Tests for registry validation and sync stability.
6. Maintainer documentation for the discovery/enrichment workflow.

## What must be adapted, not copied

- XDR portal hostname(s)
- tracked request families
- route families
- auth/bootstrap expectations
- XDR extension mapping file names
- XDR cmdlet naming and representative mapping generation
- XDR-specific role/license/tenant hints

## Suggested implementation order

1. Inventory the current XDR browser-capture, extension, sync, and build patterns.
2. Add the canonical registry and seed it with a small XDR surface area.
3. Add the helper/projection layer with linting from the start.
4. Add route discovery plus interaction recipes and snapshot/diff/history output.
5. Generate tracked-prefix artifacts for `XDRay` and `XDRay Firefox`.
6. Move duplicated build-time request arrays and write-probe candidates behind the registry.
7. Update tests and docs.

## Guardrails

- Do not assume M365 route families or tracked prefixes apply to XDR.
- Do not auto-mutate the registry from observed traffic; keep it review-driven.
- Do not move public runtime cmdlet routing behind the registry unless XDR packaging clearly ships the registry as a runtime asset.
- Preserve XDRInternals auth/build/test conventions.

## Paste-ready prompt for the XDRInternals agent

> Port the registry-backed portal surface discovery capability from the `nathanmcnulty/cmdlet-surface-design` branch of M365Internals into XDRInternals.
>
> First study these files in M365Internals:
>
> - `build/metadata/portal-surface-registry.json`
> - `build/PortalSurfaceRegistry.ps1`
> - `build/capture-portal-surface-discovery.spec.js`
> - `build/run-edge-portal-surface-discovery.ps1`
> - `build/capture-agent-copilot-browser-endpoints.spec.js`
> - `build/live-discover-settings-write-routes.ps1`
> - `build/live-discover-remaining-agent-copilot-routes.ps1`
> - `build/Sync-CmdletDocumentation.ps1`
> - `M365Ray/background.js`
> - `M365Ray/panel.js`
> - `M365Ray Firefox/background.js`
> - `M365Ray Firefox/panel.js`
> - `tests/general/PortalSurfaceRegistry.Tests.ps1`
> - `tests/general/SyncCmdletDocumentation.Tests.ps1`
> - `README.md`
> - `M365Ray/README.md`
>
> In XDRInternals, implement the XDR equivalent:
>
> 1. Add a canonical XDR portal surface registry with tracked prefixes, header profiles, browser capture plans, discovery routes, interaction recipes, interactive-only surfaces, and write probe plans.
> 2. Add a helper/projection PowerShell layer that validates the registry, resolves placeholders, generates discovery/browser/write-probe plans, and exports extension mapping/prefix artifacts.
> 3. Add Playwright-based route discovery with interaction recipes plus normalized snapshot/diff/history output.
> 4. Update XDRay and XDRay Firefox so tracked request prefixes are loaded from generated JSON instead of hardcoded arrays.
> 5. Move duplicated build-time browser/request metadata behind the registry where safe.
> 6. Add tests and maintainer docs for the workflow.
>
> Constraints:
>
> - Adapt for XDR-specific hosts, routes, and request families; do not copy the M365 data verbatim.
> - Keep discovery review-driven.
> - Avoid moving public runtime cmdlet routing behind the registry unless XDR packaging supports shipping it as a runtime asset.
> - Preserve XDRInternals repo conventions.
