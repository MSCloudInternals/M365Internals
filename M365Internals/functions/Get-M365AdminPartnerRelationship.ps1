function Get-M365AdminPartnerRelationship {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center partner relationship data.

    .DESCRIPTION
        Reads the Settings > Partner relationships delegated partner payloads.

    .PARAMETER Name
        The partner relationship payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw partner relationship payload for the selected view.

    .PARAMETER RawJson
        Returns the raw partner relationship payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminPartnerRelationship

        Retrieves both DAP and GDAP partner relationship payloads.

    .OUTPUTS
        Object
        Returns the selected partner relationship payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'DAP', 'GDAP')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        if ($Name -eq 'All') {
            $result = [pscustomobject]@{
                DAP  = Get-M365AdminPartnerClient -PartnerType DAP -Force:$Force
                GDAP = Get-M365AdminPartnerClient -PartnerType GDAP -Force:$Force
            }

            $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.PartnerRelationship'
            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
        }

        $result = Get-M365AdminPartnerClient -PartnerType $Name -Force:$Force -Raw:$Raw -RawJson:$RawJson
        return $result
    }
}