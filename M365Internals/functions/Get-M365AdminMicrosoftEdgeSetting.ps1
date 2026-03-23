function Get-M365AdminMicrosoftEdgeSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Microsoft Edge settings data.

    .DESCRIPTION
        Reads the Settings > Microsoft Edge landing-page payloads for policy, extension,
        device, and site list management.

    .PARAMETER Name
        The Microsoft Edge payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminMicrosoftEdgeSetting

        Retrieves the primary Microsoft Edge landing-page payloads.

    .OUTPUTS
        Object
        Returns the selected Microsoft Edge payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'ConfigurationPolicies', 'DeviceCount', 'ExtensionFeedback', 'ExtensionPolicies', 'FeatureProfiles', 'SiteLists')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        function Get-EdgeDeviceSummary {
            $deviceResult = Invoke-M365RestMethod -Path '/fd/msgraph/v1.0/devices?$count=true&$top=1' -Headers @{ ConsistencyLevel = 'eventual' }
            [pscustomobject]@{
                Count  = $deviceResult.'@odata.count'
                Sample = @($deviceResult.value)
            }
        }

        if ($Name -eq 'All') {
            [pscustomobject]@{
                ConfigurationPolicies = Get-M365AdminPortalData -Path '/fd/OfficePolicyAdmin/v1.0/edge/policies' -CacheKey 'M365AdminMicrosoftEdgeSetting:ConfigurationPolicies' -Force:$Force
                DeviceCount           = Get-EdgeDeviceSummary
                FeatureProfiles       = Get-M365AdminPortalData -Path '/fd/edgeenterpriseextensionsmanagement/api/featureManagement/profiles' -CacheKey 'M365AdminMicrosoftEdgeSetting:FeatureProfiles' -Force:$Force
                ExtensionPolicies     = Get-M365AdminPortalData -Path '/fd/edgeenterpriseextensionsmanagement/api/policies' -CacheKey 'M365AdminMicrosoftEdgeSetting:ExtensionPolicies' -Force:$Force
                ExtensionFeedback     = Get-M365AdminPortalData -Path '/fd/edgeenterpriseextensionsmanagement/api/extensions/extensionFeedback' -CacheKey 'M365AdminMicrosoftEdgeSetting:ExtensionFeedback' -Force:$Force
                SiteLists             = Get-M365AdminEdgeSiteList -Force:$Force
            }
            return
        }

        if ($Name -eq 'DeviceCount') {
            return Get-EdgeDeviceSummary
        }

        if ($Name -eq 'SiteLists') {
            return Get-M365AdminEdgeSiteList -Force:$Force
        }

        $path = switch ($Name) {
            'ConfigurationPolicies' { '/fd/OfficePolicyAdmin/v1.0/edge/policies' }
            'ExtensionFeedback' { '/fd/edgeenterpriseextensionsmanagement/api/extensions/extensionFeedback' }
            'ExtensionPolicies' { '/fd/edgeenterpriseextensionsmanagement/api/policies' }
            'FeatureProfiles' { '/fd/edgeenterpriseextensionsmanagement/api/featureManagement/profiles' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminMicrosoftEdgeSetting:$Name" -Force:$Force
    }
}