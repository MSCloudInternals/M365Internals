Describe 'Get-M365AdminSearchSetting' {
    BeforeEach {
        $script:lastSearchPortalCall = $null

        Mock -ModuleName M365Internals Get-M365PortalContextHeaders { @{} }
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            $script:lastSearchPortalCall = [pscustomobject]@{
                Path = $Path
                CacheKey = $CacheKey
                Method = $Method
                Body = $Body
                Headers = $Headers
            }

            [pscustomobject]@{
                Path = $Path
                Success = $true
            }
        }
    }

    It 'uses the requested QnAs service and filter values in the POST payload' {
        $result = Get-M365AdminSearchSetting -Name Qnas -QnasServiceType 'SharePoint' -QnasFilter 'Draft'

        $script:lastSearchPortalCall.Path | Should -Be '/admin/api/searchadminapi/Qnas'
        $script:lastSearchPortalCall.Method | Should -Be 'Post'
        $script:lastSearchPortalCall.Body.ServiceType | Should -Be 'SharePoint'
        $script:lastSearchPortalCall.Body.Filter | Should -Be 'Draft'
        $script:lastSearchPortalCall.CacheKey | Should -Be 'M365AdminSearchSetting:Qnas:SharePoint:Draft'
        $result.PSObject.TypeNames | Should -Contain 'M365Admin.SearchSetting.Qnas'
    }

    It 'returns actionable guidance for AccountLinking' {
        $result = Get-M365AdminSearchSetting -Name AccountLinking

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.SearchSetting.AccountLinking'
        $result.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
        $result.Name | Should -Be 'Account Linking'
        $result.Reason | Should -Be 'InteractiveOnly'
        $result.PortalRoute | Should -Be '#/Settings/EnterpriseMicrosoftRewards'
        $result.DirectReadSupported | Should -BeFalse
        $result.SuggestedAction | Should -Match 'DevTools|browser'
    }

    It 'falls back to the configuration inventory when the direct configurations endpoint is unavailable' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            throw 'Response status code does not indicate success: 503 (Service Unavailable).'
        } -ParameterFilter {
            $Path -eq '/admin/api/searchadminapi/configurations'
        }

        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            [pscustomobject]@{
                Settings = @(
                    [pscustomobject]@{
                        SettingName = 'SearchAdminConfigurationBingSetting'
                        TeamContact = 'ECSearchAdminFC'
                        PermissionLevel = 1
                    }
                )
            }
        } -ParameterFilter {
            $Path -eq '/admin/api/searchadminapi/ConfigurationSettings'
        }

        $result = Get-M365AdminSearchSetting -Name Configurations

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.SearchSetting.Configurations'
        $result.Status | Should -Be 'Fallback'
        $result.DirectConfigurations.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
        $result.DirectConfigurations.Name | Should -Be 'Configurations'
        $result.DirectConfigurations.Reason | Should -Be 'Transient'
        $result.DirectConfigurations.HttpStatusCode | Should -Be 503
        $result.ConfigurationCount | Should -Be 1
        $result.ConfigurationSettings[0].SettingName | Should -Be 'SearchAdminConfigurationBingSetting'
    }

    It 'returns the direct failure plus configuration inventory bundle when Configurations is requested with Raw' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            throw 'Response status code does not indicate success: 503 (Service Unavailable).'
        } -ParameterFilter {
            $Path -eq '/admin/api/searchadminapi/configurations'
        }

        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            [pscustomobject]@{
                Settings = @(
                    [pscustomobject]@{
                        SettingName = 'SearchAdminConfigurationBingSetting'
                        TeamContact = 'ECSearchAdminFC'
                        PermissionLevel = 1
                    }
                )
            }
        } -ParameterFilter {
            $Path -eq '/admin/api/searchadminapi/ConfigurationSettings'
        }

        $result = Get-M365AdminSearchSetting -Name Configurations -Raw

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.SearchSetting.Configurations.Raw'
        $result.DirectConfigurations.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
        $result.DirectConfigurations.HttpStatusCode | Should -Be 503
        $result.ConfigurationSettings.PSObject.TypeNames | Should -Contain 'M365Admin.SearchSetting.ConfigurationSettings'
        $result.ConfigurationSettings.Settings[0].SettingName | Should -Be 'SearchAdminConfigurationBingSetting'
    }
}

Describe 'Get-M365AdminPayAsYouGoService' {
    It 'describes the known telemetry route and next discovery step' {
        $result = Get-M365AdminPayAsYouGoService -Name Telemetry

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.PayAsYouGoService.Telemetry'
        $result.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
        $result.Name | Should -Be 'Telemetry'
        $result.RequestMethod | Should -Be 'Post'
        $result.RequestPath | Should -Be '/admin/api/km/setting/telemetry'
        $result.ObservedStatusCode | Should -Be 204
        $result.RequestBodyCaptured | Should -BeFalse
        $result.SuggestedAction | Should -Match 'DevTools|browser'
    }
}

Describe 'legacy output typing' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365PortalContextHeaders { @{} }
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            [pscustomobject]@{
                Path = $Path
                Enabled = $true
            }
        }
    }

    It 'adds type names to security settings results' {
        $result = Get-M365AdminSecuritySetting -Name BingDataCollection

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.SecuritySetting.BingDataCollection'
    }

    It 'adds type names to tenant settings results' {
        $result = Get-M365AdminTenantSetting -Name AccountSkus

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.TenantSetting.AccountSkus'
    }

    It 'adds type names to recommendation results' {
        $result = Get-M365AdminRecommendation -Name M365Suggestions

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.Recommendation.M365Suggestions'
    }
}