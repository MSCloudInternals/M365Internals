function Get-M365AdminCopilotPinPolicy {
    <#
    .SYNOPSIS
        Retrieves the Copilot pin policy.

    .DESCRIPTION
        Reads the Copilot pin policy exposed by the Microsoft 365 admin center and returns the
        current tenant policy payload.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw Copilot pin policy payload.

    .PARAMETER RawJson
        Returns the raw Copilot pin policy payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminCopilotPinPolicy

        Retrieves the current Copilot pin policy.

    .OUTPUTS
        Object
        Returns the current Copilot pin policy payload.
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
        $result = Get-M365AdminPortalData -Path '/admin/api/settings/company/copilotpolicy/pin' -CacheKey 'M365AdminCopilotPinPolicy:Current' -Force:$Force
        $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotPinPolicy'
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}