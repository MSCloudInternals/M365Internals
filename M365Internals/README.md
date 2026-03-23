![](../images/m365internals-banner.jpg "M365Internals")

# M365Internals

Welcome to the M365Internals module folder. This is the PowerShell implementation behind the repository, containing the exported cmdlets, internal helpers, manifest, format definitions, and session plumbing used to interact with the Microsoft 365 admin center.

## Description

This folder contains the actual M365Internals PowerShell module. The implementation is specific to `admin.cloud.microsoft` and includes connection handling, read-only admin-center cmdlets, Graph-proxy helpers, REST utilities, cache support, and shared portal request/session logic.

## Disclaimer

This is an unofficial, community-driven project and is not affiliated with, endorsed by, or supported by Microsoft. This module interacts with undocumented APIs that may change without notice.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

USE AT YOUR OWN RISK. The authors and contributors are not responsible for any issues, data loss, or security implications that may arise from using this module.

## Key Features

### Module Layout

The module follows the same high-level structure as XDRInternals, adapted for Microsoft 365 admin-center APIs:

- `functions/` contains exported cmdlets such as `Connect-M365Portal`, `Connect-M365PortalBySoftwarePasskey`, the `Get-M365Admin*` family, and `Invoke-M365RestMethod`
- `internal/functions/` contains helper functions for cache management, session state, portal request handling, Graph proxy access, and software-passkey authentication
- `internal/scripts/` contains support script space for future initialization or helper workflows
- `M365Internals.psd1` is the module manifest
- `M365Internals.psm1` loads the module content from the folder structure above
- `M365Internals.Format.ps1xml` contains custom formatting definitions for module output types

### Caching Functionality

The module includes shared in-memory caching for portal metadata and repeated read operations:

- Cache entries are tenant-aware and scoped to the active portal connection when possible
- Read-heavy cmdlets commonly support `-Force` to bypass cache
- Common bootstrap and settings data can be reused across repeated calls in the same session

Example:
```powershell
# Retrieve and cache shell information
Get-M365AdminShellInfo

# Bypass the cache for a fresh response
Get-M365AdminShellInfo -Force
```

## Available Cmdlets

