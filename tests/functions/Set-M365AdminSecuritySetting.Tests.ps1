Describe 'Set-M365AdminSecuritySetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminSecuritySetting {
            [pscustomobject]@{
                Existing = 'KeepMe'
                isEnabled = $false
                IsBingDataCollectionConsented = $true
                isEnabledInOrganization = $false
            }
        }

        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod {
            [pscustomobject]@{ Success = $true }
        }

        Mock -ModuleName M365Internals Get-M365PortalTenantId { 'tenant-1234' }
        Mock -ModuleName M365Internals Clear-M365Cache { }
    }

    It 'posts merged security payloads for post-backed routes' {
        Set-M365AdminSecuritySetting -Name BingDataCollection -Settings @{ IsBingDataCollectionConsented = $false } -Confirm:$false | Out-Null

        Assert-MockCalled Get-M365AdminSecuritySetting -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Name -eq 'BingDataCollection' -and $Raw.IsPresent -and -not $Force.IsPresent
        }

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/settings/security/bingdatacollection' -and
            $Method -eq 'Post' -and
            $Body.IsBingDataCollectionConsented -eq $false -and
            $Body.Existing -eq 'KeepMe'
        }
    }

    It 'patches security defaults' {
        Set-M365AdminSecuritySetting -Name SecurityDefaults -Settings @{ isEnabled = $true } -Confirm:$false | Out-Null

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/identitysecurity/securitydefaults' -and
            $Method -eq 'Patch' -and
            $Body.isEnabled -eq $true -and
            $Body.Existing -eq 'KeepMe'
        }
    }

    It 'patches people-backed security toggles' {
        Set-M365AdminSecuritySetting -Name Pronouns -Settings @{ isEnabledInOrganization = $true } -Confirm:$false | Out-Null

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/fd/peopleadminservice/tenant-1234/settings/pronouns' -and
            $Method -eq 'Patch' -and
            $Body.isEnabledInOrganization -eq $true
        }
    }

    It 'returns refreshed data when PassThru is used' {
        $script:getCallCount = 0
        Mock -ModuleName M365Internals Get-M365AdminSecuritySetting {
            $script:getCallCount++
            if ($script:getCallCount -eq 1) {
                [pscustomobject]@{ IsBingDataCollectionConsented = $true }
            }
            else {
                [pscustomobject]@{ IsBingDataCollectionConsented = $false }
            }
        }

        $result = Set-M365AdminSecuritySetting -Name BingDataCollection -Settings @{ IsBingDataCollectionConsented = $false } -PassThru -Confirm:$false

        $result.IsBingDataCollectionConsented | Should -Be $false
        Assert-MockCalled Get-M365AdminSecuritySetting -ModuleName M365Internals -Exactly 2
        Assert-MockCalled Get-M365AdminSecuritySetting -ModuleName M365Internals -Exactly 1 -ParameterFilter { $Raw.IsPresent }
        Assert-MockCalled Get-M365AdminSecuritySetting -ModuleName M365Internals -Exactly 1 -ParameterFilter { -not $Raw.IsPresent }
    }
}