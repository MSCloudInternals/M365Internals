Describe 'Set-M365AdminCompanySetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminCompanySetting {
            [pscustomobject]@{
                Existing = 'KeepMe'
                Enabled  = $false
            }
        }

        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod {
            [pscustomobject]@{ Success = $true }
        }

        Mock -ModuleName M365Internals Get-M365PortalTenantId { 'tenant-1234' }
        Mock -ModuleName M365Internals Clear-M365Cache { }
    }

    It 'posts merged company payloads for post-backed routes' {
        Set-M365AdminCompanySetting -Name Profile -Settings @{
            Enabled = $true
            Added   = 'NewValue'
        } -Confirm:$false | Out-Null

        Assert-MockCalled Get-M365AdminCompanySetting -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Name -eq 'Profile' -and $Raw.IsPresent -and -not $Force.IsPresent
        }

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/Settings/company/profile' -and
            $Method -eq 'Post' -and
            $Body.Enabled -eq $true -and
            $Body.Existing -eq 'KeepMe' -and
            $Body.Added -eq 'NewValue'
        }

        Assert-MockCalled Clear-M365Cache -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $TenantId -eq 'tenant-1234'
        }
    }

    It 'uses put for theme-backed routes' {
        Set-M365AdminCompanySetting -Name Theme -Settings @{ Enabled = $true } -Confirm:$false | Out-Null

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/Settings/company/theme/v2' -and
            $Method -eq 'Put' -and
            $Body.Enabled -eq $true -and
            $Body.Existing -eq 'KeepMe'
        }
    }

    It 'returns refreshed data when PassThru is used' {
        $script:getCallCount = 0
        Mock -ModuleName M365Internals Get-M365AdminCompanySetting {
            $script:getCallCount++
            if ($script:getCallCount -eq 1) {
                [pscustomobject]@{ Enabled = $false }
            }
            else {
                [pscustomobject]@{ Enabled = $true }
            }
        }

        $result = Set-M365AdminCompanySetting -Name HelpDesk -Settings @{ Enabled = $true } -PassThru -Confirm:$false

        $result.Enabled | Should -Be $true
        Assert-MockCalled Get-M365AdminCompanySetting -ModuleName M365Internals -Exactly 2
        Assert-MockCalled Get-M365AdminCompanySetting -ModuleName M365Internals -Exactly 1 -ParameterFilter { $Raw.IsPresent }
        Assert-MockCalled Get-M365AdminCompanySetting -ModuleName M365Internals -Exactly 1 -ParameterFilter { -not $Raw.IsPresent }
    }
}