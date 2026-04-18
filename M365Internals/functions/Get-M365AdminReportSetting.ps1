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

    .PARAMETER Raw
        Returns the raw report settings payload for the selected section.

    .PARAMETER RawJson
        Returns the raw report settings payload serialized as formatted JSON.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        if ($Name -eq 'AdoptionScore') {
            $productivityScoreConfig = Get-M365AdminPortalData -Path '/admin/api/reports/productivityScoreConfig/GetProductivityScoreConfig' -CacheKey 'M365AdminReportSetting:ProductivityScoreConfig' -Force:$Force
            $productivityScoreCustomerOption = Get-M365AdminPortalData -Path '/admin/api/reports/productivityScoreCustomerOption' -CacheKey 'M365AdminReportSetting:ProductivityScoreCustomerOption' -Force:$Force

            $result = [pscustomobject]@{
                ProductivityScoreConfig         = $productivityScoreConfig
                ProductivityScoreCustomerOption = $productivityScoreCustomerOption
            }

            $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.ReportSetting.AdoptionScore'
            $rawResult = [pscustomobject]@{
                ProductivityScoreConfig         = $productivityScoreConfig
                ProductivityScoreCustomerOption = $productivityScoreCustomerOption
            }

            return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
        }

        $path = switch ($Name) {
            'TenantConfiguration' { '/admin/api/reports/config/GetTenantConfiguration' }
            'ProductivityScoreConfig' { '/admin/api/reports/productivityScoreConfig/GetProductivityScoreConfig' }
            'ProductivityScoreCustomerOption' { '/admin/api/reports/productivityScoreCustomerOption' }
            'Reports' { '/admin/api/reports/config/GetTenantConfiguration' }
        }

        $rawResult = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminReportSetting:$Name" -Force:$Force
        $result = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName ("M365Admin.ReportSetting.{0}" -f $Name) -Category 'Reports' -ItemName $Name -Endpoint $path
        return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
    }
}