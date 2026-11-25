Describe 'Set-M365AdminUserOwnedAppSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod { }
        Mock -ModuleName M365Internals Get-M365PortalTenantId { 'tenant-1234' }
        Mock -ModuleName M365Internals Clear-M365Cache { }
        Mock -ModuleName M365Internals Get-M365AdminUserOwnedAppSetting {
            [pscustomobject]@{
                StoreAccess           = $true
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
            $Method -eq 'Put'
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

        $result.StoreAccess | Should -Be $true
        $result.InAppPurchasesAllowed | Should -Be $false
    }

    It 'throws when no values are provided' {
        { Set-M365AdminUserOwnedAppSetting -Confirm:$false } | Should -Throw 'At least one user-owned apps setting value must be provided.'
    }

    It 'stops after write <FailAt> fails with <Preference>' -TestCases @(
        @{ FailAt = 1; Preference = 'Stop' }
        @{ FailAt = 1; Preference = 'SilentlyContinue' }
        @{ FailAt = 2; Preference = 'Stop' }
        @{ FailAt = 2; Preference = 'SilentlyContinue' }
    ) {
        param($FailAt, $Preference)
        $script:writeCount = 0
        $script:failAt = $FailAt
        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod {
            $script:writeCount++
            if ($script:writeCount -eq $script:failAt) {
                throw 'Synthetic write failure'
            }
        }

        $result = $null
        $failure = $null
        try {
            $result = Set-M365AdminUserOwnedAppSetting -LetUsersAccessOfficeStore $true -LetUsersStartTrials $true -LetUsersAutoClaimLicenses $true -PassThru -Confirm:$false -ErrorAction $Preference
        }
        catch { $failure = $_ }

        $result | Should -BeNullOrEmpty
        $failure.Exception.Message | Should -Match 'Synthetic write failure'
        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly $FailAt
        Assert-MockCalled Get-M365AdminUserOwnedAppSetting -ModuleName M365Internals -Exactly 0
        Assert-MockCalled Clear-M365Cache -ModuleName M365Internals -Exactly ($FailAt - 1)
        if ($FailAt -eq 2) {
            $failure.Exception.Message | Should -Match 'earlier update succeeded'
        }
    }

    It 'does not write or clear cache under WhatIf' {
        Set-M365AdminUserOwnedAppSetting -LetUsersAccessOfficeStore $true -PassThru -WhatIf
        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 0
        Assert-MockCalled Clear-M365Cache -ModuleName M365Internals -Exactly 0
        Assert-MockCalled Get-M365AdminUserOwnedAppSetting -ModuleName M365Internals -Exactly 0
    }
}
