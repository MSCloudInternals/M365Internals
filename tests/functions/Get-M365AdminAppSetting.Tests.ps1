Describe 'Get-M365AdminAppSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData { [pscustomobject]@{} }
    }

    It 'maps <Name> to <ExpectedPath>' -TestCases @(
        @{ Name = 'Dynamics365ConnectionGraph'; ExpectedPath = '/admin/api/settings/apps/dcg' }
        @{ Name = 'Dynamics365SalesInsights'; ExpectedPath = '/admin/api/settings/apps/dci' }
        @{ Name = 'OfficeScripts'; ExpectedPath = '/admin/api/settings/apps/officescripts' }
        @{ Name = 'Project'; ExpectedPath = '/admin/api/settings/apps/projectonline' }
    ) {
        param (
            $Name,
            $ExpectedPath
        )

        $expectedCacheKey = "M365AdminAppSetting:$Name"

        Get-M365AdminAppSetting -Name $Name | Out-Null

        Assert-MockCalled Get-M365AdminPortalData -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq $ExpectedPath -and $CacheKey -eq $expectedCacheKey
        }
    }
}
