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
        [switch]$Force
    )

    process {
        if ($Name -eq 'All') {
            $result = [pscustomobject]@{
                DAP  = Get-M365AdminPartnerClient -PartnerType DAP -Force:$Force
                GDAP = Get-M365AdminPartnerClient -PartnerType GDAP -Force:$Force
            }

            return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.PartnerRelationship'
        }

        Get-M365AdminPartnerClient -PartnerType $Name -Force:$Force
    }
}