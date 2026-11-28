# Milestone 1 validation handoff

The runs used a fresh Paseo worktree on `paseo-lxc` on 2026-11-28. GitHub and the local `origin/main` agreed on baseline commit `3ce351e7eead57463367dc21a4af4416e67592ee`. The implementation run used `caba652fb22ed03eebcbcd22b84d3e7cd7415656`. Node was 24.22.3. Both shells had Pester 5.7.1 and 6.2.0 available, and the maintainer runner loaded 6.2.0 by name in all four runs. Both suites ran offline with respect to the tenant.

| Run | Executable | PowerShell | Loaded Pester | Maintainer pass / fail / skip / total | MCP pass / fail / skip / total |
| --- | --- | --- | --- | --- | --- |
| Baseline | `/home/paseo/.local/bin/pwsh` | 7.6.6 | 6.2.0 | 12,161 / 63 / 0 / 12,224 | 5 / 0 / 0 / 5 |
| Baseline | `/usr/bin/pwsh` | 7.7.0 | 6.2.0 | 12,161 / 63 / 0 / 12,224 | 5 / 0 / 0 / 5 |
| Implementation | `/home/paseo/.local/bin/pwsh` | 7.6.6 | 6.2.0 | 12,161 / 63 / 0 / 12,224 | 5 / 0 / 0 / 5 |
| Implementation | `/usr/bin/pwsh` | 7.7.0 | 6.2.0 | 12,161 / 63 / 0 / 12,224 | 5 / 0 / 0 / 5 |

All four maintainer runs exited 1 and all four MCP runs exited 0. Per-test counts come from the NUnit XML. The maintainer summary reports the Pester exception and omits the counts when validation fails. The four runs had the same 63 failing test names and first error lines. Every failure starts with `Should operator 'Be' is not registered` and includes an error loading Pester to resolve `Assert-MockCalled`. Leave these failures open for a Pester compatibility investigation. The recorded comparison used Pester 6.2.0 throughout.

Raw results are under `/tmp/m365-m1.Rodqmu` on `paseo-lxc`, in separate `before-7.6.6`, `before-7.7.0`, `after-7.6.6`, and `after-7.7.0` directories. Each contains the maintainer summary, XML, logs, and exit status. Use `mcp-selected-host.log` and `mcp-selected-host.exit` for the baseline MCP results. Those runs set both `MSCI_PWSH` and `PATH` because the baseline tests used bare `pwsh` and discarded `MSCI_*` variables. The updated tests honor `MSCI_PWSH` for every worker. Use `mcp.log` and `mcp.exit` for the implementation runs.

<details>
<summary>Failing Pester files on both runtimes</summary>

| File | Failed cases |
| --- | ---: |
| `Connect-M365Portal.AuthSurface.Tests.ps1` | 4 |
| `Connect-M365Portal.Wrapper.Tests.ps1` | 6 |
| `Get-M365AdminAgentFrontierAccess.Tests.ps1` | 1 |
| `Get-M365AdminAppSetting.Tests.ps1` | 10 |
| `Get-M365AdminCopilotConnector.Tests.ps1` | 1 |
| `Get-M365AdminCopilotPinPolicy.Tests.ps1` | 1 |
| `Get-M365AdminService.Tests.ps1` | 4 |
| `Get-M365AdminSurfaceConsistency.Tests.ps1` | 2 |
| `Get-M365AdminUserOwnedAppSetting.Tests.ps1` | 3 |
| `Set-M365AdminAgentFrontierAccess.Tests.ps1` | 2 |
| `Set-M365AdminAppSetting.Tests.ps1` | 6 |
| `Set-M365AdminCompanySetting.Tests.ps1` | 3 |
| `Set-M365AdminCopilotConnector.Tests.ps1` | 3 |
| `Set-M365AdminCopilotPinPolicy.Tests.ps1` | 2 |
| `Set-M365AdminMicrosoft365GroupSetting.Tests.ps1` | 2 |
| `Set-M365AdminPeopleSetting.Tests.ps1` | 2 |
| `Set-M365AdminSecuritySetting.Tests.ps1` | 4 |
| `Set-M365AdminUserOwnedAppSetting.Tests.ps1` | 3 |
| `Set-M365PortalConnectionSettings.Tests.ps1` | 4 |

</details>

## Reproduce

Run from the repository on `paseo-lxc`. Refresh the base and create a new worktree. For an exact historical reproduction after main advances, check out the baseline commit above in that worktree.

```bash
git fetch origin main
paseo workspace create --isolation worktree --mode branch-off \
  --new-branch reproduce-milestone-1 --base origin/main
```

In the new worktree, install missing test prerequisites and the locked Node dependencies. For the recorded comparison, verify Pester 6.2.0 is available and check the loaded version in each log.

```bash
"$HOME/.local/bin/pwsh" -NoProfile -File ./build/vsts-prerequisites.ps1
npm --prefix mcp ci --ignore-scripts
node --version
```

Run the following in Bash from the worktree root, once at each commit. It creates a new results directory each time and moves each `TestResults` directory before the next runtime can overwrite it. Start with a fresh worktree or move any existing `TestResults` aside before running.

```bash
results=$(mktemp -d /tmp/m365-validation.XXXXXX)
for exe in "$HOME/.local/bin/pwsh" /usr/bin/pwsh; do
  version=$("$exe" -NoProfile -Command '$PSVersionTable.PSVersion.ToString()')
  dest="$results/$version"
  mkdir -p "$dest/bin"
  printf 'commit=%s\nexecutable=%s\nPowerShell=%s\n' \
    "$(git rev-parse HEAD)" "$exe" "$version" > "$dest/environment.txt"

  maintainer_exit=0
  "$exe" -NoProfile -Command '
    try { ./build/run-maintainer-validation.ps1 -PesterOutput Detailed }
    finally { Get-Module Pester | Select-Object Version,Path | Out-Host }
  ' > "$dest/maintainer.log" 2>&1 || maintainer_exit=$?
  printf '%s\n' "$maintainer_exit" > "$dest/maintainer.exit"
  if [ -d TestResults ]; then
    mv TestResults "$dest/"
  fi

  ln -s "$exe" "$dest/bin/pwsh"
  mcp_exit=0
  PATH="$dest/bin:$PATH" MSCI_PWSH="$exe" npm --prefix mcp test \
    > "$dest/mcp.log" 2>&1 || mcp_exit=$?
  printf '%s\n' "$mcp_exit" > "$dest/mcp.exit"
done
printf 'Results in %s\n' "$results"
```

Use the NUnit XML case names and failure messages when comparing maintainer runs. The Node test log gives MCP pass, fail, and skip counts. The maintainer invocation uses its default empty live-script list.

## Installation and issue #10

A clean PowerShell 7.6.6 shell (`-NoProfile`, no discoverable M365Internals module) cloned current main from GitHub. The old README import failed from the clone's parent directory because the module is nested inside the repository. After entering the clone, importing `./M365Internals/M365Internals.psd1` loaded M365Internals 0.0.1 and exposed 65 commands. The corrected sequence also passed from a fresh clone of the implementation commit.

`Install-Module M365Internals -Repository PSGallery -Scope CurrentUser` in a clean 7.6.6 shell with a temporary user data directory returned "No match was found for the specified search criteria and module name 'M365Internals'." Keep the issue open for Gallery publication. The README now gives the verified GitHub install sequence. [Installation issue #10](https://github.com/MSCloudInternals/M365Internals/issues/10)
