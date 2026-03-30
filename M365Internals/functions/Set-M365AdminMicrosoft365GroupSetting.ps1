function Set-M365AdminMicrosoft365GroupSetting {
    <#
    .SYNOPSIS
        Updates Microsoft 365 Groups settings from the Org settings experience.

    .DESCRIPTION
        Retrieves the current Microsoft 365 Groups settings payload, merges the provided setting
        values into that payload, and submits the updated result back to the Microsoft 365 admin center.

    .PARAMETER Name
        The Microsoft 365 Groups settings payload to update.

    .PARAMETER Settings
        The setting values to merge into the current payload before submitting the update.

    .PARAMETER Force
        Bypasses the cache when retrieving the current payload before the update.

    .PARAMETER PassThru
        Retrieves and returns the updated payload after the write succeeds.

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs without submitting the update.

    .PARAMETER Confirm
        Prompts for confirmation before submitting the update.

    .EXAMPLE
        Set-M365AdminMicrosoft365GroupSetting -Name GuestUserPolicy -Settings @{ AllowGuestInvitations = $false } -Confirm:$false

        Updates the Microsoft 365 Groups guest user policy payload.

    .OUTPUTS
        Object
        Returns the admin-center write response, or the refreshed payload when `-PassThru` is used.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('GuestAccess', 'GuestUserPolicy')]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Settings,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        $path = if ($Name -eq 'GuestAccess') {
            '/admin/api/settings/security/o365guestuser'
        }
        else {
            '/admin/api/Settings/security/guestUserPolicy'
        }

        $currentSettings = Get-M365AdminMicrosoft365GroupSetting -Name $Name -Force:$Force -Raw
        $body = Merge-M365AdminSettingsPayload -CurrentSettings $currentSettings -Settings $Settings

        if ($PSCmdlet.ShouldProcess("Microsoft 365 Groups setting '$Name'", "POST $path")) {
            $result = Invoke-M365AdminRestMethod -Path $path -Method Post -Body $body
            Clear-M365Cache -TenantId (Get-M365PortalTenantId)

            if ($PassThru) {
                return Get-M365AdminMicrosoft365GroupSetting -Name $Name -Force
            }

            return $result
        }
    }
}