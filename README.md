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

## Available Cmdlets

| Cmdlet                                   | Description                                                                |
| ---------------------------------------- | -------------------------------------------------------------------------- |
| Connect-M365Portal                       | Authenticate to the Microsoft 365 admin center by using cookies or a session |
| Connect-M365PortalBySoftwarePasskey      | Authenticate to the Microsoft 365 admin center by using a local software passkey |
| Get-M365AdminAppSetting                  | Retrieve app settings such as Bookings, Mail, Office Online, Store, and Whiteboard |
| Get-M365AdminBrandCenterSetting          | Retrieve Brand center configuration and BrandGuide site URL data            |
| Get-M365AdminBookingsSetting             | Retrieve the Bookings org settings flyout with friendly property names      |
| Get-M365AdminCompanySetting              | Retrieve company settings such as profile, help desk, release track, and theme |
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
# Clone the repository
git clone https://github.com/MSCloudInternals/M365Internals.git

# Import the module
Import-Module .\M365Internals\M365Internals.psd1
```

## Usage

### Connect to the Microsoft 365 admin center

```powershell
# Connect by exchanging an ESTSAUTHPERSISTENT cookie
Connect-M365Portal -EstsAuthCookieValue $estsCookie
```

```powershell
# Connect by using a local software passkey file
Connect-M365PortalBySoftwarePasskey -KeyFilePath '.\admin.passkey'
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

# Retrieve fresh shell information without using cache
Get-M365AdminShellInfo -Force

# Invoke a direct authenticated request to the admin center
Invoke-M365RestMethod -Path '/admin/api/coordinatedbootstrap/shellinfo'
```

## License

See LICENSE file for details.
