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
                return Get-M365AdminPortalData -Path '/admin/api/searchadminapi/configurations' -CacheKey 'M365AdminSearchSetting:Configurations' -Headers (Get-M365PortalContextHeaders -Context MicrosoftSearch) -Force:$Force
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

        if ($Name -in @('FirstRunExperience', 'Qnas')) {
            $path = if ($Name -eq 'FirstRunExperience') { '/admin/api/searchadminapi/firstrunexperience/get' } else { '/admin/api/searchadminapi/Qnas' }

            try {
                return Get-M365AdminPortalData -Path $path -CacheKey "M365AdminSearchSetting:$Name" -Headers (Get-M365PortalContextHeaders -Context MicrosoftSearch) -Force:$Force
            }
            catch {
                return [pscustomobject]@{
                    Name        = $Name
                    DataBacked  = $false
                    Error       = $_.Exception.Message
                    Description = 'This Search setting currently returns the same tenant-specific 400 response seen in the live portal.'
                }
            }
        }

        if ($Name -eq 'News') {
            [pscustomobject]@{
                NewsOptions    = Get-M365AdminPortalData -Path '/admin/api/searchadminapi/news/options/Bing' -CacheKey 'M365AdminSearchSetting:NewsOptions' -Headers (Get-M365PortalContextHeaders -Context MicrosoftSearch) -Force:$Force
                NewsIndustry   = Get-M365AdminPortalData -Path '/admin/api/searchadminapi/news/industry/Bing' -CacheKey 'M365AdminSearchSetting:NewsIndustry' -Headers (Get-M365PortalContextHeaders -Context MicrosoftSearch) -Force:$Force
                NewsMsbEnabled = Get-M365AdminPortalData -Path '/admin/api/searchadminapi/news/msbenabled/Bing' -CacheKey 'M365AdminSearchSetting:NewsMsbEnabled' -Headers (Get-M365PortalContextHeaders -Context MicrosoftSearch) -Force:$Force
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

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminSearchSetting:$Name" -Headers (Get-M365PortalContextHeaders -Context MicrosoftSearch) -Force:$Force
    }
}