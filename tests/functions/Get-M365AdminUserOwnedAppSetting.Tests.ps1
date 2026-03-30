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
        $result.StoreAccess | Should -Be $true
        $result.InAppPurchasesAllowed | Should -Be $true
        $result.AutoClaimPolicy.tenantPolicyValue | Should -Be 'Enabled'
    }

    It 'normalizes StoreAccess to a Boolean for direct reads' {
        $result = Get-M365AdminUserOwnedAppSetting -Name StoreAccess

        $result | Should -BeOfType ([bool])
        $result | Should -Be $true
    }

    It 'returns the unmodified StoreAccess payload when Raw is used' {
        $result = Get-M365AdminUserOwnedAppSetting -Name StoreAccess -Raw

        $result.Enabled | Should -Be $true
        $result | Should -Not -BeOfType ([bool])
    }

    It 'returns grouped raw payloads as JSON when RawJson is used' {
        $result = Get-M365AdminUserOwnedAppSetting -RawJson

        $result | Should -BeOfType ([string])
        $result | Should -Match '"StoreAccess"'
        $result | Should -Match '"Enabled"\s*:\s*true'
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
            throw 'Response status code does not indicate success: 400 (Bad Request).'
        } -ParameterFilter { $Path -eq '/admin/api/storesettings/iwpurchaseallowed' }

        $result = Get-M365AdminUserOwnedAppSetting

        $result.InAppPurchasesAllowed.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
        $result.InAppPurchasesAllowed.Name | Should -Be 'InAppPurchasesAllowed'
        $result.InAppPurchasesAllowed.Reason | Should -Be 'ProvisioningOrLicensing'
        $result.InAppPurchasesAllowed.HttpStatusCode | Should -Be 400
        $result.InAppPurchasesAllowed.SuggestedAction | Should -Match 'license|provision'
    }
}
