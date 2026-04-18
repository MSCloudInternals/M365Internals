Describe 'Get-M365AdminCompanySetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            switch ($Path) {
                '/admin/api/tenant/datalocationandcommitments' {
                    [pscustomobject]@{ PrimaryLocation = 'EUR' }
                }
                '/admin/api/tenant/localdatalocation' {
                    [pscustomobject]@{ Locations = @('EUR') }
                }
                default {
                    [pscustomobject]@{
                        Path = $Path
                        Enabled = $true
                    }
                }
            }
        }
    }

    It 'returns grouped company settings by default' {
        $result = Get-M365AdminCompanySetting

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.CompanySetting'
        $result.Theme.PSObject.TypeNames | Should -Contain 'M365Admin.CompanySetting.Theme'
        $result.DataLocation.PSObject.TypeNames | Should -Contain 'M365Admin.CompanySetting.DataLocation'
        $result.KeyboardShortcuts.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
    }

    It 'normalizes organization information to the profile contract' {
        $result = Get-M365AdminCompanySetting -Name OrganizationInformation

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.CompanySetting.Profile'
        $result.ItemName | Should -Be 'Profile'
        $result.Endpoint | Should -Be '/admin/api/Settings/company/profile'
    }
}