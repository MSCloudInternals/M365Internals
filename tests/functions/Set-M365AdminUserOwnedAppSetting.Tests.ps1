Describe 'Set-M365AdminUserOwnedAppSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod { }
        Mock -ModuleName M365Internals Get-M365PortalTenantId { 'tenant-1234' }
        Mock -ModuleName M365Internals Clear-M365Cache { }
        Mock -ModuleName M365Internals Get-M365AdminUserOwnedAppSetting {
            [pscustomobject]@{
                StoreAccess           = [pscustomobject]@{ Enabled = $true }
                InAppPurchasesAllowed = $false
                AutoClaimPolicy       = [pscustomobject]@{ tenantPolicyValue = 'Disabled' }
            }
        }
    }

    It 'posts the Office Store access payload' {
        Set-M365AdminUserOwnedAppSetting -LetUsersAccessOfficeStore $true -Confirm:$false

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/settings/apps/store' -and
            $Method -eq 'Post' -and
            $Body.Enabled -eq $true
        }
    }

    It 'puts the trials toggle to the stateful endpoint' {
        Set-M365AdminUserOwnedAppSetting -LetUsersStartTrials $false -Confirm:$false

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/storesettings/iwpurchase/false' -and
            $Method -eq 'Put' -and
            $null -eq $Body
        }
    }

    It 'posts the auto-claim state and returns grouped data when PassThru is used' {
        $result = Set-M365AdminUserOwnedAppSetting -LetUsersAutoClaimLicenses $false -PassThru -Confirm:$false

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/fd/m365licensing/v1/policies/autoclaim' -and
            $Method -eq 'Post' -and
            $Body.policyValue -eq 'Disabled'
        }

        Assert-MockCalled Get-M365AdminUserOwnedAppSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Force.IsPresent
        }

        $result.StoreAccess.Enabled | Should -Be $true
        $result.InAppPurchasesAllowed | Should -Be $false
    }

    It 'throws when no values are provided' {
        { Set-M365AdminUserOwnedAppSetting -Confirm:$false } | Should -Throw 'At least one user-owned apps setting value must be provided.'
    }
}
