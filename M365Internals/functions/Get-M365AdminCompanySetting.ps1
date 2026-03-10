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
        [ValidateSet('HelpDesk', 'Profile', 'ReleaseTrack', 'SendFromAddress', 'Theme', 'Tile')]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    process {
        $path = switch ($Name) {
            'HelpDesk' { '/admin/api/Settings/company/helpdesk' }
            'Profile' { '/admin/api/Settings/company/profile' }
            'ReleaseTrack' { '/admin/api/Settings/company/releasetrack' }
            'SendFromAddress' { '/admin/api/Settings/company/sendfromaddress' }
            'Theme' { '/admin/api/Settings/company/theme/v2' }
            'Tile' { '/admin/api/Settings/company/tile' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminCompanySetting:$Name" -Force:$Force
    }
}