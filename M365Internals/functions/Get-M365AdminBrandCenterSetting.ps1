function Get-M365AdminBrandCenterSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Brand center data.

    .DESCRIPTION
        Reads the Brand center configuration payloads used by the Org settings Brand center
        experience.

    .PARAMETER Name
        The Brand center payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminBrandCenterSetting

        Retrieves the Brand center configuration and site URL information.

    .OUTPUTS
        Object
        Returns the selected Brand center payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'Configuration', 'SiteUrl')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        switch ($Name) {
            'All' {
                $configuration = Get-M365AdminPortalData -Path '/_api/spo.tenant/GetBrandCenterConfiguration' -CacheKey 'M365AdminBrandCenterSetting:Configuration' -Force:$Force
                $siteUrl = Get-M365AdminPortalData -Path "/_api/GroupSiteManager/GetValidSiteUrlFromAlias?alias='BrandGuide'&managedPath='sites'" -CacheKey 'M365AdminBrandCenterSetting:SiteUrl' -Force:$Force

                $result = [pscustomobject]@{
                    Configuration = $configuration
                    SiteUrl        = $siteUrl
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.BrandCenterSetting'
            }
            'Configuration' {
                $path = '/_api/spo.tenant/GetBrandCenterConfiguration'
            }
            'SiteUrl' {
                $path = "/_api/GroupSiteManager/GetValidSiteUrlFromAlias?alias='BrandGuide'&managedPath='sites'"
            }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminBrandCenterSetting:$Name" -Force:$Force
    }
}