function Set-M365AdminAgentFrontierAccess {
    <#
    .SYNOPSIS
        Updates the Agents Frontier access policy.

    .DESCRIPTION
        Retrieves the current Frontier access payload, merges the provided values into that
        payload, and posts the updated result back to the Microsoft 365 admin center.

    .PARAMETER Settings
        The Frontier access values to merge into the current payload before posting the update.

    .PARAMETER Force
        Bypasses the cache when retrieving the current policy before the update.

    .PARAMETER PassThru
        Retrieves and returns the updated policy after the write succeeds.

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs without submitting the update.

    .PARAMETER Confirm
        Prompts for confirmation before submitting the update.

    .EXAMPLE
        Set-M365AdminAgentFrontierAccess -Settings @{ FrontierPolicy = 0 } -Confirm:$false

        Updates the Agents Frontier access policy.

    .OUTPUTS
        Object
        Returns the admin-center write response, or the refreshed policy when `-PassThru` is used.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Settings,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        $path = '/admin/api/settings/company/frontier/access'
        $currentSettings = Get-M365AdminAgentFrontierAccess -Force:$Force
        $body = Merge-M365AdminSettingsPayload -CurrentSettings $currentSettings -Settings $Settings

        if ($PSCmdlet.ShouldProcess('Agent Frontier access policy', "POST $path")) {
            $result = Invoke-M365AdminRestMethod -Path $path -Method Post -Body $body
            Clear-M365Cache -TenantId (Get-M365PortalTenantId)

            if ($PassThru) {
                return Get-M365AdminAgentFrontierAccess -Force
            }

            return $result
        }
    }
}