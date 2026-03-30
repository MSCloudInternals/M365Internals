function Get-M365AdminSearchSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center search settings.

    .DESCRIPTION
        Reads search administration payloads exposed by the searchadminapi endpoints.

    .PARAMETER Name
        The search settings payload to retrieve.

    .PARAMETER QnasServiceType
        Overrides the ServiceType value used for the QnAs POST payload.

    .PARAMETER QnasFilter
        Overrides the Filter value used for the QnAs POST payload.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw Search settings payload for the selected section.

    .PARAMETER RawJson
        Returns the raw Search settings payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminSearchSetting -Name ModernResultTypes

        Retrieves the modern result types payload.

    .OUTPUTS
        Object
        Returns the selected search settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('AccountLinking', 'Configurations', 'ConfigurationSettings', 'FirstRunExperience', 'ModernResultTypes', 'News', 'NewsIndustry', 'NewsMsbEnabled', 'NewsOptions', 'Pivots', 'Qnas', 'SearchIntelligenceHomeCards', 'UdtConnectorsSummary')]
        [string]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$QnasServiceType = 'Bing',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$QnasFilter = 'Published',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        function Get-SearchPortalData {
            param(
                [Parameter(Mandatory)]
                [string]$Path,

                [Parameter(Mandatory)]
                [string]$CacheKey,

                [Parameter()]
                [ValidateSet('Get', 'Post', 'Put', 'Patch', 'Delete')]
                [string]$Method = 'Get',

                [Parameter()]
                $Body,

                [Parameter()]
                [switch]$Force
            )

            return Get-M365AdminPortalData -Path $Path -CacheKey $CacheKey -Method $Method -Body $Body -Headers (Get-M365PortalContextHeaders -Context MicrosoftSearch) -Force:$Force
        }

        function Add-SearchSettingTypeName {
            param(
                [Parameter(Mandatory)]
                $InputObject,

                [Parameter(Mandatory)]
                [string]$SectionName
            )

            if ($InputObject -and ($InputObject.PSObject.TypeNames -notcontains 'M365Admin.UnavailableResult')) {
                $InputObject = Add-M365TypeName -InputObject $InputObject -TypeName ("M365Admin.SearchSetting.{0}" -f $SectionName)
            }

            return $InputObject
        }

        function Get-CacheToken {
            param(
                [Parameter(Mandatory)]
                [string]$Value
            )

            return ([regex]::Replace($Value, '[^A-Za-z0-9]+', '_')).Trim('_')
        }

        function Get-ConfigurationSettingsResult {
            $result = Get-SearchPortalData -Path '/admin/api/searchadminapi/ConfigurationSettings' -CacheKey 'M365AdminSearchSetting:ConfigurationSettings' -Force:$Force
            return Add-SearchSettingTypeName -InputObject $result -SectionName 'ConfigurationSettings'
        }

        if ($Name -eq 'AccountLinking') {
            $result = New-M365AdminUnavailableResult -Name 'Account Linking' -Description 'The Org settings Account Linking flyout issued an internal browser request during live capture, but a stable same-origin request could not be reproduced outside the portal interaction flow.' -Reason 'InteractiveOnly' -SuggestedAction 'Inspect the live portal with browser DevTools during the Account Linking interaction to capture the backing request shape before adding direct module support.'
            Add-Member -InputObject $result -NotePropertyName PortalRoute -NotePropertyValue '#/Settings/EnterpriseMicrosoftRewards' -Force
            Add-Member -InputObject $result -NotePropertyName DirectReadSupported -NotePropertyValue $false -Force
            Add-Member -InputObject $result -NotePropertyName DiscoveryState -NotePropertyValue 'InteractionBoundRequest' -Force
            Add-Member -InputObject $result -NotePropertyName ObservedInteraction -NotePropertyValue 'Org settings Account Linking flyout' -Force
            $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.SearchSetting.AccountLinking'
            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
        }

        if ($Name -eq 'Configurations') {
            try {
                $result = Get-SearchPortalData -Path '/admin/api/searchadminapi/configurations' -CacheKey 'M365AdminSearchSetting:Configurations' -Force:$Force
                $result = Add-SearchSettingTypeName -InputObject $result -SectionName $Name
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            catch {
                $directResult = New-M365AdminUnavailableResultFromError -Name 'Configurations' -Area 'Search configurations' -ErrorMessage $_.Exception.Message -DefaultDescription 'The Search configurations endpoint is currently unavailable in this tenant and returns the same error state seen in the live portal.' -DefaultReason 'Transient'

                try {
                    $configurationSettings = Get-ConfigurationSettingsResult
                    $friendlyResult = [pscustomobject]@{
                        Status                = 'Fallback'
                        Description           = 'The direct Search configurations endpoint is returning the same service error seen in the live portal. Returning the stable configuration inventory from ConfigurationSettings instead.'
                        DirectConfigurations  = $directResult
                        ConfigurationCount    = @($configurationSettings.Settings).Count
                        ConfigurationSettings = @($configurationSettings.Settings)
                        RawSettings           = $configurationSettings
                    }

                    $friendlyResult = Add-M365TypeName -InputObject $friendlyResult -TypeName 'M365Admin.SearchSetting.Configurations'
                    $rawResult = [pscustomobject]@{
                        DirectConfigurations = $directResult
                        ConfigurationSettings = $configurationSettings
                    }

                    $rawResult = Add-M365TypeName -InputObject $rawResult -TypeName 'M365Admin.SearchSetting.Configurations.Raw'
                    return Resolve-M365AdminOutput -DefaultValue $friendlyResult -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
                }
                catch {
                    $fallbackResult = New-M365AdminUnavailableResultFromError -Name 'ConfigurationSettings' -Area 'Search configuration inventory' -ErrorMessage $_.Exception.Message -DefaultDescription 'The fallback Search configuration inventory also did not return a usable payload.' -DefaultReason 'Transient'
                    $rawResult = [pscustomobject]@{
                        DirectConfigurations = $directResult
                        ConfigurationSettings = $fallbackResult
                    }

                    $rawResult = Add-M365TypeName -InputObject $rawResult -TypeName 'M365Admin.SearchSetting.Configurations.Raw'
                    return Resolve-M365AdminOutput -DefaultValue $directResult -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
                }
            }
        }

        if ($Name -eq 'ConfigurationSettings') {
            $result = Get-ConfigurationSettingsResult
            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
        }

        if ($Name -eq 'FirstRunExperience') {
            try {
                $result = Get-SearchPortalData -Path '/admin/api/searchadminapi/firstrunexperience/get' -CacheKey 'M365AdminSearchSetting:FirstRunExperience' -Method Post -Body @(
                    'SearchHomepageBannerFirstTime'
                    'SearchHomepageBannerReturning'
                    'SearchHomepageLearningFeedback'
                    'SearchHomepageAnalyticsFirstTime'
                    'SearchHomepageAnalyticsReturning'
                ) -Force:$Force
                $result = Add-SearchSettingTypeName -InputObject $result -SectionName $Name
            }
            catch {
                $result = New-M365AdminUnavailableResultFromError -Name 'FirstRunExperience' -Area 'Search first-run experience' -ErrorMessage $_.Exception.Message -DefaultDescription 'The Search first-run experience payload could not be retrieved, even though the live portal uses a POST-backed request shape for this surface.'
            }

            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
        }

        if ($Name -eq 'Qnas') {
            $serviceToken = Get-CacheToken -Value $QnasServiceType
            $filterToken = Get-CacheToken -Value $QnasFilter
            try {
                $result = Get-SearchPortalData -Path '/admin/api/searchadminapi/Qnas' -CacheKey ("M365AdminSearchSetting:Qnas:{0}:{1}" -f $serviceToken, $filterToken) -Method Post -Body @{
                    ServiceType = $QnasServiceType
                    Filter = $QnasFilter
                } -Force:$Force
                $result = Add-SearchSettingTypeName -InputObject $result -SectionName $Name
            }
            catch {
                $result = New-M365AdminUnavailableResult -Name 'Qnas' -Description ("The live portal uses a POST-backed QnAs request, but this tenant did not return a usable payload for ServiceType '{0}' and Filter '{1}'." -f $QnasServiceType, $QnasFilter) -Reason 'TenantSpecific' -ErrorMessage $_.Exception.Message -SuggestedAction 'Retry with the live-portal default Bing/Published combination or compare alternate QnAs filters and service types against the browser request payloads in the admin center.'
            }

            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
        }

        if ($Name -eq 'News') {
            $result = [pscustomobject]@{
                NewsOptions    = Get-SearchPortalData -Path '/admin/api/searchadminapi/news/options/Bing' -CacheKey 'M365AdminSearchSetting:NewsOptions' -Force:$Force
                NewsIndustry   = Get-SearchPortalData -Path '/admin/api/searchadminapi/news/industry/Bing' -CacheKey 'M365AdminSearchSetting:NewsIndustry' -Force:$Force
                NewsMsbEnabled = Get-SearchPortalData -Path '/admin/api/searchadminapi/news/msbenabled/Bing' -CacheKey 'M365AdminSearchSetting:NewsMsbEnabled' -Force:$Force
            }

            $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.SearchSetting.News'
            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
        }

        $path = switch ($Name) {
            'ModernResultTypes' { '/admin/api/searchadminapi/modernResultTypes' }
            'NewsIndustry' { '/admin/api/searchadminapi/news/industry/Bing' }
            'NewsMsbEnabled' { '/admin/api/searchadminapi/news/msbenabled/Bing' }
            'NewsOptions' { '/admin/api/searchadminapi/news/options/Bing' }
            'Pivots' { '/admin/api/searchadminapi/Pivots' }
            'SearchIntelligenceHomeCards' { '/admin/api/searchadminapi/searchintelligencehome/cards' }
            'UdtConnectorsSummary' { '/admin/api/searchadminapi/UDTConnectorsSummary' }
        }

        $result = Get-SearchPortalData -Path $path -CacheKey "M365AdminSearchSetting:$Name" -Force:$Force
        $result = Add-SearchSettingTypeName -InputObject $result -SectionName $Name
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}