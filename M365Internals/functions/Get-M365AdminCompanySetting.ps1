function Get-M365AdminCompanySetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center company settings.

    .DESCRIPTION
        Reads company settings payloads exposed under the admin center company settings surface.

    .PARAMETER Name
        The company settings payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminCompanySetting -Name Profile

        Retrieves the company profile settings payload.

    .OUTPUTS
        Object
        Returns the selected company settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('CustomThemes', 'CustomTilesForApps', 'DataLocation', 'HelpDesk', 'HelpDeskInformation', 'KeyboardShortcuts', 'OrganizationInformation', 'Profile', 'ReleasePreferences', 'ReleaseTrack', 'SendEmailNotificationsFromYourDomain', 'SendFromAddress', 'SupportIntegration', 'Theme', 'Tile')]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    process {
        if ($Name -eq 'DataLocation') {
            $dataLocationAndCommitments = Get-M365AdminPortalData -Path '/admin/api/tenant/datalocationandcommitments' -CacheKey 'M365AdminCompanySetting:DataLocationAndCommitments' -Force:$Force
            $localDataLocation = Get-M365AdminPortalData -Path '/admin/api/tenant/localdatalocation' -CacheKey 'M365AdminCompanySetting:LocalDataLocation' -Force:$Force

            [pscustomobject]@{
                DataLocationAndCommitments = $dataLocationAndCommitments
                LocalDataLocation          = $localDataLocation
            }
            return
        }

        if ($Name -eq 'KeyboardShortcuts') {
            return [pscustomobject]@{
                Name        = 'Keyboard shortcuts'
                Route       = 'KeyboardShortcuts'
                DataBacked  = $false
                Description = 'The Org settings Keyboard shortcuts item appears to be a static help surface rather than a dedicated settings API.'
                Shortcut    = 'Shift+?'
            }
        }

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
            'SupportIntegration' { '/admin/api/supportRepository/my' }
            'Theme' { '/admin/api/Settings/company/theme/v2' }
            'Tile' { '/admin/api/Settings/company/tile' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminCompanySetting:$Name" -Force:$Force
    }
}