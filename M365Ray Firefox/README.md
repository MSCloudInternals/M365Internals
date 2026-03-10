# M365Ray (Firefox)

A Firefox-compatible build of the M365Ray DevTools inspector for `admin.cloud.microsoft`.

## Install (Temporary)
1. Open `about:debugging` in Firefox.
2. Click `This Firefox`.
3. Click `Load Temporary Add-on...`.
4. Select `manifest.json` from the `M365Ray Firefox` folder.

Open DevTools and the `M365Ray` panel will be available.

## Notes
- Uses Manifest v2 background scripts for compatibility.
- Captures `admin.cloud.microsoft` admin API, home bootstrap, and Graph proxy requests.
- Maps recognized requests to `M365Internals` cmdlets and falls back to `Invoke-M365RestMethod` for unmatched calls.
- The danger zone exposes the admin portal cookies used by `Connect-M365Portal`.
