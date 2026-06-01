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
        $result.Cortana.Endpoint | Should -Be '/admin/api/settings/apps/cortana'
        $result.OfficeScripts.ItemName | Should -Be 'OfficeScripts'
        $result.Microsoft365OnTheWeb.Endpoint | Should -Be '/admin/api/settings/apps/officeonline'
        $result.Planner.Endpoint | Should -Be '/admin/api/settings/apps/planner'
        $result.ToDo.Endpoint | Should -Be '/admin/api/settings/apps/todo'
        $result.UserOwnedAppsAndServices.Endpoint | Should -Be '/admin/api/settings/apps/userownedapps'
    }

    It 'maps <Name> to <ExpectedPath>' -TestCases @(
        @{ Name = 'Cortana'; ExpectedPath = '/admin/api/settings/apps/cortana' }
        @{ Name = 'Dynamics365ConnectionGraph'; ExpectedPath = '/admin/api/settings/apps/dcg' }
        @{ Name = 'Dynamics365SalesInsights'; ExpectedPath = '/admin/api/settings/apps/dci' }
        @{ Name = 'OfficeOnTheWebPolicies'; ExpectedPath = '/fd/ocps/user/v1.0/web/policies' }
        @{ Name = 'OfficeScripts'; ExpectedPath = '/admin/api/settings/apps/officescripts' }
        @{ Name = 'Planner'; ExpectedPath = '/admin/api/settings/apps/planner' }
        @{ Name = 'Project'; ExpectedPath = '/admin/api/settings/apps/projectonline' }
        @{ Name = 'TeamsProvisioningCustomization'; ExpectedPath = '/admin/api/TeamsProvisioning/Customization' }
        @{ Name = 'ToDo'; ExpectedPath = '/admin/api/settings/apps/todo' }
        @{ Name = 'UserOwnedAppsAndServices'; ExpectedPath = '/admin/api/settings/apps/userownedapps' }
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
        @{ Name = 'UserOwnedAppsAndServices'; ErrorMessage = 'Response status code does not indicate success: 404 (Not Found).' }
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

    It 'keeps grouped app settings readable when user-owned apps are unavailable' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            if ($CacheKey -eq 'M365AdminAppSetting:UserOwnedAppsAndServices') {
                throw 'Response status code does not indicate success: 404 (Not Found).'
            }

            [pscustomobject]@{}
        }

        $result = Get-M365AdminAppSetting

        $result.UserOwnedAppsAndServices.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
        $result.UserOwnedAppsAndServices.Name | Should -Be 'UserOwnedAppsAndServices'
    }

    It 'continues to throw for non-fallback app-setting errors' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            throw 'Response status code does not indicate success: 404 (Not Found).'
        }

        { Get-M365AdminAppSetting -Name Project } | Should -Throw 'Response status code does not indicate success: 404 (Not Found).'
    }
}
