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

    .PARAMETER Raw
        Returns the raw company settings payload for the selected section.

    .PARAMETER RawJson
        Returns the raw company settings payload serialized as formatted JSON.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        function Get-CompanySettingResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [string]$Path
            )

            $result = Get-M365AdminPortalData -Path $Path -CacheKey "M365AdminCompanySetting:$ResultName" -Force:$Force
            if ($null -ne $result) {
                return $result
            }

            return New-M365AdminUnavailableResult -Name $ResultName -Description 'The portal did not return a settings payload for this company setting in the current tenant.' -Reason 'TenantSpecific'
        }

        if ($Name -eq 'DataLocation') {
            $dataLocationAndCommitments = Get-M365AdminPortalData -Path '/admin/api/tenant/datalocationandcommitments' -CacheKey 'M365AdminCompanySetting:DataLocationAndCommitments' -Force:$Force
            $localDataLocation = Get-M365AdminPortalData -Path '/admin/api/tenant/localdatalocation' -CacheKey 'M365AdminCompanySetting:LocalDataLocation' -Force:$Force

            $result = [pscustomobject]@{
                DataLocationAndCommitments = $dataLocationAndCommitments
                LocalDataLocation          = $localDataLocation
            }

            $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CompanySetting.DataLocation'
            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
        }

        if ($Name -eq 'KeyboardShortcuts') {
            $result = New-M365AdminUnavailableResult -Name 'Keyboard shortcuts' -Description 'The Org settings Keyboard shortcuts item appears to be a static help surface rather than a dedicated settings API.' -Reason 'Informational'
            Add-Member -InputObject $result -NotePropertyName Shortcut -NotePropertyValue 'Shift+?' -Force
            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
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

        $result = Get-CompanySettingResult -ResultName $Name -Path $path
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}