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

    It 'wraps known unavailable live surfaces in standardized objects' -TestCases @(
        @{ Name = 'OfficeScripts'; ErrorMessage = 'Response status code does not indicate success: 400 (Bad Request).' }
        @{ Name = 'Dynamics365ConnectionGraph'; ErrorMessage = 'Response status code does not indicate success: 404 (Not Found).' }
        @{ Name = 'Dynamics365SalesInsights'; ErrorMessage = 'Response status code does not indicate success: 400 (Bad Request).' }
    ) {
        param (
            $Name,
            $ErrorMessage
        )

        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            throw $ErrorMessage
        }

        $result = Get-M365AdminAppSetting -Name $Name

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
        $result.Name | Should -Be $Name
        $result.Reason | Should -Be 'ProvisioningOrLicensing'
        $result.HttpStatusCode | Should -Be ([int]($ErrorMessage -replace '.*?(400|404).*', '$1'))
        $result.Description | Should -Match 'licensed|provisioned'
        $result.SuggestedAction | Should -Match 'license|provision'
    }

    It 'continues to throw for non-fallback app-setting errors' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            throw 'Response status code does not indicate success: 404 (Not Found).'
        }

        { Get-M365AdminAppSetting -Name Project } | Should -Throw 'Response status code does not indicate success: 404 (Not Found).'
    }
}
