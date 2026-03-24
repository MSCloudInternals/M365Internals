# Description

This is the folder, where all the tests go.

Those are subdivided in two categories:

 - General
 - Function

## General Tests

General tests are function generic and test for general policies.

These test scan answer questions such as:

 - Is my module following my style guides?
 - Does any of my scripts have a syntax error?
 - Do my scripts use commands I do not want them to use?
 - Do my commands follow best practices?
 - Do my commands have proper help?

Basically, these allow a general module health check.

These tests are already provided as part of the template.

## Function Tests

A healthy module should provide unit and integration tests for the commands & components it ships.
Only then can be guaranteed, that they will actually perform as promised.

However, as each such test must be specific to the function it tests, there cannot be much in the way of templates.

## Maintainer Validation Workflow

The repository currently uses two validation layers during publish-readiness work:

- Standard repository validation via `./tests/pester.ps1`
- Authenticated live admin-center validation via the helper scripts under `TestResults/`

### Standard Validation

Run the standard suite from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File .\tests\pester.ps1
```

This covers manifest integrity, help coverage, file policies, and PSScriptAnalyzer rules.

### Live Validation

The live validation harness is intended for maintainers working with a real tenant and a local
software passkey file.

Current scripts:

- `TestResults/live-cmdlet-batch.ps1`: the primary batched live validation harness
- `TestResults/live-cmdlet-smoke.ps1`: the earlier monolithic harness kept for comparison and ad hoc use
- `TestScripts/Validate-AdminMenuCmdlets.ps1`: a deeper comparison-oriented maintainer validation script

Typical batch execution sequence:

```powershell
pwsh -NoLogo -NoProfile -File .\TestResults\live-cmdlet-batch.ps1 -BatchName Batch1
pwsh -NoLogo -NoProfile -File .\TestResults\live-cmdlet-batch.ps1 -BatchName Batch2
pwsh -NoLogo -NoProfile -File .\TestResults\live-cmdlet-batch.ps1 -BatchName Batch3
pwsh -NoLogo -NoProfile -File .\TestResults\live-cmdlet-batch.ps1 -BatchName Batch4
pwsh -NoLogo -NoProfile -File .\TestResults\live-cmdlet-batch.ps1 -BatchName Batch5
```

Each batch writes JSONL output into `TestResults/BatchX-results.jsonl` unless `-OutputPath` is specified.

### Current Baseline Classification

As of 2026-03-24, the standard repository validation suite is currently clean.

- `pwsh -NoLogo -NoProfile -File .\tests\pester.ps1` completed with `All 6344 tests executed without a single failure!`
- The earlier publish-readiness backlog items were resolved during the current polish pass.

Recently resolved during the current publish-readiness pass:

- `TestScripts/Validate-AdminMenuCmdlets.ps1`: removed `Set-Location` usage so the script no longer fails the repository file-policy test
- Internal helper analyzer debt in portal bootstrap and passkey helpers: empty catches now emit verbose diagnostics instead of remaining silent
- Internal naming and output metadata warnings: updated helper naming and `OutputType` metadata where needed

### Recommended Maintainer Order

1. Run `./tests/pester.ps1` first to catch static and policy regressions.
2. Re-authenticate with the software passkey before live validation if using a new PowerShell session.
3. Run the five live batch scripts from `TestResults/`.
4. Review any structured `M365Admin.UnavailableResult` objects before treating a live scenario as a failure, because some endpoints are tenant-conditional by design.
5. Re-run `./tests/pester.ps1` after validation-script edits so maintainer-only scripts do not add new analyzer debt.