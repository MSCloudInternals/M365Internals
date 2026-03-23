function Get-M365AdminAppSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center app settings.

    .DESCRIPTION
        Reads settings payloads under the admin center apps settings surface discovered in the
        settings HAR capture.

    .PARAMETER Name
        The app settings payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminAppSetting -Name Bookings

        Retrieves the Bookings admin settings payload.

    .OUTPUTS
        Object
        Returns the selected app settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Bookings', 'Calendar', 'CalendarSharing', 'DirectorySynchronization', 'Dynamics365CustomerVoice', 'DynamicsCrm', 'EndUserCommunications', 'Learning', 'LoopPolicy', 'Mail', 'Microsoft365OnTheWeb', 'MicrosoftCommunicationToUsers', 'MicrosoftForms', 'MicrosoftGraphDataConnect', 'MicrosoftLoop', 'MicrosoftTeams', 'O365DataPlan', 'OfficeForms', 'OfficeFormsPro', 'OfficeOnline', 'SharePoint', 'SitesSharing', 'SkypeTeams', 'Store', 'Sway', 'UserOwnedAppsAndServices', 'UserSoftware', 'VivaLearning', 'Whiteboard')]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    process {
        $path = switch ($Name) {
            'Bookings' { '/admin/api/settings/apps/bookings' }
            'Calendar' { '/admin/api/settings/apps/calendarsharing' }
            'CalendarSharing' { '/admin/api/settings/apps/calendarsharing' }
            'DirectorySynchronization' { '/admin/api/settings/apps/dirsync' }
            'Dynamics365CustomerVoice' { '/admin/api/settings/apps/officeformspro' }
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

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminAppSetting:$Name" -Force:$Force
    }
}