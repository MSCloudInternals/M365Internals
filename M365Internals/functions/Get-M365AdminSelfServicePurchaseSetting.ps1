function Get-M365AdminSelfServicePurchaseSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center self-service purchase settings.

    .DESCRIPTION
        Reads the product self-service purchase policy payload used by the Self-service trials
        and purchases Org settings page.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw self-service purchase payload.

    .PARAMETER RawJson
        Returns the raw self-service purchase payload serialized as formatted JSON.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $result = Get-M365AdminPortalData -Path '/admin/api/selfServicePurchasePolicy/products' -CacheKey 'M365AdminSelfServicePurchaseSetting:Products' -Force:$Force
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}