| Cmdlet                                   | Description                                                                |
| ---------------------------------------- | -------------------------------------------------------------------------- |
| Connect-M365Portal                       | Authenticate to the Microsoft 365 admin center by using cookies or a session |
| Connect-M365PortalBySoftwarePasskey      | Authenticate to the Microsoft 365 admin center by using a local software passkey |
| Get-M365AdminAppSetting                  | Retrieve app settings such as Bookings, Mail, Office Online, Store, and Whiteboard |
| Get-M365AdminBrandCenterSetting          | Retrieve Brand center configuration and BrandGuide site URL data            |
| Get-M365AdminBookingsSetting             | Retrieve the Bookings org settings flyout with friendly property names      |
| Get-M365AdminCompanySetting              | Retrieve company settings such as profile, help desk, release track, and theme |
| Get-M365AdminCopilotBillingUsage         | Retrieve Copilot Billing & usage tab payloads and billing policy data      |
| Get-M365AdminCopilotConnector            | Retrieve Copilot Connectors gallery and connection inventory payloads      |
| Get-M365AdminCopilotOverview             | Retrieve Copilot Overview, Security, Usage, and About payloads             |
| Get-M365AdminCopilotSetting              | Retrieve Copilot Settings optimize and view-all payloads                   |
| Get-M365AdminContentUnderstandingSetting | Retrieve Content Understanding settings and related admin payloads          |
| Get-M365AdminDirectorySyncError          | Retrieve directory sync error rows from the admin center settings surface   |
| Get-M365AdminDomain                      | Retrieve domain inventory, records, DNS health, and dependency data        |
| Get-M365AdminEdgeSiteList                | Retrieve Microsoft Edge enterprise site lists and notifications             |
| Get-M365AdminEnhancedRestoreStatus       | Retrieve Enhanced Restore status by using the admin center Graph proxy      |
| Get-M365AdminFeature                     | Retrieve feature metadata and startup configuration from the admin center   |
| Get-M365AdminGroup                       | Retrieve group lists, labels, and group permission payloads                |
| Get-M365AdminHomeData                    | Retrieve the home page ClassicModernAdminDataStream payload                |
| Get-M365AdminIntegratedAppSetting        | Retrieve the Settings > Integrated apps landing-page payloads              |
| Get-M365AdminMicrosoft365BackupSetting   | Retrieve the Settings > Microsoft 365 Backup landing-page payloads         |
| Get-M365AdminMicrosoft365GroupSetting    | Retrieve Microsoft 365 Groups guest access and ownerless group policy data |
| Get-M365AdminMicrosoft365InstallationOption | Retrieve Microsoft 365 installation options and release-management data |
| Get-M365AdminMicrosoftEdgeSetting        | Retrieve the Settings > Microsoft Edge landing-page payloads               |
| Get-M365AdminNavigation                  | Retrieve primary or asynchronous navigation payloads from the admin center |
| Get-M365AdminPayAsYouGoService           | Retrieve pay-as-you-go billing, backup, and Content Understanding payloads |
| Get-M365AdminPartnerClient               | Retrieve delegated partner client data for DAP and GDAP scenarios          |
| Get-M365AdminPartnerRelationship         | Retrieve the Settings > Partner relationships payloads                     |
| Get-M365AdminPeopleSetting               | Retrieve People settings such as profile card properties, name pronunciation, and pronouns |
| Get-M365AdminRecommendation              | Retrieve recommendations, alerts, and suggestions from the admin center    |
| Get-M365AdminReportSetting               | Retrieve reporting configuration and productivity score settings           |
| Get-M365AdminSearchAndIntelligenceSetting | Retrieve the Settings > Search & intelligence landing-page sections       |
| Get-M365AdminSearchSetting               | Retrieve search configuration, result types, QnA, news, and connector data |
| Get-M365AdminSecuritySetting             | Retrieve security settings such as MFA, guest access, and security defaults |
| Get-M365AdminSelfServicePurchaseSetting  | Retrieve self-service trials and purchases product policy data             |
| Get-M365AdminService                     | Retrieve service configuration such as Modern Auth, Planner, and Viva data |
| Get-M365AdminShellInfo                   | Retrieve coordinated bootstrap shell information from the admin center     |
| Get-M365AdminTenantRelationship          | Retrieve multi-tenant organization and user sync relationship data         |
| Get-M365AdminTenantSetting               | Retrieve tenant settings such as account SKUs, data location, and privacy state |
| Get-M365AdminUserSetting                 | Retrieve current-user, role, product, and dashboard-layout admin data      |
| Get-M365AdminVivaSetting                 | Retrieve Viva module, role, and Glint client lookup settings               |
| Invoke-M365RestMethod                    | Invoke authenticated REST requests against `admin.cloud.microsoft`         |

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
# Import the module directly from the repository root
Import-Module .\M365Internals.psd1
```

## Usage

### Import the module locally

```powershell
Import-Module .\M365Internals.psd1
```

### Examples

```powershell
# Connect by exchanging an ESTSAUTHPERSISTENT cookie
Connect-M365Portal -EstsAuthCookieValue $estsCookie

# Connect by using a local software passkey file
Connect-M365PortalBySoftwarePasskey -KeyFilePath '.\admin.passkey'

# Retrieve company profile settings
Get-M365AdminCompanySetting -Name Profile

# Retrieve the Copilot overview payloads
Get-M365AdminCopilotOverview

# Retrieve the Copilot connectors payloads
Get-M365AdminCopilotConnector

# Retrieve the Copilot Billing & usage payloads
Get-M365AdminCopilotBillingUsage

# Retrieve the Copilot settings payloads
Get-M365AdminCopilotSetting

# Retrieve the summarized Bookings org settings
Get-M365AdminBookingsSetting

# Retrieve People settings org data
Get-M365AdminPeopleSetting

# Retrieve Microsoft 365 Groups org settings
Get-M365AdminMicrosoft365GroupSetting

# Retrieve Microsoft 365 installation options
Get-M365AdminMicrosoft365InstallationOption

# Retrieve pay-as-you-go service settings
Get-M365AdminPayAsYouGoService

# Retrieve the Search & intelligence landing-page sections
Get-M365AdminSearchAndIntelligenceSetting

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

# Invoke an authenticated admin-center request directly
Invoke-M365RestMethod -Path '/admin/api/coordinatedbootstrap/shellinfo'
```

## License

See LICENSE file for details.