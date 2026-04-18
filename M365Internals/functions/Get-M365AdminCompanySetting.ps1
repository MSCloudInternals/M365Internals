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
        [Parameter()]
        [ValidateSet('All', 'CustomThemes', 'CustomTilesForApps', 'DataLocation', 'HelpDesk', 'HelpDeskInformation', 'KeyboardShortcuts', 'OrganizationInformation', 'Profile', 'ReleasePreferences', 'ReleaseTrack', 'SendEmailNotificationsFromYourDomain', 'SendFromAddress', 'SupportIntegration', 'Theme', 'Tile')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $forceRequested = $Force
        $allNames = @(
            'Theme',
            'Tile',
            'HelpDesk',
            'Profile',
            'ReleaseTrack',
            'SendFromAddress',
            'SupportIntegration',
            'DataLocation',
            'KeyboardShortcuts'
        )

        function Get-CompanySettingResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [string]$Path
            )

            $result = Get-M365AdminPortalData -Path $Path -CacheKey "M365AdminCompanySetting:$ResultName" -Force:$forceRequested
            if ($null -ne $result) {
                return $result
            }

            return New-M365AdminUnavailableResult -Name $ResultName -Description 'The portal did not return a settings payload for this company setting in the current tenant.' -Reason 'TenantSpecific'
        }

        function Resolve-CompanySettingCanonicalName {
            param (
                [Parameter(Mandatory)]
                [string]$RequestedName
            )

            switch ($RequestedName) {
                'CustomThemes' { return 'Theme' }
                'CustomTilesForApps' { return 'Tile' }
                'HelpDeskInformation' { return 'HelpDesk' }
                'OrganizationInformation' { return 'Profile' }
                'ReleasePreferences' { return 'ReleaseTrack' }
                'SendEmailNotificationsFromYourDomain' { return 'SendFromAddress' }
                default { return $RequestedName }
            }
        }

        function Get-CompanySettingView {
            param (
                [Parameter(Mandatory)]
                [string]$RequestedName
            )

            $canonicalName = Resolve-CompanySettingCanonicalName -RequestedName $RequestedName

            if ($canonicalName -eq 'DataLocation') {
                $dataLocationHeaders = Get-M365PortalContextHeaders -Context DataLocation
                $rawResult = [ordered]@{
                    DataLocationAndCommitments = Get-M365AdminPortalData -Path '/admin/api/tenant/datalocationandcommitments' -CacheKey 'M365AdminCompanySetting:DataLocationAndCommitments' -Headers $dataLocationHeaders -Force:$forceRequested
                    LocalDataLocation = Get-M365AdminPortalData -Path '/admin/api/tenant/localdatalocation' -CacheKey 'M365AdminCompanySetting:LocalDataLocation' -Headers $dataLocationHeaders -Force:$forceRequested
                }

                $items = [ordered]@{
                    DataLocationAndCommitments = ConvertTo-M365AdminResult -InputObject $rawResult.DataLocationAndCommitments -TypeName 'M365Admin.CompanySetting.DataLocationAndCommitments' -Category 'Company settings' -ItemName 'DataLocationAndCommitments' -Endpoint '/admin/api/tenant/datalocationandcommitments'
                    LocalDataLocation = ConvertTo-M365AdminResult -InputObject $rawResult.LocalDataLocation -TypeName 'M365Admin.CompanySetting.LocalDataLocation' -Category 'Company settings' -ItemName 'LocalDataLocation' -Endpoint '/admin/api/tenant/localdatalocation'
                }

                $defaultResult = New-M365AdminResultBundle -TypeName 'M365Admin.CompanySetting.DataLocation' -Category 'Company settings' -Items $items -RawData ([pscustomobject]$rawResult)
                return [pscustomobject]@{
                    Name = $canonicalName
                    Path = '/admin/api/tenant/datalocationandcommitments'
                    Raw = [pscustomobject]$rawResult
                    Default = $defaultResult
                }
            }

            if ($canonicalName -eq 'KeyboardShortcuts') {
                $defaultResult = New-M365AdminUnavailableResult -Name 'Keyboard shortcuts' -Description 'The Org settings Keyboard shortcuts item appears to be a static help surface rather than a dedicated settings API.' -Reason 'Informational'
                Add-Member -InputObject $defaultResult -NotePropertyName Shortcut -NotePropertyValue 'Shift+?' -Force
                return [pscustomobject]@{
                    Name = $canonicalName
                    Path = $null
                    Raw = $defaultResult
                    Default = $defaultResult
                }
            }

            $path = switch ($canonicalName) {
                'HelpDesk' { '/admin/api/Settings/company/helpdesk' }
                'Profile' { '/admin/api/Settings/company/profile' }
                'ReleaseTrack' { '/admin/api/Settings/company/releasetrack' }
                'SendFromAddress' { '/admin/api/Settings/company/sendfromaddress' }
                'SupportIntegration' { '/admin/api/supportRepository/my' }
                'Theme' { '/admin/api/Settings/company/theme/v2' }
                'Tile' { '/admin/api/Settings/company/tile' }
            }

            $rawResult = Get-CompanySettingResult -ResultName $canonicalName -Path $path
            $defaultResult = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName ("M365Admin.CompanySetting.{0}" -f $canonicalName) -Category 'Company settings' -ItemName $canonicalName -Endpoint $path

            return [pscustomobject]@{
                Name = $canonicalName
                Path = $path
                Raw = $rawResult
                Default = $defaultResult
            }
        }

        if ($Name -eq 'All') {
            $rawResults = [ordered]@{}
            $defaultResults = [ordered]@{}

            foreach ($itemName in $allNames) {
                $view = Get-CompanySettingView -RequestedName $itemName
                $rawResults[$itemName] = $view.Raw
                $defaultResults[$itemName] = $view.Default
            }

            $result = New-M365AdminResultBundle -TypeName 'M365Admin.CompanySetting' -Category 'Company settings' -Items $defaultResults -RawData ([pscustomobject]$rawResults)
            return Resolve-M365AdminOutput -DefaultValue $result -RawValue ([pscustomobject]$rawResults) -Raw:$Raw -RawJson:$RawJson
        }

        $view = Get-CompanySettingView -RequestedName $Name
        return Resolve-M365AdminOutput -DefaultValue $view.Default -RawValue $view.Raw -Raw:$Raw -RawJson:$RawJson
    }
}