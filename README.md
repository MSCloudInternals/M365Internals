![](./images/m365internals-banner.jpg "M365Internals")

# M365Internals

Welcome to M365Internals, the unofficial PowerShell module to interact with the Microsoft 365 admin center. The module provides direct access to the same portal-backed APIs used by `admin.cloud.microsoft`, so you can script and automate tenant, settings, search, Viva, reporting, navigation, and related admin-center data.

## Description

M365Internals is a PowerShell module that provides direct access to Microsoft 365 admin center portal APIs. It enables automation and scripting capabilities for managing and querying Microsoft 365 admin resources including tenant configuration, company settings, domains, groups, recommendations, reporting, search, security settings, and related portal metadata.

## Disclaimer

This is an unofficial, community-driven project and is not affiliated with, endorsed by, or supported by Microsoft. This module interacts with undocumented APIs that may change without notice.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

USE AT YOUR OWN RISK. The authors and contributors are not responsible for any issues, data loss, or security implications that may arise from using this module.

## Key Features

### Caching Functionality

Many cmdlets in this module implement intelligent caching to improve performance and reduce repeated portal calls:

- Cached data is stored in memory with tenant-aware cache keys
- Default cache duration varies by cmdlet, typically between 5 and 15 minutes
- Many read cmdlets support the `-Force` parameter to bypass cache and retrieve fresh data
- Cached responses are automatically refreshed when they expire

Example:
```powershell
# First call retrieves from the admin center and caches the result
Get-M365AdminShellInfo

# Second call uses cached data if it is still valid
Get-M365AdminShellInfo

# Force a fresh retrieval
Get-M365AdminShellInfo -Force
```

### Result Shapes

Most cmdlets are designed to be useful interactively first, while still exposing the underlying portal-backed data.

- Page and feature-family cmdlets often return grouped objects that mirror the major sections or tabs of the admin center.
- Smaller cmdlets often return a direct payload or a small composite of related payloads.
- When a tenant-specific section is unavailable, the cmdlet should return a structured informational object instead of failing the whole command when possible.

In practice, this means `-Name All` is intended to help you explore an area quickly, while narrower `-Name` values let you retrieve one section at a time.

### Standardized Unavailable Results

When a tenant-specific, optional, or informational sub-surface does not return usable data, many cmdlets now return a standardized object instead of failing the full command.

- These objects use the `M365Admin.UnavailableResult` type name.
- Common fields include `Name`, `Status`, `Reason`, `Description`, and `Error`.
- This makes it easier to script against partial results without parsing exception text.

Example:
```powershell
$result = Get-M365AdminTenantRelationship -Name MultiTenantCollaboration

$result.UserSyncAppOutboundDetails | Format-List Name, Status, Reason, Description
```

### Friendly Output And Raw Output

When it makes sense, the module prefers a more user-friendly default output instead of returning the portal payload exactly as-is.

- Friendly output is easier to scan and script against for common admin tasks.
- Raw output is better when you need to inspect the original admin-center response shape.

Several cmdlets now support both `-Raw` and `-RawJson` and return a friendlier summarized or page-oriented object by default:

```powershell
# Friendly summarized output
Get-M365AdminBookingsSetting

# Original admin-center payload
Get-M365AdminBookingsSetting -Raw

# Original admin-center payload as formatted JSON
Get-M365AdminBookingsSetting -RawJson

# Page-oriented default output
Get-M365AdminCopilotSetting

# Underlying leaf payload bundle
Get-M365AdminCopilotSetting -Raw

# Page-oriented default output
Get-M365AdminSearchAndIntelligenceSetting

# Underlying leaf payload bundle
Get-M365AdminSearchAndIntelligenceSetting -Raw

# Raw company settings payload as formatted JSON
Get-M365AdminCompanySetting -Name Profile -RawJson
```

This same `friendly by default, raw on demand` pattern now applies broadly across the Settings-family getters, including app, company, security, people, search, report, tenant, user, Viva, Microsoft Edge, Microsoft 365 Backup, and related Org settings cmdlets.

### Validation Status

The current publish-readiness pass included authenticated live validation against `admin.cloud.microsoft` by using a software passkey-backed session.

- The public cmdlet surface was exercised in five live validation batches.
- Validation confirmed the current request shapes for mixed GET and POST cmdlets such as `Get-M365AdminUserSetting`.
- Software passkey-backed validation is currently more reliable than saved-cookie reuse for broad live testing.
- Maintainers can now run `./build/run-maintainer-validation.ps1` for the standard Pester pass and optionally append one or more live scripts with `-LiveScript`.

