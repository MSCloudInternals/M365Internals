function Get-M365AdminTenantSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center tenant settings.

    .DESCRIPTION
        Reads tenant-level configuration and status payloads from the admin center tenant endpoints.

    .PARAMETER Name
        The tenant settings payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw tenant settings payload for the selected section.

    .PARAMETER RawJson
        Returns the raw tenant settings payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminTenantSetting -Name AccountSkus

        Retrieves the tenant SKU inventory payload.

    .OUTPUTS
        Object
        Returns the selected tenant settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('AADLink', 'AccountSkus', 'DataLocationAndCommitments', 'EligibleToRemoveSac', 'LocalDataLocation', 'O365ActivationUserCounts', 'ReportsPrivacyEnabled')]
        [string]$Name,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $path = switch ($Name) {
            'AADLink' { '/admin/api/tenant/AADLink' }
            'AccountSkus' { '/admin/api/tenant/accountSkus' }
            'DataLocationAndCommitments' { '/admin/api/tenant/datalocationandcommitments' }
            'EligibleToRemoveSac' { '/admin/api/tenant/isTenantEligibleToRemoveSAC' }
            'LocalDataLocation' { '/admin/api/tenant/localdatalocation' }
            'O365ActivationUserCounts' { '/admin/api/tenant/o365activationusercounts' }
            'ReportsPrivacyEnabled' { '/admin/api/tenant/isReportsPrivacyEnabled' }
        }

        $result = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminTenantSetting:$Name" -Force:$Force
        $result = Add-M365TypeName -InputObject $result -TypeName ("M365Admin.TenantSetting.{0}" -f $Name)
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}