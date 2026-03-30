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

    .PARAMETER Raw
        Returns the raw payload for the selected service view.

    .PARAMETER RawJson
        Returns the raw payload for the selected service view serialized as formatted JSON.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        function Resolve-ServiceCanonicalName {
            param (
                [Parameter(Mandatory)]
                [string]$RequestedName
            )

            switch ($RequestedName) {
                'Microsoft365Lighthouse' { return 'M365Lighthouse' }
                'MicrosoftPlanner' { return 'Planner' }
                'MicrosoftToDo' { return 'Todo' }
                'MicrosoftVivaInsights' { return 'VivaInsights' }
                'ModernAuthentication' { return 'ModernAuth' }
                'SearchAndIntelligenceUsageAnalytics' { return 'SearchIntelligenceAnalytics' }
                default { return $RequestedName }
            }
        }

        function Add-ServiceTypeName {
            param (
                [Parameter(Mandatory)]
                $InputObject,

                [Parameter(Mandatory)]
                [string]$CanonicalName
            )

            return Add-M365TypeName -InputObject $InputObject -TypeName ("M365Admin.Service.{0}" -f $CanonicalName)
        }

        function Get-ServiceResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [string]$Path
            )

            try {
                $result = Get-M365AdminPortalData -Path $Path -CacheKey "M365AdminService:$ResultName" -Force:$Force
            }
            catch {
                $result = New-M365AdminUnavailableResult -Name $ResultName -Description 'This service configuration endpoint currently does not return a usable payload in the current tenant.' -Reason 'TenantSpecific' -ErrorMessage $_.Exception.Message
            }

            return Add-ServiceTypeName -InputObject $result -CanonicalName $ResultName
        }

        $canonicalName = Resolve-ServiceCanonicalName -RequestedName $Name

        switch ($canonicalName) {
            'AccountLinking' { return Get-M365AdminSearchSetting -Name AccountLinking -Force:$Force -Raw:$Raw -RawJson:$RawJson }
            'AdoptionScore' { return Get-M365AdminReportSetting -Name AdoptionScore -Force:$Force -Raw:$Raw -RawJson:$RawJson }
            'BrandCenter' { return Get-M365AdminBrandCenterSetting -Force:$Force -Raw:$Raw -RawJson:$RawJson }
            'Microsoft365Groups' { return Get-M365AdminMicrosoft365GroupSetting -Force:$Force -Raw:$Raw -RawJson:$RawJson }
            'Microsoft365InstallationOptions' { return Get-M365AdminMicrosoft365InstallationOption -Force:$Force -Raw:$Raw -RawJson:$RawJson }
            'MicrosoftAzureInformationProtection' {
                $result = New-M365AdminUnavailableResult -Name 'Microsoft Azure Information Protection' -Description 'This Org settings flyout is informational in the current tenant and did not issue a dedicated admin API request during live capture.' -Reason 'Informational'
                $result = Add-ServiceTypeName -InputObject $result -CanonicalName $canonicalName
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'MicrosoftEdgeSiteLists' { return Get-M365AdminEdgeSiteList -Force:$Force -Raw:$Raw -RawJson:$RawJson }
            'News' { return Get-M365AdminSearchSetting -Name News -Force:$Force -Raw:$Raw -RawJson:$RawJson }
            'PayAsYouGoServices' { return Get-M365AdminPayAsYouGoService -Force:$Force -Raw:$Raw -RawJson:$RawJson }
            'PeopleSettings' { return Get-M365AdminPeopleSetting -Force:$Force -Raw:$Raw -RawJson:$RawJson }
            'Reports' { return Get-M365AdminReportSetting -Name Reports -Force:$Force -Raw:$Raw -RawJson:$RawJson }
            'Sales' {
                $result = New-M365AdminUnavailableResult -Name 'Sales' -Description 'This Org settings flyout currently appears informational in the tenant. Live capture showed descriptive content but no stable dedicated settings endpoint.' -Reason 'Informational'
                $result = Add-ServiceTypeName -InputObject $result -CanonicalName $canonicalName
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'SelfServiceTrialsAndPurchases' { return Get-M365AdminSelfServicePurchaseSetting -Force:$Force -Raw:$Raw -RawJson:$RawJson }
            'WhatsNewInMicrosoft365' {
                $result = New-M365AdminUnavailableResult -Name "What's new in Microsoft 365" -Description 'The current tenant shows an informational page stating that updates to this surface are on hold.' -Status 'UpdatesOnHold' -Reason 'Informational'
                $result = Add-ServiceTypeName -InputObject $result -CanonicalName $canonicalName
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
        }

        $path = switch ($canonicalName) {
            'AzureSpeechServices' { '/admin/api/services/apps/azurespeechservices' }
            'Cortana' { '/admin/api/services/apps/cortana' }
            'DeveloperPortal' { '/admin/api/services/apps/developerportal' }
            'DeveloperPortalForTeams' { '/admin/api/services/apps/developerportal' }
            'M365Lighthouse' { '/admin/api/services/apps/m365lighthouse' }
            'Planner' { '/admin/api/services/apps/planner' }
            'Todo' { '/admin/api/services/apps/todo' }
            'VivaInsights' { '/admin/api/services/apps/vivainsights' }
            'ModernAuth' { '/admin/api/services/apps/modernAuth' }
            'SearchIntelligenceAnalytics' { '/admin/api/services/apps/searchintelligenceanalytics' }
        }

        $result = Get-ServiceResult -ResultName $canonicalName -Path $path
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}