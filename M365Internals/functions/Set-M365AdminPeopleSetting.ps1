function Set-M365AdminPeopleSetting {
    <#
    .SYNOPSIS
        Updates Microsoft 365 admin center People settings.

    .DESCRIPTION
        Retrieves the current People settings payload, merges the provided setting values into
        that payload, preserves the untouched properties, and submits the updated result back
        to the Microsoft 365 admin center.

    .PARAMETER Name
        The People settings payload to update.

    .PARAMETER Settings
        The setting values to merge into the current payload before submitting the update.
        Only the supplied keys are overwritten; the remaining payload is preserved.

    .PARAMETER Force
        Bypasses the cache when retrieving the current payload before the update.

    .PARAMETER PassThru
        Retrieves and returns the updated payload after the write succeeds.

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs without submitting the update.

    .PARAMETER Confirm
        Prompts for confirmation before submitting the update.

    .EXAMPLE
        Set-M365AdminPeopleSetting -Name Pronouns -Settings @{ isEnabledInOrganization = $true } -Confirm:$false

        Updates the People Pronouns settings payload.

    .EXAMPLE
        Set-M365AdminPeopleSetting -Name Pronouns -Settings @{ isEnabledInOrganization = $true } -PassThru -Confirm:$false

        Updates only the supplied People keys and returns the refreshed payload.

    .OUTPUTS
        Object
        Returns the admin-center write response, or the refreshed payload when `-PassThru` is used.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('NamePronunciation', 'Pronouns')]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$Settings,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        $tenantId = Get-M365PortalTenantId
        $path = if ($Name -eq 'NamePronunciation') {
            "/fd/peopleadminservice/{0}/settings/namePronunciation" -f $tenantId
        }
        else {
            "/fd/peopleadminservice/{0}/settings/pronouns" -f $tenantId
        }

        $currentSettings = Get-M365AdminPeopleSetting -Name $Name -Force:$Force -Raw
        $body = Merge-M365AdminSettingsPayload -CurrentSettings $currentSettings -Settings $Settings
        $mergedKeys = @($Settings.Keys | Sort-Object) -join ', '

        if ($PSCmdlet.ShouldProcess("People setting '$Name'", "PATCH $path (merge keys: $mergedKeys)")) {
            $result = Invoke-M365AdminRestMethod -Path $path -Method Patch -Body $body
            Clear-M365Cache -TenantId (Get-M365PortalTenantId)

            if ($PassThru) {
                return Get-M365AdminPeopleSetting -Name $Name -Force
            }

            return $result
        }
    }
}