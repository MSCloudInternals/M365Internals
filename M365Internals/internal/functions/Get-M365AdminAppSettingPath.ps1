function Get-M365AdminAppSettingPath {
    <#
    .SYNOPSIS
        Resolves the admin-center path for an app setting name.

    .DESCRIPTION
        Maps the public `Get-M365AdminAppSetting` and `Set-M365AdminAppSetting` names to the
        corresponding Microsoft 365 admin center endpoint paths.

    .PARAMETER Name
        The app setting name to resolve.

    .EXAMPLE
        Get-M365AdminAppSettingPath -Name Bookings

        Returns the Bookings app settings endpoint path.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Bookings', 'Calendar', 'CalendarSharing', 'DirectorySynchronization', 'Dynamics365ConnectionGraph', 'Dynamics365CustomerVoice', 'Dynamics365SalesInsights', 'DynamicsCrm', 'EndUserCommunications', 'Learning', 'LoopPolicy', 'Mail', 'Microsoft365OnTheWeb', 'MicrosoftCommunicationToUsers', 'MicrosoftForms', 'MicrosoftGraphDataConnect', 'MicrosoftLoop', 'MicrosoftTeams', 'O365DataPlan', 'OfficeForms', 'OfficeFormsPro', 'OfficeOnline', 'OfficeScripts', 'Project', 'SharePoint', 'SitesSharing', 'SkypeTeams', 'Store', 'Sway', 'UserOwnedAppsAndServices', 'UserSoftware', 'VivaLearning', 'Whiteboard')]
        [string]$Name
    )

    process {
        switch ($Name) {
            'Bookings' { '/admin/api/settings/apps/bookings' }
            'Calendar' { '/admin/api/settings/apps/calendarsharing' }
            'CalendarSharing' { '/admin/api/settings/apps/calendarsharing' }
            'DirectorySynchronization' { '/admin/api/settings/apps/dirsync' }
            'Dynamics365ConnectionGraph' { '/admin/api/settings/apps/dcg' }
            'Dynamics365CustomerVoice' { '/admin/api/settings/apps/officeformspro' }
            'Dynamics365SalesInsights' { '/admin/api/settings/apps/dci' }
            'DynamicsCrm' { '/admin/api/settings/apps/dynamicscrm' }
            'EndUserCommunications' { '/admin/api/settings/apps/EndUserCommunications' }
            'MicrosoftCommunicationToUsers' { '/admin/api/settings/apps/EndUserCommunications' }
            'Learning' { '/admin/api/settings/apps/learning' }
            'LoopPolicy' { '/admin/api/settings/apps/looppolicy' }
            'MicrosoftLoop' { '/admin/api/settings/apps/looppolicy' }
            'Mail' { '/admin/api/settings/apps/mail' }
            'Microsoft365OnTheWeb' { '/admin/api/settings/apps/officeonline' }
            'MicrosoftForms' { '/admin/api/settings/apps/officeforms' }
            'MicrosoftGraphDataConnect' { '/admin/api/settings/apps/o365dataplan' }
            'O365DataPlan' { '/admin/api/settings/apps/o365dataplan' }
            'OfficeForms' { '/admin/api/settings/apps/officeforms' }
            'OfficeFormsPro' { '/admin/api/settings/apps/officeformspro' }
            'OfficeOnline' { '/admin/api/settings/apps/officeonline' }
            'OfficeScripts' { '/admin/api/settings/apps/officescripts' }
            'Project' { '/admin/api/settings/apps/projectonline' }
            'SharePoint' { '/admin/api/settings/apps/sitessharing' }
            'SitesSharing' { '/admin/api/settings/apps/sitessharing' }
            'MicrosoftTeams' { '/admin/api/settings/apps/skypeteams' }
            'SkypeTeams' { '/admin/api/settings/apps/skypeteams' }
            'UserOwnedAppsAndServices' { '/admin/api/settings/apps/store' }
            'Store' { '/admin/api/settings/apps/store' }
            'Sway' { '/admin/api/settings/apps/Sway' }
            'UserSoftware' { '/admin/api/settings/apps/usersoftware' }
            'VivaLearning' { '/admin/api/settings/apps/learning' }
            'Whiteboard' { '/admin/api/settings/apps/whiteboard' }
        }
    }
}