Known tenant-specific or optional sections should still be expected to return structured informational results instead of hard failures when the live portal behaves the same way.

### Confirmed Write Coverage

The module now exposes write-capable cmdlets for the Settings-family routes that accepted live no-op payload replays from the authenticated admin-center session.

- `Set-M365AdminAppSetting` continues to cover the app settings routes that already supported reversible write validation.
- `Set-M365AdminUserOwnedAppSetting` continues to cover Office Store access, trials, and auto-claim licensing policy.
- `Set-M365AdminCompanySetting` now covers Help Desk, Profile, Release Track, Send From Address, Theme, and Tile payloads.
- `Set-M365AdminSecuritySetting` now covers Bing data collection, data access, guest policy, guest access, password policy, privacy policy, tenant lockbox, security defaults, and the People-backed name-pronunciation and pronouns security surfaces.
- `Set-M365AdminPeopleSetting` now covers the direct People toggles for name pronunciation and pronouns.
- `Set-M365AdminMicrosoft365GroupSetting` now covers the Microsoft 365 Groups guest access and guest user policy payloads.

For higher-impact Settings routes, live validation used no-op roundtrips with the current payload to confirm the method and body contract without changing tenant state. Lower-risk toggles such as Bing data collection, name pronunciation, and pronouns were also exercised with reversible live mutations.

## Available Cmdlets

### Connect Cmdlets

| Cmdlet | Description |
| --- | --- |
| Connect-M365Portal | Connect to the Microsoft 365 admin center by using cookies, existing sessions, or built-in auth flows |
| Connect-M365PortalByBrowser | Connect to the Microsoft 365 admin center by using an interactive browser sign-in |
| Connect-M365PortalByCredential | Connect to the Microsoft 365 admin center by using username/password and optional MFA |
| Connect-M365PortalByEstsCookie | Connect to the Microsoft 365 admin center by exchanging an ESTS authentication cookie |
| Connect-M365PortalByPhoneSignIn | Connect to the Microsoft 365 admin center by using Microsoft Authenticator phone sign-in |
| Connect-M365PortalBySoftwarePasskey | Connect to the Microsoft 365 admin center by using a local or Azure Key Vault-backed software passkey |
| Connect-M365PortalBySSO | Connect to the Microsoft 365 admin center by using browser-based single sign-on |
| Connect-M365PortalByTemporaryAccessPass | Connect to the Microsoft 365 admin center by using a Temporary Access Pass |

### Get Cmdlets

