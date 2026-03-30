Describe 'Set-M365AdminPeopleSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPeopleSetting {
            [pscustomobject]@{
                isEnabledInOrganization = $false
                Existing = 'KeepMe'
            }
        }

        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod {
            [pscustomobject]@{ Success = $true }
        }

        Mock -ModuleName M365Internals Get-M365PortalTenantId { 'tenant-1234' }
        Mock -ModuleName M365Internals Clear-M365Cache { }
    }

    It 'patches the selected people setting payload' {
        Set-M365AdminPeopleSetting -Name NamePronunciation -Settings @{ isEnabledInOrganization = $true } -Confirm:$false | Out-Null

        Assert-MockCalled Get-M365AdminPeopleSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Name -eq 'NamePronunciation' -and $Raw.IsPresent -and -not $Force.IsPresent
        }

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/fd/peopleadminservice/tenant-1234/settings/namePronunciation' -and
            $Method -eq 'Patch' -and
            $Body.isEnabledInOrganization -eq $true -and
            $Body.Existing -eq 'KeepMe'
        }
    }

    It 'returns refreshed data when PassThru is used' {
        $script:getCallCount = 0
        Mock -ModuleName M365Internals Get-M365AdminPeopleSetting {
            $script:getCallCount++
            if ($script:getCallCount -eq 1) {
                [pscustomobject]@{ isEnabledInOrganization = $false }
            }
            else {
                [pscustomobject]@{ isEnabledInOrganization = $true }
            }
        }

        $result = Set-M365AdminPeopleSetting -Name Pronouns -Settings @{ isEnabledInOrganization = $true } -PassThru -Confirm:$false

        $result.isEnabledInOrganization | Should -Be $true
        Assert-MockCalled Get-M365AdminPeopleSetting -ModuleName M365Internals -Exactly 2
        Assert-MockCalled Get-M365AdminPeopleSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter { $Raw.IsPresent }
        Assert-MockCalled Get-M365AdminPeopleSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter { -not $Raw.IsPresent }
    }
}