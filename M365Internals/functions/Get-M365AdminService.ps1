function Get-M365AdminService {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center service configuration data.

    .DESCRIPTION
        Reads service and app configuration payloads from the admin center services apps surface.

    .PARAMETER Name
        The service payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminService -Name ModernAuth

        Retrieves the Modern Auth service configuration payload.

    .OUTPUTS
        Object
        Returns the selected service payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('AccountLinking', 'AdoptionScore', 'AzureSpeechServices', 'BrandCenter', 'Cortana', 'DeveloperPortal', 'DeveloperPortalForTeams', 'M365Lighthouse', 'Microsoft365Groups', 'Microsoft365InstallationOptions', 'Microsoft365Lighthouse', 'MicrosoftAzureInformationProtection', 'MicrosoftEdgeSiteLists', 'MicrosoftPlanner', 'MicrosoftToDo', 'MicrosoftVivaInsights', 'ModernAuth', 'ModernAuthentication', 'News', 'PayAsYouGoServices', 'PeopleSettings', 'Planner', 'Reports', 'Sales', 'SearchAndIntelligenceUsageAnalytics', 'SearchIntelligenceAnalytics', 'SelfServiceTrialsAndPurchases', 'Todo', 'VivaInsights', 'WhatsNewInMicrosoft365')]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    process {
        switch ($Name) {
            'AccountLinking' { return Get-M365AdminSearchSetting -Name AccountLinking -Force:$Force }
            'AdoptionScore' { return Get-M365AdminReportSetting -Name AdoptionScore -Force:$Force }
            'BrandCenter' { return Get-M365AdminBrandCenterSetting -Force:$Force }
            'Microsoft365Groups' { return Get-M365AdminMicrosoft365GroupSetting -Force:$Force }
            'Microsoft365InstallationOptions' { return Get-M365AdminMicrosoft365InstallationOption -Force:$Force }
            'MicrosoftAzureInformationProtection' {
                return [pscustomobject]@{
                    Name       = 'Microsoft Azure Information Protection'
                    Route      = 'RightsManagement'
                    DataBacked = $false
                    Description = 'This Org settings flyout is informational in the current tenant and did not issue a dedicated admin API request during live capture.'
                }
            }
            'MicrosoftEdgeSiteLists' { return Get-M365AdminEdgeSiteList -Force:$Force }
            'News' { return Get-M365AdminSearchSetting -Name News -Force:$Force }
            'PayAsYouGoServices' { return Get-M365AdminPayAsYouGoService -Force:$Force }
            'PeopleSettings' { return Get-M365AdminPeopleSetting -Force:$Force }
            'Reports' { return Get-M365AdminReportSetting -Name Reports -Force:$Force }
            'Sales' {
                return [pscustomobject]@{
                    Name        = 'Sales'
                    Route       = 'VivaSales'
                    DataBacked  = $false
                    Description = 'This Org settings flyout currently appears informational in the tenant. Live capture showed descriptive content but no stable dedicated settings endpoint.'
                }
            }
            'SelfServiceTrialsAndPurchases' { return Get-M365AdminSelfServicePurchaseSetting -Force:$Force }
            'WhatsNewInMicrosoft365' {
                return [pscustomobject]@{
                    Name        = "What's new in Microsoft 365"
                    Route       = 'whatsnew'
                    DataBacked  = $false
                    Status      = 'UpdatesOnHold'
                    Description = 'The current tenant shows an informational page stating that updates to this surface are on hold.'
                }
            }
        }

        $path = switch ($Name) {
            'AzureSpeechServices' { '/admin/api/services/apps/azurespeechservices' }
            'Cortana' { '/admin/api/services/apps/cortana' }
            'DeveloperPortal' { '/admin/api/services/apps/developerportal' }
            'DeveloperPortalForTeams' { '/admin/api/services/apps/developerportal' }
            'M365Lighthouse' { '/admin/api/services/apps/m365lighthouse' }
            'Microsoft365Lighthouse' { '/admin/api/services/apps/m365lighthouse' }
            'MicrosoftPlanner' { '/admin/api/services/apps/planner' }
            'MicrosoftToDo' { '/admin/api/services/apps/todo' }
            'MicrosoftVivaInsights' { '/admin/api/services/apps/vivainsights' }
            'ModernAuth' { '/admin/api/services/apps/modernAuth' }
            'ModernAuthentication' { '/admin/api/services/apps/modernAuth' }
            'Planner' { '/admin/api/services/apps/planner' }
            'SearchAndIntelligenceUsageAnalytics' { '/admin/api/services/apps/searchintelligenceanalytics' }
            'SearchIntelligenceAnalytics' { '/admin/api/services/apps/searchintelligenceanalytics' }
            'Todo' { '/admin/api/services/apps/todo' }
            'VivaInsights' { '/admin/api/services/apps/vivainsights' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminService:$Name" -Force:$Force
    }
}