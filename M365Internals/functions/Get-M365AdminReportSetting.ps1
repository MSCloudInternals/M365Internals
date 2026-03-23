function Get-M365AdminReportSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center report settings.

    .DESCRIPTION
        Reads reporting configuration payloads exposed by the admin center report endpoints.

    .PARAMETER Name
        The report settings payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminReportSetting -Name TenantConfiguration

        Retrieves the tenant reporting configuration payload.

    .OUTPUTS
        Object
        Returns the selected report settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('AdoptionScore', 'ProductivityScoreConfig', 'ProductivityScoreCustomerOption', 'Reports', 'TenantConfiguration')]
        [string]$Name = 'TenantConfiguration',

        [Parameter()]
        [switch]$Force
    )

    process {
        if ($Name -eq 'AdoptionScore') {
            $productivityScoreConfig = Get-M365AdminPortalData -Path '/admin/api/reports/productivityScoreConfig/GetProductivityScoreConfig' -CacheKey 'M365AdminReportSetting:ProductivityScoreConfig' -Force:$Force
            $productivityScoreCustomerOption = Get-M365AdminPortalData -Path '/admin/api/reports/productivityScoreCustomerOption' -CacheKey 'M365AdminReportSetting:ProductivityScoreCustomerOption' -Force:$Force

            [pscustomobject]@{
                ProductivityScoreConfig         = $productivityScoreConfig
                ProductivityScoreCustomerOption = $productivityScoreCustomerOption
            }
            return
        }

        $path = switch ($Name) {
            'TenantConfiguration' { '/admin/api/reports/config/GetTenantConfiguration' }
            'ProductivityScoreConfig' { '/admin/api/reports/productivityScoreConfig/GetProductivityScoreConfig' }
            'ProductivityScoreCustomerOption' { '/admin/api/reports/productivityScoreCustomerOption' }
            'Reports' { '/admin/api/reports/config/GetTenantConfiguration' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminReportSetting:$Name" -Force:$Force
    }
}