function Set-M365AdminUserOwnedAppSetting {
    <#
    .SYNOPSIS
        Updates Microsoft 365 admin center user-owned apps and services settings.

    .DESCRIPTION
        Updates the user-owned apps and services experience by toggling Office Store access,
        in-app purchases and trials, and the auto-claim licensing policy.

    .PARAMETER LetUsersAccessOfficeStore
        Controls whether users can access the Office Store.

    .PARAMETER LetUsersStartTrials
        Controls whether users can start in-app purchases and trials.

    .PARAMETER LetUsersAutoClaimLicenses
        Controls whether users can auto-claim licenses.

    .PARAMETER PassThru
        Retrieves and returns the grouped user-owned apps payload after the writes succeed.

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs without submitting the updates.

    .PARAMETER Confirm
        Prompts for confirmation before submitting the updates.

    .EXAMPLE
        Set-M365AdminUserOwnedAppSetting -LetUsersAccessOfficeStore $true -LetUsersStartTrials $false -Confirm:$false

        Updates the Office Store and trial settings for user-owned apps.

    .OUTPUTS
        Object
        Returns the grouped user-owned apps payload when `-PassThru` is used.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [nullable[bool]]$LetUsersAccessOfficeStore,

        [Parameter()]
        [nullable[bool]]$LetUsersStartTrials,

        [Parameter()]
        [nullable[bool]]$LetUsersAutoClaimLicenses,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        $didUpdate = $false

        if (($null -eq $LetUsersAccessOfficeStore) -and ($null -eq $LetUsersStartTrials) -and ($null -eq $LetUsersAutoClaimLicenses)) {
            throw 'At least one user-owned apps setting value must be provided.'
        }

        if ($null -ne $LetUsersAccessOfficeStore) {
            $storePath = Get-M365AdminUserOwnedAppSettingPath -Name StoreAccess
            if ($PSCmdlet.ShouldProcess('User-owned apps Office Store access', "POST $storePath")) {
                $null = Invoke-M365AdminRestMethod -Path $storePath -Method Post -Body @{
                    Enabled = $LetUsersAccessOfficeStore
                }
                $didUpdate = $true
            }
        }

        if ($null -ne $LetUsersStartTrials) {
            $trialState = $LetUsersStartTrials.ToString().ToLowerInvariant()
            $trialPath = "/admin/api/storesettings/iwpurchase/{0}" -f $trialState
            if ($PSCmdlet.ShouldProcess('User-owned apps in-app purchases and trials', "PUT $trialPath")) {
                $null = Invoke-M365AdminRestMethod -Path $trialPath -Method Put
                $didUpdate = $true
            }
        }

        if ($null -ne $LetUsersAutoClaimLicenses) {
            $autoClaimPath = Get-M365AdminUserOwnedAppSettingPath -Name AutoClaimPolicy
            if ($PSCmdlet.ShouldProcess('User-owned apps auto-claim licensing policy', "POST $autoClaimPath")) {
                $null = Invoke-M365AdminRestMethod -Path $autoClaimPath -Method Post -Body @{
                    policyValue = if ($LetUsersAutoClaimLicenses) { 'Enabled' } else { 'Disabled' }
                }
                $didUpdate = $true
            }
        }

        if (-not $didUpdate) {
            return
        }

        Clear-M365Cache -TenantId (Get-M365PortalTenantId)

        if ($PassThru) {
            return Get-M365AdminUserOwnedAppSetting -Force
        }
    }
}
