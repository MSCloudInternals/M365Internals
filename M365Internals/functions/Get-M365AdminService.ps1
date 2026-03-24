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
        function Get-ServiceResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [string]$Path
            )

            try {
                return Get-M365AdminPortalData -Path $Path -CacheKey "M365AdminService:$ResultName" -Force:$Force
            }
            catch {
                return New-M365AdminUnavailableResult -Name $ResultName -Description 'This service configuration endpoint currently does not return a usable payload in the current tenant.' -Reason 'TenantSpecific' -ErrorMessage $_.Exception.Message
            }
        }

        switch ($Name) {
            'AccountLinking' { return Get-M365AdminSearchSetting -Name AccountLinking -Force:$Force }
            'AdoptionScore' { return Get-M365AdminReportSetting -Name AdoptionScore -Force:$Force }
            'BrandCenter' { return Get-M365AdminBrandCenterSetting -Force:$Force }
            'Microsoft365Groups' { return Get-M365AdminMicrosoft365GroupSetting -Force:$Force }
            'Microsoft365InstallationOptions' { return Get-M365AdminMicrosoft365InstallationOption -Force:$Force }
            'MicrosoftAzureInformationProtection' {
                return New-M365AdminUnavailableResult -Name 'Microsoft Azure Information Protection' -Description 'This Org settings flyout is informational in the current tenant and did not issue a dedicated admin API request during live capture.' -Reason 'Informational'
            }
            'MicrosoftEdgeSiteLists' { return Get-M365AdminEdgeSiteList -Force:$Force }
            'News' { return Get-M365AdminSearchSetting -Name News -Force:$Force }
            'PayAsYouGoServices' { return Get-M365AdminPayAsYouGoService -Force:$Force }
            'PeopleSettings' { return Get-M365AdminPeopleSetting -Force:$Force }
            'Reports' { return Get-M365AdminReportSetting -Name Reports -Force:$Force }
            'Sales' {
                return New-M365AdminUnavailableResult -Name 'Sales' -Description 'This Org settings flyout currently appears informational in the tenant. Live capture showed descriptive content but no stable dedicated settings endpoint.' -Reason 'Informational'
            }
            'SelfServiceTrialsAndPurchases' { return Get-M365AdminSelfServicePurchaseSetting -Force:$Force }
            'WhatsNewInMicrosoft365' {
                return New-M365AdminUnavailableResult -Name "What's new in Microsoft 365" -Description 'The current tenant shows an informational page stating that updates to this surface are on hold.' -Status 'UpdatesOnHold' -Reason 'Informational'
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

        Get-ServiceResult -ResultName $Name -Path $path
    }
}