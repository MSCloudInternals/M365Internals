function Get-M365AdminIntegratedAppSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center integrated apps data.

    .DESCRIPTION
        Reads the Settings > Integrated apps payloads used by the integrated apps landing page.

    .PARAMETER Name
        The integrated apps payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw integrated apps payload bundle for the selected view.

    .PARAMETER RawJson
        Returns the raw integrated apps payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminIntegratedAppSetting

        Retrieves the primary integrated apps landing-page payloads.

    .OUTPUTS
        Object
        Returns the selected integrated apps payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('ActionableApps', 'All', 'AppCatalog', 'AvailableApps', 'PopularAppRecommendations', 'Settings')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        switch ($Name) {
            'All' {
                $result = [pscustomobject]@{
                    Settings                  = Get-M365AdminPortalData -Path '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings' -CacheKey 'M365AdminIntegratedAppSetting:Settings' -Force:$Force
                    AppCatalog                = Get-M365AdminPortalData -Path '/fd/addins/api/apps?workloads=AzureActiveDirectory,WXPO,MetaOS,SharePoint' -CacheKey 'M365AdminIntegratedAppSetting:AppCatalog' -Force:$Force
                    AvailableApps             = Get-M365AdminPortalData -Path '/fd/addins/api/availableApps?workloads=MetaOS' -CacheKey 'M365AdminIntegratedAppSetting:AvailableApps' -Force:$Force
                    ActionableApps            = Get-M365AdminPortalData -Path '/fd/addins/api/actionableApps?workloads=MetaOS' -CacheKey 'M365AdminIntegratedAppSetting:ActionableApps' -Force:$Force
                    PopularAppRecommendations = Get-M365AdminPortalData -Path '/fd/addins/api/recommendations/appRecommendations?appRecommendationType=PopularApps' -CacheKey 'M365AdminIntegratedAppSetting:PopularAppRecommendations' -Force:$Force
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.IntegratedAppSetting'
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'Settings' {
                $path = '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings'
            }
            'AppCatalog' {
                $path = '/fd/addins/api/apps?workloads=AzureActiveDirectory,WXPO,MetaOS,SharePoint'
            }
            'AvailableApps' {
                $path = '/fd/addins/api/availableApps?workloads=MetaOS'
            }
            'ActionableApps' {
                $path = '/fd/addins/api/actionableApps?workloads=MetaOS'
            }
            'PopularAppRecommendations' {
                $path = '/fd/addins/api/recommendations/appRecommendations?appRecommendationType=PopularApps'
            }
        }

        $result = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminIntegratedAppSetting:$Name" -Force:$Force
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}