function Get-M365AdminSearchSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center search settings.

    .DESCRIPTION
        Reads search administration payloads exposed by the searchadminapi endpoints.

    .PARAMETER Name
        The search settings payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

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
        [switch]$Force
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

        if ($Name -eq 'AccountLinking') {
            return [pscustomobject]@{
                Name        = 'Account Linking'
                Route       = 'EnterpriseMicrosoftRewards'
                DataBacked  = $false
                Description = 'The Org settings Account Linking flyout issued an internal browser request during live capture, but a stable same-origin GET could not be reproduced outside the portal interaction flow.'
            }
        }

        if ($Name -eq 'Configurations') {
            try {
                return Get-SearchPortalData -Path '/admin/api/searchadminapi/configurations' -CacheKey 'M365AdminSearchSetting:Configurations' -Force:$Force
            }
            catch {
                return [pscustomobject]@{
                    Name        = 'Configurations'
                    DataBacked  = $false
                    Error       = $_.Exception.Message
                    Description = 'The Search configurations endpoint is currently unavailable in this tenant and returns the same 503 response seen in the live portal.'
                }
            }
        }

        if ($Name -eq 'FirstRunExperience') {
            try {
                return Get-SearchPortalData -Path '/admin/api/searchadminapi/firstrunexperience/get' -CacheKey 'M365AdminSearchSetting:FirstRunExperience' -Method Post -Body @(
                    'SearchHomepageBannerFirstTime'
                    'SearchHomepageBannerReturning'
                    'SearchHomepageLearningFeedback'
                    'SearchHomepageAnalyticsFirstTime'
                    'SearchHomepageAnalyticsReturning'
                ) -Force:$Force
            }
            catch {
                return [pscustomobject]@{
                    Name        = 'FirstRunExperience'
                    DataBacked  = $false
                    Error       = $_.Exception.Message
                    Description = 'The Search first-run experience payload could not be retrieved, even though the live portal uses a POST-backed request shape for this surface.'
                }
            }
        }

        if ($Name -eq 'Qnas') {
            try {
                return Get-SearchPortalData -Path '/admin/api/searchadminapi/Qnas' -CacheKey 'M365AdminSearchSetting:Qnas' -Method Post -Body @{
                    ServiceType = 'Bing'
                    Filter = 'Published'
                } -Force:$Force
            }
            catch {
                return [pscustomobject]@{
                    Name        = 'Qnas'
                    DataBacked  = $false
                    Error       = $_.Exception.Message
                    Description = 'The live portal uses a POST-backed QnAs request, but this tenant currently returns 404 for the published Bing payload.'
                }
            }
        }

        if ($Name -eq 'News') {
            [pscustomobject]@{
                NewsOptions    = Get-SearchPortalData -Path '/admin/api/searchadminapi/news/options/Bing' -CacheKey 'M365AdminSearchSetting:NewsOptions' -Force:$Force
                NewsIndustry   = Get-SearchPortalData -Path '/admin/api/searchadminapi/news/industry/Bing' -CacheKey 'M365AdminSearchSetting:NewsIndustry' -Force:$Force
                NewsMsbEnabled = Get-SearchPortalData -Path '/admin/api/searchadminapi/news/msbenabled/Bing' -CacheKey 'M365AdminSearchSetting:NewsMsbEnabled' -Force:$Force
            }
            return
        }

        $path = switch ($Name) {
            'ConfigurationSettings' { '/admin/api/searchadminapi/ConfigurationSettings' }
            'ModernResultTypes' { '/admin/api/searchadminapi/modernResultTypes' }
            'NewsIndustry' { '/admin/api/searchadminapi/news/industry/Bing' }
            'NewsMsbEnabled' { '/admin/api/searchadminapi/news/msbenabled/Bing' }
            'NewsOptions' { '/admin/api/searchadminapi/news/options/Bing' }
            'Pivots' { '/admin/api/searchadminapi/Pivots' }
            'SearchIntelligenceHomeCards' { '/admin/api/searchadminapi/searchintelligencehome/cards' }
            'UdtConnectorsSummary' { '/admin/api/searchadminapi/UDTConnectorsSummary' }
        }

        Get-SearchPortalData -Path $path -CacheKey "M365AdminSearchSetting:$Name" -Force:$Force
    }
}