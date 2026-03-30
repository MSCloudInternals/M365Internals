function Get-M365AdminPartnerClient {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center partner client data.

    .DESCRIPTION
        Reads delegated partner client lists exposed by the AOBOClients admin endpoint.

    .PARAMETER PartnerType
        The delegated partner model to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw partner client payload.

    .PARAMETER RawJson
        Returns the raw partner client payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminPartnerClient -PartnerType GDAP

        Retrieves the GDAP delegated partner client list.

    .OUTPUTS
        Object
        Returns the selected partner client payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('DAP', 'GDAP')]
        [string]$PartnerType = 'DAP',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $path = '/admin/api/partners/AOBOClients?partnerType={0}' -f $PartnerType
        $result = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminPartnerClient:$PartnerType" -Force:$Force
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}