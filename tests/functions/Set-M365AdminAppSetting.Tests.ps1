Describe 'Set-M365AdminAppSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminAppSetting {
            [pscustomobject]@{
                Enabled  = $false
                Existing = 'KeepMe'
            }
        }

        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod {
            [pscustomobject]@{ Success = $true }
        }

        Mock -ModuleName M365Internals Get-M365PortalTenantId { 'tenant-1234' }
        Mock -ModuleName M365Internals Clear-M365Cache { }
    }

    It 'posts a merged payload to the resolved endpoint' {
        Set-M365AdminAppSetting -Name OfficeScripts -Settings @{
            Enabled = $true
            Added   = 'NewValue'
        } -Confirm:$false | Out-Null

        Assert-MockCalled Get-M365AdminAppSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Name -eq 'OfficeScripts' -and $Raw.IsPresent -and -not $Force.IsPresent
        }

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/settings/apps/officescripts' -and
            $Method -eq 'Post' -and
            $Body.Enabled -eq $true -and
            $Body.Existing -eq 'KeepMe' -and
            $Body.Added -eq 'NewValue'
        }

        Assert-MockCalled Clear-M365Cache -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $TenantId -eq 'tenant-1234'
        }
    }

    It 'returns refreshed settings when PassThru is used' {
        $script:getCallCount = 0
        Mock -ModuleName M365Internals Get-M365AdminAppSetting {
            $script:getCallCount++
            if ($script:getCallCount -eq 1) {
                [pscustomobject]@{ Enabled = $false }
            }
            else {
                [pscustomobject]@{ Enabled = $true }
            }
        }

        $result = Set-M365AdminAppSetting -Name Bookings -Settings @{ Enabled = $true } -PassThru -Confirm:$false

        $result.Enabled | Should -Be $true
        Assert-MockCalled Get-M365AdminAppSetting -ModuleName M365Internals -Exactly 2
        Assert-MockCalled Get-M365AdminAppSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter { $Raw.IsPresent }
        Assert-MockCalled Get-M365AdminAppSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter { -not $Raw.IsPresent }
    }

    It 'wraps primitive Boolean payloads in a writable body' {
        Mock -ModuleName M365Internals Get-M365AdminAppSetting { $true }

        Set-M365AdminAppSetting -Name Store -Settings @{ Enabled = $false } -Confirm:$false | Out-Null

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/settings/apps/store' -and
            $Method -eq 'Post' -and
            $Body.Enabled -eq $false
        }
    }

    It 'throws when the current payload is unavailable' {
        $unavailableResult = [pscustomobject]@{
            Name        = 'Bookings'
            Description = 'Endpoint unavailable'
        }
        $unavailableResult.PSObject.TypeNames.Insert(0, 'M365Admin.UnavailableResult')

        Mock -ModuleName M365Internals Get-M365AdminAppSetting { $unavailableResult }

        {
            Set-M365AdminAppSetting -Name Bookings -Settings @{ Enabled = $true } -Confirm:$false
        } | Should -Throw "Cannot update unavailable settings payload 'Bookings'. Endpoint unavailable"

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 0
    }
}
