function Get-M365AdminSelfServicePurchaseSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center self-service purchase settings.

    .DESCRIPTION
        Reads the product self-service purchase policy payload used by the Self-service trials
        and purchases Org settings page.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminSelfServicePurchaseSetting

        Retrieves the self-service purchase product policy payload.

    .OUTPUTS
        Object
        Returns the self-service purchase product policy payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$Force
    )

    process {
        Get-M365AdminPortalData -Path '/admin/api/selfServicePurchasePolicy/products' -CacheKey 'M365AdminSelfServicePurchaseSetting:Products' -Force:$Force
    }
}