| Cmdlet | Description |
| --- | --- |
| Get-M365AdminAgent | Retrieve the Agents > All agents route-family payloads |
| Get-M365AdminAgentFrontierAccess | Retrieve the Agents Frontier access policy payload |
| Get-M365AdminAgentOverview | Retrieve Agents overview inventory, adoption, and risky-agent payloads |
| Get-M365AdminAgentSetting | Retrieve Agents settings, sharing, templates, and user-access payloads |
| Get-M365AdminAgentTool | Retrieve Agents tools payloads such as the MCP server inventory |
| Get-M365AdminAppSetting | Retrieve app settings such as Bookings, Mail, Office Online, Office Scripts, Project, Store, and Whiteboard |
| Get-M365AdminBookingsSetting | Retrieve the Bookings org settings flyout with friendly property names |
| Get-M365AdminBrandCenterSetting | Retrieve Brand center configuration and BrandGuide site URL data |
| Get-M365AdminCompanySetting | Retrieve company settings such as profile, help desk, release track, and theme |
| Get-M365AdminContentUnderstandingSetting | Retrieve Content Understanding settings and related admin payloads |
| Get-M365AdminCopilotBillingUsage | Retrieve Copilot Billing & usage tab payloads and billing policy data |
| Get-M365AdminCopilotConnector | Retrieve Copilot Connectors gallery and connection inventory payloads |
| Get-M365AdminCopilotOverview | Retrieve Copilot Overview, Security, Usage, and About payloads |
| Get-M365AdminCopilotPinPolicy | Retrieve the Copilot pin policy payload |
| Get-M365AdminCopilotSetting | Retrieve Copilot Settings optimize and view-all payloads |
| Get-M365AdminDirectorySyncError | Retrieve directory sync error rows from the admin center settings surface |
| Get-M365AdminDomain | Retrieve domain inventory, records, DNS health, and dependency data |
| Get-M365AdminEdgeSiteList | Retrieve Microsoft Edge enterprise site lists and notifications |
| Get-M365AdminEnhancedRestoreStatus | Retrieve Enhanced Restore status by using the admin center Graph proxy |
| Get-M365AdminFeature | Retrieve feature metadata and startup configuration from the admin center |
| Get-M365AdminGroup | Retrieve group lists, labels, and group permission payloads |
| Get-M365AdminHomeData | Retrieve the home page ClassicModernAdminDataStream payload |
| Get-M365AdminIntegratedAppSetting | Retrieve the Settings > Integrated apps landing-page payloads |
| Get-M365AdminMicrosoft365BackupSetting | Retrieve the Settings > Microsoft 365 Backup landing-page payloads |
| Get-M365AdminMicrosoft365GroupSetting | Retrieve Microsoft 365 Groups guest access and ownerless group policy data |
| Get-M365AdminMicrosoft365InstallationOption | Retrieve Microsoft 365 installation options and release-management data |
| Get-M365AdminMicrosoftEdgeSetting | Retrieve the Settings > Microsoft Edge landing-page payloads |
| Get-M365AdminNavigation | Retrieve primary or asynchronous navigation payloads from the admin center |
| Get-M365AdminPartnerClient | Retrieve delegated partner client data for DAP and GDAP scenarios |
| Get-M365AdminPartnerRelationship | Retrieve the Settings > Partner relationships payloads |
| Get-M365AdminPayAsYouGoService | Retrieve pay-as-you-go billing, backup, and Content Understanding payloads |
| Get-M365AdminPeopleSetting | Retrieve People settings such as profile card properties, name pronunciation, and pronouns |
| Get-M365AdminRecommendation | Retrieve recommendations, alerts, and suggestions from the admin center |
| Get-M365AdminReportSetting | Retrieve reporting configuration and productivity score settings |
| Get-M365AdminSearchAndIntelligenceSetting | Retrieve the Settings > Search & intelligence landing-page sections |
| Get-M365AdminSearchSetting | Retrieve search configuration, result types, QnA, news, and connector data |
| Get-M365AdminSecuritySetting | Retrieve security settings such as MFA, guest access, and security defaults |
| Get-M365AdminSelfServicePurchaseSetting | Retrieve self-service trials and purchases product policy data |
| Get-M365AdminService | Retrieve service configuration such as Modern Auth, Planner, and Viva data |
| Get-M365AdminShellInfo | Retrieve coordinated bootstrap shell information from the admin center |
| Get-M365AdminTenantRelationship | Retrieve multi-tenant organization and user sync relationship data |
| Get-M365AdminTenantSetting | Retrieve tenant settings such as account SKUs, data location, and privacy state |
| Get-M365AdminUserOwnedAppSetting | Retrieve user-owned apps and services settings such as store access, in-app purchases, and auto-claim policy |
| Get-M365AdminUserSetting | Retrieve current-user, role, product, dashboard-layout, and token-broker admin data |
| Get-M365AdminVivaSetting | Retrieve Viva module, role, and Glint client lookup settings |

### Set Cmdlets

| Cmdlet | Description |
| --- | --- |
| Set-M365AdminAgentFrontierAccess | Update the Agents Frontier access policy by merging provided values into the current payload |
| Set-M365AdminAppSetting | Update an app settings payload by merging provided values into the current admin-center payload |
| Set-M365AdminCompanySetting | Update supported company settings payloads such as Help Desk, Profile, Release Track, Theme, and Tile |
| Set-M365AdminCopilotPinPolicy | Update the Copilot pin policy by merging provided values into the current payload |
| Set-M365AdminMicrosoft365GroupSetting | Update Microsoft 365 Groups guest access and guest user policy payloads |
| Set-M365AdminPeopleSetting | Update the People name-pronunciation and pronouns payloads |
| Set-M365AdminSecuritySetting | Update supported security settings payloads such as Bing data collection, guest access, privacy policy, and security defaults |
| Set-M365AdminUserOwnedAppSetting | Update Office Store access, trials, and auto-claim settings for user-owned apps and services |

### Invoke Cmdlets

| Cmdlet | Description |
| --- | --- |
| Invoke-M365AdminRestMethod | Invoke authenticated REST requests against `admin.cloud.microsoft` |

## Installation

### From the PowerShell Gallery

