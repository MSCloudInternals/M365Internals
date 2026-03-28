Describe 'Get-M365AdminUserOwnedAppSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            switch ($Path) {
                '/admin/api/settings/apps/store' {
                    [pscustomobject]@{ Enabled = $true }
                }
                '/admin/api/storesettings/iwpurchaseallowed' {
                    $true
                }
                '/fd/m365licensing/v1/policies/autoclaim' {
                    [pscustomobject]@{ tenantPolicyValue = 'Enabled' }
                }
                default {
                    throw "Unexpected path: $Path"
                }
            }
        }
    }

    It 'returns grouped data by default' {
        $result = Get-M365AdminUserOwnedAppSetting

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.UserOwnedAppSetting'
        $result.StoreAccess.Enabled | Should -Be $true
        $result.InAppPurchasesAllowed | Should -Be $true
        $result.AutoClaimPolicy.tenantPolicyValue | Should -Be 'Enabled'
    }

    It 'maps <Name> to <ExpectedPath>' -TestCases @(
        @{ Name = 'StoreAccess'; ExpectedPath = '/admin/api/settings/apps/store' }
        @{ Name = 'InAppPurchasesAllowed'; ExpectedPath = '/admin/api/storesettings/iwpurchaseallowed' }
        @{ Name = 'AutoClaimPolicy'; ExpectedPath = '/fd/m365licensing/v1/policies/autoclaim' }
    ) {
        param (
            $Name,
            $ExpectedPath
        )

        $expectedCacheKey = "M365AdminUserOwnedAppSetting:$Name"

        Get-M365AdminUserOwnedAppSetting -Name $Name | Out-Null

        Assert-MockCalled Get-M365AdminPortalData -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq $ExpectedPath -and $CacheKey -eq $expectedCacheKey
        }
    }

    It 'wraps unavailable grouped leaf results in standardized objects' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            throw 'Endpoint unavailable'
        } -ParameterFilter { $Path -eq '/admin/api/storesettings/iwpurchaseallowed' }

        $result = Get-M365AdminUserOwnedAppSetting

        $result.InAppPurchasesAllowed.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
        $result.InAppPurchasesAllowed.Name | Should -Be 'InAppPurchasesAllowed'
    }
}
