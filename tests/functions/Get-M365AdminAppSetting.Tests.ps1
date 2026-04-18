Describe 'Get-M365AdminAppSetting' {
    BeforeEach {
        $script:lastAppSettingPortalCall = $null

        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            $script:lastAppSettingPortalCall = [pscustomobject]@{
                Path = $Path
                CacheKey = $CacheKey
                Headers = $Headers
            }

            [pscustomobject]@{}
        }
    }

    It 'returns grouped app settings by default' {
        $result = Get-M365AdminAppSetting

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.AppSetting'
        $result.Bookings.PSObject.TypeNames | Should -Contain 'M365Admin.AppSetting.Bookings'
        $result.OfficeScripts.ItemName | Should -Be 'OfficeScripts'
        $result.Microsoft365OnTheWeb.Endpoint | Should -Be '/admin/api/settings/apps/officeonline'
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

    It 'uses the OfficeOnline portal context for Office Online surfaces' -TestCases @(
        @{ Name = 'OfficeOnline'; ExpectedPath = '/admin/api/settings/apps/officeonline' }
        @{ Name = 'Microsoft365OnTheWeb'; ExpectedPath = '/admin/api/settings/apps/officeonline' }
    ) {
        param (
            $Name,
            $ExpectedPath
        )

        Get-M365AdminAppSetting -Name $Name | Out-Null

        $script:lastAppSettingPortalCall.Path | Should -Be $ExpectedPath
        $script:lastAppSettingPortalCall.Headers.'x-adminapp-request' | Should -Be '/Settings/Services/:/Settings/L1/OfficeOnline'
        $script:lastAppSettingPortalCall.Headers.'x-ms-mac-appid' | Should -Be '3fda709f-4f6c-4ba7-8da3-b3d031a4d675'
        $script:lastAppSettingPortalCall.Headers.'x-ms-mac-target-app' | Should -Be 'MAC'
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