`M365Internals` is not published to the PowerShell Gallery yet. Once it is published, installation will look like this:

```powershell
# Install the module from the PowerShell Gallery
Install-Module M365Internals

# Import the module
Import-Module M365Internals
```

### From GitHub

```powershell
# Clone the repository
git clone https://github.com/MSCloudInternals/M365Internals.git

# Import the module
Import-Module .\M365Internals\M365Internals.psd1
```

## Usage

### Authentication notes

- `Connect-M365Portal` defaults to the interactive browser sign-in flow for interactive use and remains the main umbrella entrypoint for the built-in auth methods.
- `Connect-M365Portal -Credential` and `Connect-M365PortalByCredential` support username/password sign-in and optional Authenticator TOTP completion through `-TotpSecret`.
- `Connect-M365PortalByPhoneSignIn` starts the Microsoft Authenticator phone sign-in flow for passwordless approval scenarios.
- `Connect-M365PortalByTemporaryAccessPass` uses a Temporary Access Pass for bootstrap, recovery, or other short-lived sign-in scenarios.
- `Connect-M365PortalBySoftwarePasskey` requires PowerShell 7.0 or later and supports local or Azure Key Vault-backed passkeys.
- `Connect-M365PortalByBrowser` and `Connect-M365PortalBySSO` use a dedicated Chromium profile directory to reduce session-restore friction during repeated sign-ins.
- `Connect-M365PortalBySSO` currently supports Windows only.
- Cookie reuse and `Connect-M365PortalByEstsCookie` remain best-effort because the admin portal can still reject stale bootstrap state.

### Authentication examples

```powershell
# Preferred: connect by launching the interactive browser sign-in flow
Connect-M365Portal

# Connect by exchanging an ESTS authentication cookie
Connect-M365Portal -EstsAuthCookieValue $estsCookie

# Connect by reusing core portal cookies and let bootstrap recover AjaxSessionKey when needed
Connect-M365Portal -RootAuthToken $root -SPAAuthCookie $spa -OIDCAuthCookie $oidc

# Connect by using Entra credentials with automatic Authenticator OTP handling
Connect-M365Portal -Credential (Get-Credential) -TotpSecret 'JBSWY3DPEHPK3PXP'

# Connect by using a Temporary Access Pass
$tap = ConvertTo-SecureString 'ABC12345' -AsPlainText -Force
Connect-M365PortalByTemporaryAccessPass -Username 'admin@contoso.com' -TAP $tap

# Connect by using Microsoft Authenticator phone sign-in
Connect-M365PortalByPhoneSignIn -Username 'admin@contoso.com'

# Connect by using an interactive browser session
Connect-M365PortalByBrowser -PrivateSession

# Connect by using browser-based SSO on Windows for now
Connect-M365PortalBySSO -Visible

# Connect by using a local software passkey file
Connect-M365PortalBySoftwarePasskey -KeyFilePath '.\admin.passkey'

# Connect by using an Azure Key Vault-backed software passkey file
Connect-M365PortalBySoftwarePasskey -KeyFilePath '.\admin-kv.passkey' -KeyVaultTenantId '8612f621-73ca-4c12-973c-0da732bc44c2'
```

### Examples

