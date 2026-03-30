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

    .PARAMETER Raw
        Returns the raw Microsoft Edge payload for the selected section.

    .PARAMETER RawJson
        Returns the raw Microsoft Edge payload serialized as formatted JSON.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        function Get-EdgeDeviceResult {
            Invoke-M365AdminRestMethod -Path '/fd/msgraph/v1.0/devices?$count=true&$top=1' -Headers @{ ConsistencyLevel = 'eventual' }
        }

        function ConvertTo-EdgeDeviceSummary {
            param (
                [Parameter(Mandatory)]
                $DeviceResult
            )

            $result = [pscustomobject]@{
                Count       = $DeviceResult.'@odata.count'
                Sample      = @($DeviceResult.value)
                RawSettings = $DeviceResult
            }

            return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.MicrosoftEdgeSetting.DeviceCount'
        }

        function Get-EdgeExtensionFeedback {
            $result = Get-M365AdminPortalData -Path '/fd/edgeenterpriseextensionsmanagement/api/extensions/extensionFeedback' -CacheKey 'M365AdminMicrosoftEdgeSetting:ExtensionFeedback' -Force:$Force
            if ($null -ne $result) {
                return $result
            }

            New-M365AdminUnavailableResult -Name 'ExtensionFeedback' -Description 'The Microsoft Edge extension feedback feed returned no data in the current tenant.' -Reason 'TenantSpecific'
        }

        if ($Name -eq 'All') {
            if ($Raw -or $RawJson) {
                $rawResult = [pscustomobject]@{
                    ConfigurationPolicies = Get-M365AdminPortalData -Path '/fd/OfficePolicyAdmin/v1.0/edge/policies' -CacheKey 'M365AdminMicrosoftEdgeSetting:ConfigurationPolicies' -Force:$Force
                    DeviceCount           = Get-EdgeDeviceResult
                    FeatureProfiles       = Get-M365AdminPortalData -Path '/fd/edgeenterpriseextensionsmanagement/api/featureManagement/profiles' -CacheKey 'M365AdminMicrosoftEdgeSetting:FeatureProfiles' -Force:$Force
                    ExtensionPolicies     = Get-M365AdminPortalData -Path '/fd/edgeenterpriseextensionsmanagement/api/policies' -CacheKey 'M365AdminMicrosoftEdgeSetting:ExtensionPolicies' -Force:$Force
                    ExtensionFeedback     = Get-EdgeExtensionFeedback
                    SiteLists             = Get-M365AdminEdgeSiteList -Force:$Force -Raw
                }

                $rawResult = Add-M365TypeName -InputObject $rawResult -TypeName 'M365Admin.MicrosoftEdgeSetting.Raw'
                return Resolve-M365AdminOutput -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
            }

            $deviceResult = Get-EdgeDeviceResult
            $result = [pscustomobject]@{
                ConfigurationPolicies = Get-M365AdminPortalData -Path '/fd/OfficePolicyAdmin/v1.0/edge/policies' -CacheKey 'M365AdminMicrosoftEdgeSetting:ConfigurationPolicies' -Force:$Force
                DeviceCount           = ConvertTo-EdgeDeviceSummary -DeviceResult $deviceResult
                FeatureProfiles       = Get-M365AdminPortalData -Path '/fd/edgeenterpriseextensionsmanagement/api/featureManagement/profiles' -CacheKey 'M365AdminMicrosoftEdgeSetting:FeatureProfiles' -Force:$Force
                ExtensionPolicies     = Get-M365AdminPortalData -Path '/fd/edgeenterpriseextensionsmanagement/api/policies' -CacheKey 'M365AdminMicrosoftEdgeSetting:ExtensionPolicies' -Force:$Force
                ExtensionFeedback     = Get-EdgeExtensionFeedback
                SiteLists             = Get-M365AdminEdgeSiteList -Force:$Force
            }

            $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.MicrosoftEdgeSetting'
            return $result
        }

        if ($Name -eq 'DeviceCount') {
            $deviceResult = Get-EdgeDeviceResult
            $result = ConvertTo-EdgeDeviceSummary -DeviceResult $deviceResult
            return Resolve-M365AdminOutput -DefaultValue $result -RawValue $deviceResult -Raw:$Raw -RawJson:$RawJson
        }

        if ($Name -eq 'SiteLists') {
            return Get-M365AdminEdgeSiteList -Force:$Force -Raw:$Raw -RawJson:$RawJson
        }

        if ($Name -eq 'ExtensionFeedback') {
            return Resolve-M365AdminOutput -DefaultValue (Get-EdgeExtensionFeedback) -Raw:$Raw -RawJson:$RawJson
        }

        $path = switch ($Name) {
            'ConfigurationPolicies' { '/fd/OfficePolicyAdmin/v1.0/edge/policies' }
            'ExtensionPolicies' { '/fd/edgeenterpriseextensionsmanagement/api/policies' }
            'FeatureProfiles' { '/fd/edgeenterpriseextensionsmanagement/api/featureManagement/profiles' }
        }

        $result = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminMicrosoftEdgeSetting:$Name" -Force:$Force
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}