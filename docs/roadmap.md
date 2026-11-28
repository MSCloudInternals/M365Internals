# M365Internals roadmap

Use M365Internals to qualify improvements on the new Paseo hosts, then carry demonstrated improvements to PurviewInternals first and XDRInternals second. PowerShell **7.6+** is the support floor. Legacy 5.1 code may change or break. The compatibility matrix excludes 5.1, 7.2, and 7.4.

## Starting point

At the November 2026 review, main at `443a971` included the read-only M365/Purview MCP server, isolated provider workers, and same-session identity checks. The module and MCP trees matched the lab release branch. The VM-retirement branch at `c960f4e` held eleven commits covering nine open issues. Its reconnect changes overlap merged work. The milestones below describe planned verification on the replacement hosts. [Merged MCP work](https://github.com/MSCloudInternals/M365Internals/pull/21) · [Recovery branch at review](https://github.com/MSCloudInternals/M365Internals/commit/c960f4e)

## Milestone 1 — Reproduce the baseline

Start from refreshed `origin/main` in a clean Paseo worktree on `paseo-lxc`. At review, `~/.local/bin/pwsh` ran 7.6.6 and `/usr/bin/pwsh` ran 7.7.0. Plain `pwsh` selected 7.6.6. Node 24.22.3 met the MCP server's Node 20+ requirement. Set `MSCI_PWSH` explicitly for each MCP run so the worker uses the runtime under test. [Maintainer validation](../build/run-maintainer-validation.ps1) · [MCP setup](../mcp/README.md)

See the [baseline results and reproduction commands](milestone-1-validation.md).

**Acceptance criteria**

- Run maintainer validation and the offline MCP stdio suite on both runtimes before integrating recovery fixes. Preserve separate summaries with commit, executable, loaded Pester version, test counts, and failures. The host has Pester 5.7.1 and 6.2.0, and the runner imports it by name.
- Declare the 7.6 floor in the module manifest, setup docs, and MCP prerequisites. CI exercises 7.6 and 7.7 explicitly.
- Link this roadmap from the README. A maintainer following the handoff from a fresh worktree can reproduce both runs and identify any pre-existing failures.

## Milestone 2 — Recover fixes against current main

Work through the packages in order. Run each recovery regression test against current main first. Port the missing behavior with its test and retain the merged MCP worker coverage. [Issue tracker](https://github.com/MSCloudInternals/M365Internals/issues)

| Package | Issues | Acceptance criteria |
| --- | --- | --- |
| Request and write handling | #20, #12, #13 | Mocked transport confirms authenticated requests stay on the intended portal origin and permitted same-origin reads still succeed. A redirected or failed write reports the outcome, including uncertainty, and stops subsequent setter steps. |
| Connection replacement and confirmation | #17, #15 | Failed reconnect preserves the working session and its caches. A successful account switch clears account-scoped data. A setter stops if its connection changes after preflight. |
| Browser behavior and diagnostics | #14, #16, #18 | Private SSO selects a temporary profile. Local status accurately reports retained-profile availability. Startup errors identify the failing phase. Portable cases pass on Linux and the Windows SSO case passes on `paseo-windows` using a verified supported runtime. |
| Group pagination | #11 | `Get-M365AdminGroup -Name Groups` accepts the returned continuation for page two. Tests cover first, subsequent, and terminal pages and preserve the existing single-page output contract. |

Record a disposition and test result for every recovery issue, including cases already covered on main. Separately, check the advertised installation method from a clean supported shell and record the result for [installation issue #10](https://github.com/MSCloudInternals/M365Internals/issues/10).

## Milestone 3 — Qualify connection replacement and transfer the findings

Use the direct M365 module and the worker-isolated MCP connection to test identity and cache behavior through the same sequence. Draw on Purview's identity-evidence and lab qualification work. Adopt XDR's practice of checking generated cmdlet docs in the feature PR when public parameters or output change. [Purview qualification handoff](https://github.com/MSCloudInternals/PurviewInternals/pull/37) · [XDR documentation validation](https://github.com/MSCloudInternals/XDRInternals/pull/145)

**Acceptance criteria**

- Repeatable offline fixtures cover initial connection, same-account refresh, failed replacement, and successful account switch. Assert active identity and cache state after each transition. The previous connection remains usable after failure. After a switch, reads return only the new account's data.
- On `paseo-lxc`, run a read-only M365 smoke test with an operator-selected local passkey. Verify the expected identity and complete a representative read. Record the cases exercised, verdicts, and counts. Identify the exact transition or read requiring another identity or role if lab coverage is incomplete.
- Run the applicable cases in PurviewInternals, then XDRInternals. For each provider, identify passing cases, reproducible gaps, and cases outside its connection model. Pair each transferred fix with the failing regression case that justifies it.

## Portal coverage after recovery

Resume with the Search & intelligence Configurations read, then determine whether Account Linking has a reproducible direct read. Record the tested tenant conditions and result for each route before expanding its documented coverage. Keep the remaining telemetry, cross-tenant validation, and output consistency work in the existing backlog. [Known issues and follow-up order](../KNOWN_ISSUES.md)
