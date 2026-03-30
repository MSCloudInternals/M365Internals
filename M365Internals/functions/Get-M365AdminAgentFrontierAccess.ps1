function Get-M365AdminAgentFrontierAccess {
    <#
    .SYNOPSIS
        Retrieves the Agents Frontier access policy.

    .DESCRIPTION
        Reads the Agents Frontier access configuration exposed by the Microsoft 365 admin
        center and returns the current tenant policy payload.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw Frontier access policy payload.

    .PARAMETER RawJson
        Returns the raw Frontier access policy payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminAgentFrontierAccess

        Retrieves the current Agents Frontier access policy.

    .OUTPUTS
        Object
        Returns the current Frontier access policy payload.
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
        $result = Get-M365AdminPortalData -Path '/admin/api/settings/company/frontier/access' -CacheKey 'M365AdminAgentFrontierAccess:Current' -Force:$Force
        $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.AgentFrontierAccess'
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}