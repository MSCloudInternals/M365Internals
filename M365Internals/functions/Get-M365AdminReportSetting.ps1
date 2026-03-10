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
        [ValidateSet('TenantConfiguration', 'ProductivityScoreConfig', 'ProductivityScoreCustomerOption')]
        [string]$Name = 'TenantConfiguration',

        [Parameter()]
        [switch]$Force
    )

    process {
        $path = switch ($Name) {
            'TenantConfiguration' { '/admin/api/reports/config/GetTenantConfiguration' }
            'ProductivityScoreConfig' { '/admin/api/reports/productivityScoreConfig/GetProductivityScoreConfig' }
            'ProductivityScoreCustomerOption' { '/admin/api/reports/productivityScoreCustomerOption' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminReportSetting:$Name" -Force:$Force
    }
}