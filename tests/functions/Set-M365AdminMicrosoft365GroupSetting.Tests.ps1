Describe 'Set-M365AdminMicrosoft365GroupSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminMicrosoft365GroupSetting {
            [pscustomobject]@{
                AllowGuestAccess = $true
                Existing = 'KeepMe'
            }
        }

        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod {
            [pscustomobject]@{ Success = $true }
        }

        Mock -ModuleName M365Internals Get-M365PortalTenantId { 'tenant-1234' }
        Mock -ModuleName M365Internals Clear-M365Cache { }
    }

    It 'posts the guest access payload to the Microsoft 365 Groups route' {
        Set-M365AdminMicrosoft365GroupSetting -Name GuestAccess -Settings @{ AllowGuestAccess = $false } -Confirm:$false | Out-Null

        Assert-MockCalled Get-M365AdminMicrosoft365GroupSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Name -eq 'GuestAccess' -and $Raw.IsPresent -and -not $Force.IsPresent
        }

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/settings/security/o365guestuser' -and
            $Method -eq 'Post' -and
            $Body.AllowGuestAccess -eq $false -and
            $Body.Existing -eq 'KeepMe'
        }
    }

    It 'returns refreshed data when PassThru is used' {
        $script:getCallCount = 0
        Mock -ModuleName M365Internals Get-M365AdminMicrosoft365GroupSetting {
            $script:getCallCount++
            if ($script:getCallCount -eq 1) {
                [pscustomobject]@{ AllowGuestAccess = $true }
            }
            else {
                [pscustomobject]@{ AllowGuestAccess = $false }
            }
        }

        $result = Set-M365AdminMicrosoft365GroupSetting -Name GuestAccess -Settings @{ AllowGuestAccess = $false } -PassThru -Confirm:$false

        $result.AllowGuestAccess | Should -Be $false
        Assert-MockCalled Get-M365AdminMicrosoft365GroupSetting -ModuleName M365Internals -Exactly 2
        Assert-MockCalled Get-M365AdminMicrosoft365GroupSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter { $Raw.IsPresent }
        Assert-MockCalled Get-M365AdminMicrosoft365GroupSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter { -not $Raw.IsPresent }
    }
}