```powershell
# Retrieve admin center shell information
Get-M365AdminShellInfo

# Retrieve the asynchronous navigation payload
Get-M365AdminNavigation -Async

# Retrieve the full feature payload
Get-M365AdminFeature -All

# Retrieve the company profile settings payload
Get-M365AdminCompanySetting -Name Profile

# Update the company Help Desk payload
Set-M365AdminCompanySetting -Name HelpDesk -Settings @{ CustomSupportEnabled = $true } -Confirm:$false

# Update only one company profile field and return the refreshed payload
Set-M365AdminCompanySetting -Name Profile -Settings @{ Name = 'Contoso' } -PassThru -Confirm:$false

# Retrieve the Copilot overview payloads
Get-M365AdminCopilotOverview

# Retrieve the Copilot connectors payloads
Get-M365AdminCopilotConnector

# Retrieve the raw Copilot connectors payload bundle
Get-M365AdminCopilotConnector -Raw

# Retrieve the Copilot Billing & usage payloads
Get-M365AdminCopilotBillingUsage

# Retrieve the raw Copilot Billing & usage payload bundle
Get-M365AdminCopilotBillingUsage -Raw

# Retrieve the Copilot settings payloads
Get-M365AdminCopilotSetting

# Retrieve the current Copilot pin policy
Get-M365AdminCopilotPinPolicy

# Retrieve the current Agents Frontier access policy
Get-M365AdminAgentFrontierAccess

# Update the Copilot pin policy
Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = 1 } -Confirm:$false

# Update the Agents Frontier access policy
Set-M365AdminAgentFrontierAccess -Settings @{ FrontierPolicy = 1 } -Confirm:$false

# Retrieve the raw Copilot settings payload bundle
Get-M365AdminCopilotSetting -Raw

# Retrieve the Agents overview payloads
Get-M365AdminAgentOverview

# Retrieve the All agents payloads
Get-M365AdminAgent

# Retrieve the Agents tools payloads
Get-M365AdminAgentTool

# Retrieve the Agents settings payloads
Get-M365AdminAgentSetting

# Retrieve the raw Agents settings payload bundle
Get-M365AdminAgentSetting -Raw

# Retrieve the summarized Bookings org settings
Get-M365AdminBookingsSetting

# Retrieve the raw Bookings org settings payload
Get-M365AdminBookingsSetting -Raw

# Retrieve People settings org data
Get-M365AdminPeopleSetting

# Update Bing data collection consent
Set-M365AdminSecuritySetting -Name BingDataCollection -Settings @{ IsBingDataCollectionConsented = $false } -Confirm:$false

# Update the People pronouns toggle
Set-M365AdminPeopleSetting -Name Pronouns -Settings @{ isEnabledInOrganization = $true } -Confirm:$false

# Retrieve the canonical service view; legacy aliases such as MicrosoftToDo still resolve here
Get-M365AdminService -Name Todo

# Inspect the modeled interactive-only Account Linking surface metadata
Get-M365AdminSearchSetting -Name AccountLinking

# Inspect the modeled telemetry request metadata
Get-M365AdminPayAsYouGoService -Name Telemetry

# Retrieve an admin-center brokered token for Azure Resource Manager
Get-M365AdminUserSetting -Name TokenWithExpiry -TokenAudience 'https://management.azure.com/'

# Retrieve grouped tenant relationship data and inspect any tenant-specific unavailable sections
Get-M365AdminTenantRelationship -Name MultiTenantCollaboration

# Retrieve domain dependencies for a specific domain
Get-M365AdminDomain -Dependencies -DomainName 'contoso.com' -DependencyKind 1

# Retrieve Microsoft 365 Groups org settings
Get-M365AdminMicrosoft365GroupSetting

# Update the Microsoft 365 Groups guest user policy payload
Set-M365AdminMicrosoft365GroupSetting -Name GuestUserPolicy -Settings @{ AllowGuestInvitations = $false } -Confirm:$false

# Retrieve Microsoft 365 installation options
Get-M365AdminMicrosoft365InstallationOption

# Retrieve Project settings
Get-M365AdminAppSetting -Name Project

# Update Project settings and return the refreshed payload
Set-M365AdminAppSetting -Name Project -Settings @{ IsRoadmapEnabled = $false } -PassThru -Confirm:$false

# Retrieve grouped user-owned apps and services settings
Get-M365AdminUserOwnedAppSetting

# Disable trials while leaving the other user-owned app settings unchanged
Set-M365AdminUserOwnedAppSetting -LetUsersStartTrials $false -PassThru -Confirm:$false

# Retrieve pay-as-you-go service settings
Get-M365AdminPayAsYouGoService

# Retrieve the Search & intelligence landing-page sections
Get-M365AdminSearchAndIntelligenceSetting

# Retrieve the raw Search & intelligence payload bundle
Get-M365AdminSearchAndIntelligenceSetting -Raw

# Retrieve the Integrated apps landing-page payloads
Get-M365AdminIntegratedAppSetting

# Retrieve the Microsoft 365 Backup landing-page payloads
Get-M365AdminMicrosoft365BackupSetting

# Retrieve the directory sync errors list
Get-M365AdminDirectorySyncError

# Retrieve the Partner relationships landing-page payloads
Get-M365AdminPartnerRelationship

# Retrieve the Microsoft Edge landing-page payloads
Get-M365AdminMicrosoftEdgeSetting

# Retrieve fresh shell information without using cache
Get-M365AdminShellInfo -Force

# Invoke a direct authenticated request to the admin center
Invoke-M365AdminRestMethod -Path '/admin/api/coordinatedbootstrap/shellinfo'
```

## License

See LICENSE file for details.
