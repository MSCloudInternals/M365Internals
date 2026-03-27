# M365Ray

M365Ray is a DevTools extension for the Microsoft 365 admin portal that watches `admin.cloud.microsoft` traffic and maps recognized requests to `M365Internals` cmdlets.

## Features

- Captures `admin.cloud.microsoft` requests for `/admin/api/`, `/adminportal/home/ClassicModernAdminDataStream`, and `fd/msgraph`.
- Maps recognized requests to the exported `M365Internals` cmdlets by using `CmdletApiMapping.json`.
- Falls back to `Invoke-M365AdminRestMethod` when no native cmdlet match is available.
- Stores request bodies through the background script so payloads remain visible in the panel.
- Provides guarded access to the admin portal cookies required by `Connect-M365Portal`.

## Installation

1. Open your browser extensions page.
2. Enable developer mode.
3. Load the `M365Ray` folder as an unpacked extension.
4. Open `https://admin.cloud.microsoft` and then open DevTools.
5. Use the `M365Ray` panel to inspect captured requests and copy the generated PowerShell.

## Notes

- The generated PowerShell is best-effort and should be reviewed before you run it.
- Native cmdlet mappings intentionally prefer public `M365Internals` cmdlets over raw replay snippets.
- Cookie copying is intended for local, temporary debugging only.
- The danger zone exposes sensitive admin portal cookies. Treat them like live credentials.
