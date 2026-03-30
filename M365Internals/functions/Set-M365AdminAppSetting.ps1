function Set-M365AdminAppSetting {
    <#
    .SYNOPSIS
        Updates Microsoft 365 admin center app settings.

    .DESCRIPTION
        Retrieves the current app settings payload, merges the provided setting values into that
        payload, and posts the updated result back to the Microsoft 365 admin center.

    .PARAMETER Name
        The app settings payload to update.

    .PARAMETER Settings
        The setting values to merge into the current payload before posting the update.

    .PARAMETER Force
        Bypasses the cache when retrieving the current payload before the update.

    .PARAMETER PassThru
        Retrieves and returns the updated payload after the write succeeds.

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs without submitting the update.

    .PARAMETER Confirm
        Prompts for confirmation before submitting the update.

    .EXAMPLE
        Set-M365AdminAppSetting -Name OfficeScripts -Settings @{ EnabledOption = 1 } -Confirm:$false

        Updates the Office Scripts app settings payload.

    .OUTPUTS
        Object
        Returns the admin-center write response, or the refreshed payload when `-PassThru` is used.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Bookings', 'Calendar', 'CalendarSharing', 'DirectorySynchronization', 'Dynamics365ConnectionGraph', 'Dynamics365CustomerVoice', 'Dynamics365SalesInsights', 'DynamicsCrm', 'EndUserCommunications', 'Learning', 'LoopPolicy', 'Mail', 'Microsoft365OnTheWeb', 'MicrosoftCommunicationToUsers', 'MicrosoftForms', 'MicrosoftGraphDataConnect', 'MicrosoftLoop', 'MicrosoftTeams', 'O365DataPlan', 'OfficeForms', 'OfficeFormsPro', 'OfficeOnline', 'OfficeScripts', 'Project', 'SharePoint', 'SitesSharing', 'SkypeTeams', 'Store', 'Sway', 'UserOwnedAppsAndServices', 'UserSoftware', 'VivaLearning', 'Whiteboard')]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Settings,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        $path = Get-M365AdminAppSettingPath -Name $Name
        $currentSettings = Get-M365AdminAppSetting -Name $Name -Force:$Force -Raw
        $body = Merge-M365AdminSettingsPayload -CurrentSettings $currentSettings -Settings $Settings

        if ($PSCmdlet.ShouldProcess("App setting '$Name'", "POST $path")) {
            $result = Invoke-M365AdminRestMethod -Path $path -Method Post -Body $body
            Clear-M365Cache -TenantId (Get-M365PortalTenantId)

            if ($PassThru) {
                return Get-M365AdminAppSetting -Name $Name -Force
            }

            return $result
        }
    }
}
