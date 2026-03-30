function Set-M365AdminCompanySetting {
    <#
    .SYNOPSIS
        Updates Microsoft 365 admin center company settings.

    .DESCRIPTION
        Retrieves the current company settings payload, merges the provided setting values into
        that payload, preserves the untouched properties, and submits the updated result back
        to the Microsoft 365 admin center.

    .PARAMETER Name
        The company settings payload to update.

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
        Set-M365AdminCompanySetting -Name HelpDesk -Settings @{ CustomSupportEnabled = $true } -Confirm:$false

        Updates the Help Desk company settings payload.

    .EXAMPLE
        Set-M365AdminCompanySetting -Name Profile -Settings @{ Name = 'Contoso' } -PassThru -Confirm:$false

        Updates only the supplied Profile keys and returns the refreshed payload.

    .OUTPUTS
        Object
        Returns the admin-center write response, or the refreshed payload when `-PassThru` is used.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('CustomThemes', 'CustomTilesForApps', 'HelpDesk', 'HelpDeskInformation', 'OrganizationInformation', 'Profile', 'ReleasePreferences', 'ReleaseTrack', 'SendEmailNotificationsFromYourDomain', 'SendFromAddress', 'Theme', 'Tile')]
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
        $path = switch ($Name) {
            'CustomThemes' { '/admin/api/Settings/company/theme/v2' }
            'CustomTilesForApps' { '/admin/api/Settings/company/tile' }
            'HelpDesk' { '/admin/api/Settings/company/helpdesk' }
            'HelpDeskInformation' { '/admin/api/Settings/company/helpdesk' }
            'OrganizationInformation' { '/admin/api/Settings/company/profile' }
            'Profile' { '/admin/api/Settings/company/profile' }
            'ReleasePreferences' { '/admin/api/Settings/company/releasetrack' }
            'ReleaseTrack' { '/admin/api/Settings/company/releasetrack' }
            'SendEmailNotificationsFromYourDomain' { '/admin/api/Settings/company/sendfromaddress' }
            'SendFromAddress' { '/admin/api/Settings/company/sendfromaddress' }
            'Theme' { '/admin/api/Settings/company/theme/v2' }
            'Tile' { '/admin/api/Settings/company/tile' }
        }

        $method = if ($Name -in @('CustomThemes', 'Theme')) { 'Put' } else { 'Post' }
        $currentSettings = Get-M365AdminCompanySetting -Name $Name -Force:$Force -Raw
        $body = Merge-M365AdminSettingsPayload -CurrentSettings $currentSettings -Settings $Settings
        $mergedKeys = @($Settings.Keys | Sort-Object) -join ', '

        if ($PSCmdlet.ShouldProcess("Company setting '$Name'", "$method $path (merge keys: $mergedKeys)")) {
            $result = Invoke-M365AdminRestMethod -Path $path -Method $method -Body $body
            Clear-M365Cache -TenantId (Get-M365PortalTenantId)

            if ($PassThru) {
                return Get-M365AdminCompanySetting -Name $Name -Force
            }

            return $result
        }
    }
}