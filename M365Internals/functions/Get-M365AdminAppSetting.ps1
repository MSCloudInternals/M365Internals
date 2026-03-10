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
        [ValidateSet('Bookings', 'CalendarSharing', 'DirectorySynchronization', 'DynamicsCrm', 'EndUserCommunications', 'Learning', 'LoopPolicy', 'Mail', 'O365DataPlan', 'OfficeForms', 'OfficeFormsPro', 'OfficeOnline', 'SitesSharing', 'SkypeTeams', 'Store', 'Sway', 'UserSoftware', 'Whiteboard')]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    process {
        $path = switch ($Name) {
            'Bookings' { '/admin/api/settings/apps/bookings' }
            'CalendarSharing' { '/admin/api/settings/apps/calendarsharing' }
            'DirectorySynchronization' { '/admin/api/settings/apps/dirsync' }
            'DynamicsCrm' { '/admin/api/settings/apps/dynamicscrm' }
            'EndUserCommunications' { '/admin/api/settings/apps/EndUserCommunications' }
            'Learning' { '/admin/api/settings/apps/learning' }
            'LoopPolicy' { '/admin/api/settings/apps/looppolicy' }
            'Mail' { '/admin/api/settings/apps/mail' }
            'O365DataPlan' { '/admin/api/settings/apps/o365dataplan' }
            'OfficeForms' { '/admin/api/settings/apps/officeforms' }
            'OfficeFormsPro' { '/admin/api/settings/apps/officeformspro' }
            'OfficeOnline' { '/admin/api/settings/apps/officeonline' }
            'SitesSharing' { '/admin/api/settings/apps/sitessharing' }
            'SkypeTeams' { '/admin/api/settings/apps/skypeteams' }
            'Store' { '/admin/api/settings/apps/store' }
            'Sway' { '/admin/api/settings/apps/Sway' }
            'UserSoftware' { '/admin/api/settings/apps/usersoftware' }
            'Whiteboard' { '/admin/api/settings/apps/whiteboard' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminAppSetting:$Name" -Force:$Force
    }
}