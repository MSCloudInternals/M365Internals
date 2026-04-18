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

Describe 'Get-M365AdminBrandCenterSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminAccessToken {
            [pscustomobject]@{
                Token = 'sharepoint-token'
            }
        }

        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            switch ($Path) {
                '/_api/spo.tenant/GetBrandCenterConfiguration' {
                    [pscustomobject]@{
                        IsBrandingEnabled = $true
                    }
                }
                "/_api/GroupSiteManager/GetValidSiteUrlFromAlias?alias='BrandGuide'&managedPath='sites'" {
                    [pscustomobject]@{
                        ValidSiteUrl = 'https://contoso.sharepoint.com/sites/BrandGuide'
                    }
                }
                default {
                    throw "Unexpected path: $Path"
                }
            }
        }
    }

    It 'returns typed Brand center bundle data by default' {
        $result = Get-M365AdminBrandCenterSetting

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.BrandCenterSetting'
        $result.Configuration.PSObject.TypeNames | Should -Contain 'M365Admin.BrandCenterSetting.Configuration'
        $result.Configuration.ItemName | Should -Be 'Configuration'
        $result.SiteUrl.PSObject.TypeNames | Should -Contain 'M365Admin.BrandCenterSetting.SiteUrl'
        $result.SiteUrl.Endpoint | Should -Be "/_api/GroupSiteManager/GetValidSiteUrlFromAlias?alias='BrandGuide'&managedPath='sites'"
        $result.SiteUrl.ValidSiteUrl | Should -Be 'https://contoso.sharepoint.com/sites/BrandGuide'
    }

    It 'returns raw Brand center payloads in raw mode' {
        $result = Get-M365AdminBrandCenterSetting -Raw

        $result.Configuration.IsBrandingEnabled | Should -BeTrue
        $result.SiteUrl.ValidSiteUrl | Should -Be 'https://contoso.sharepoint.com/sites/BrandGuide'
    }

    It 'returns typed Brand center leaf data by name' {
        $result = Get-M365AdminBrandCenterSetting -Name SiteUrl

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.BrandCenterSetting.SiteUrl'
        $result.ItemName | Should -Be 'SiteUrl'
        $result.Endpoint | Should -Be "/_api/GroupSiteManager/GetValidSiteUrlFromAlias?alias='BrandGuide'&managedPath='sites'"
        $result.ValidSiteUrl | Should -Be 'https://contoso.sharepoint.com/sites/BrandGuide'
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

InModuleScope M365Internals {
    Describe 'portal context header helpers' {
        It 'returns live-captured values for <Context>' -TestCases @(
            @{ Context = 'Homepage'; ExpectedAdminAppRequest = '/homepage'; ExpectedAppId = '050829af-7f24-4897-8f81-732bf47719ad'; ExpectedTargetApp = 'MAC' }
            @{ Context = 'MicrosoftSearch'; ExpectedAdminAppRequest = '/MicrosoftSearch'; ExpectedAppId = '36051945-c7f8-4505-8a9b-23f8ba62271e'; ExpectedTargetApp = 'MAC' }
            @{ Context = 'EnhancedRestore'; ExpectedAdminAppRequest = '/Settings/enhancedRestore'; ExpectedAppId = '08a68b73-8058-4c59-8bd5-7b6833e2af21'; ExpectedTargetApp = 'MAC' }
            @{ Context = 'BrandCenter'; ExpectedAdminAppRequest = '/brandcenter'; ExpectedAppId = '9f8918eb-b2b7-4b90-b5bd-86b38f6d4d23'; ExpectedTargetApp = 'SPO' }
            @{ Context = 'OfficeOnline'; ExpectedAdminAppRequest = '/Settings/Services/:/Settings/L1/OfficeOnline'; ExpectedAppId = '3fda709f-4f6c-4ba7-8da3-b3d031a4d675'; ExpectedTargetApp = 'MAC' }
            @{ Context = 'Viva'; ExpectedAdminAppRequest = '/viva'; ExpectedAppId = '050829af-7f24-4897-8f81-732bf47719ad'; ExpectedTargetApp = 'MAC' }
        ) {
            param (
                $Context,
                $ExpectedAdminAppRequest,
                $ExpectedAppId,
                $ExpectedTargetApp
            )

            $headers = Get-M365PortalContextHeaders -Context $Context

            $headers.'x-adminapp-request' | Should -Be $ExpectedAdminAppRequest
            $headers.'x-ms-mac-appid' | Should -Be $ExpectedAppId
            $headers.'x-ms-mac-target-app' | Should -Be $ExpectedTargetApp
            $headers.'x-ms-mac-version' | Should -Be 'host-mac_2026.4.2.8'
        }

        It 'returns the live-captured DataLocation request context values' {
            $headers = Get-M365PortalContextHeaders -Context DataLocation

            $headers.Referer | Should -Be 'https://admin.cloud.microsoft/'
            $headers.'x-adminapp-request' | Should -Be '/Settings/OrganizationProfile/:/Settings/L1/DataLocation'
            $headers.ContainsKey('x-ms-mac-appid') | Should -BeFalse
        }

        It 'maps <AdminAppRequest> to <ExpectedContext>' -TestCases @(
            @{ AdminAppRequest = '/homepage'; ExpectedContext = 'Homepage' }
            @{ AdminAppRequest = '/MicrosoftSearch'; ExpectedContext = 'MicrosoftSearch' }
            @{ AdminAppRequest = '/Settings/enhancedRestore'; ExpectedContext = 'EnhancedRestore' }
            @{ AdminAppRequest = '/Settings/OrganizationProfile/:/Settings/L1/DataLocation'; ExpectedContext = 'DataLocation' }
            @{ AdminAppRequest = '/brandcenter'; ExpectedContext = 'BrandCenter' }
            @{ AdminAppRequest = '/Settings/Services/:/Settings/L1/OfficeOnline'; ExpectedContext = 'OfficeOnline' }
            @{ AdminAppRequest = '/viva'; ExpectedContext = 'Viva' }
            @{ AdminAppRequest = '/unknown'; ExpectedContext = 'Homepage' }
        ) {
            param (
                $AdminAppRequest,
                $ExpectedContext
            )

            Resolve-M365PortalRequestContext -AdminAppRequest $AdminAppRequest | Should -Be $ExpectedContext
        }
    }
}

Describe 'surface-specific portal headers' {
    It 'uses Brand center headers and SharePoint authorization for Brand center reads' {
        $script:lastBrandCenterPortalCall = $null

        Mock -ModuleName M365Internals Get-M365AdminAccessToken {
            [pscustomobject]@{
                Token = 'sharepoint-token'
            }
        }

        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            $script:lastBrandCenterPortalCall = [pscustomobject]@{
                Path = $Path
                Headers = $Headers
            }

            [pscustomobject]@{}
        }

        Get-M365AdminBrandCenterSetting -Name Configuration | Out-Null

        $script:lastBrandCenterPortalCall.Path | Should -Be '/_api/spo.tenant/GetBrandCenterConfiguration'
        $script:lastBrandCenterPortalCall.Headers.'x-adminapp-request' | Should -Be '/brandcenter'
        $script:lastBrandCenterPortalCall.Headers.'x-ms-mac-appid' | Should -Be '9f8918eb-b2b7-4b90-b5bd-86b38f6d4d23'
        $script:lastBrandCenterPortalCall.Headers.'x-ms-mac-target-app' | Should -Be 'SPO'
        $script:lastBrandCenterPortalCall.Headers.Authorization | Should -Be 'Bearer sharepoint-token'
        Assert-MockCalled Get-M365AdminAccessToken -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $TokenType -eq 'SharePoint' -and $AdminAppRequest -eq '/brandcenter'
        }
    }

    It 'uses the EnhancedRestore portal context for <Name>' -TestCases @(
        @{ Name = 'BillingFeature'; ExpectedPath = "/_api/v2.1/billingFeatures('M365Backup')" }
        @{ Name = 'AzureSubscriptions'; ExpectedPath = '/admin/api/syntexbilling/azureSubscriptions' }
        @{ Name = 'EnhancedRestoreFeature'; ExpectedPath = '/fd/enhancedRestorev2/v1/featureSetting' }
    ) {
        param (
            $Name,
            $ExpectedPath
        )

        $script:lastBackupPortalCall = $null

        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            $script:lastBackupPortalCall = [pscustomobject]@{
                Path = $Path
                Headers = $Headers
            }

            [pscustomobject]@{
                value = @()
            }
        }

        Mock -ModuleName M365Internals Get-M365AdminEnhancedRestoreStatus {
            [pscustomobject]@{
                Status = 'Captured'
            }
        }

        Get-M365AdminMicrosoft365BackupSetting -Name $Name | Out-Null

        $script:lastBackupPortalCall.Path | Should -Be $ExpectedPath
        $script:lastBackupPortalCall.Headers.'x-adminapp-request' | Should -Be '/Settings/enhancedRestore'
        $script:lastBackupPortalCall.Headers.'x-ms-mac-appid' | Should -Be '08a68b73-8058-4c59-8bd5-7b6833e2af21'
        $script:lastBackupPortalCall.Headers.'x-ms-mac-target-app' | Should -Be 'MAC'
    }

    It 'uses the DataLocation portal context for company data location reads' {
        $script:dataLocationCalls = @()

        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            $script:dataLocationCalls += [pscustomobject]@{
                Path = $Path
                Headers = $Headers
            }

            [pscustomobject]@{}
        }

        Get-M365AdminCompanySetting -Name DataLocation | Out-Null

        $script:dataLocationCalls | Should -HaveCount 2
        @($script:dataLocationCalls.Path) | Should -Contain '/admin/api/tenant/datalocationandcommitments'
        @($script:dataLocationCalls.Path) | Should -Contain '/admin/api/tenant/localdatalocation'
        Assert-MockCalled Get-M365AdminPortalData -ModuleName M365Internals -Exactly 2 -ParameterFilter {
            $Headers.Referer -eq 'https://admin.cloud.microsoft/' -and
            $Headers.'x-adminapp-request' -eq '/Settings/OrganizationProfile/:/Settings/L1/DataLocation'
        }
    }

    It 'uses the DataLocation portal context for <Name>' -TestCases @(
        @{ Name = 'DataLocationAndCommitments'; ExpectedPath = '/admin/api/tenant/datalocationandcommitments' }
        @{ Name = 'LocalDataLocation'; ExpectedPath = '/admin/api/tenant/localdatalocation' }
    ) {
        param (
            $Name,
            $ExpectedPath
        )

        $script:lastTenantDataLocationCall = $null

        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            $script:lastTenantDataLocationCall = [pscustomobject]@{
                Path = $Path
                Headers = $Headers
            }

            [pscustomobject]@{}
        }

        Get-M365AdminTenantSetting -Name $Name | Out-Null

        $script:lastTenantDataLocationCall.Path | Should -Be $ExpectedPath
        $script:lastTenantDataLocationCall.Headers.Referer | Should -Be 'https://admin.cloud.microsoft/'
        $script:lastTenantDataLocationCall.Headers.'x-adminapp-request' | Should -Be '/Settings/OrganizationProfile/:/Settings/L1/DataLocation'
    }

    It 'uses the DataLocation portal context for pay-as-you-go data location reads' {
        $script:lastPayGoDataLocationCall = $null

        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            $script:lastPayGoDataLocationCall = [pscustomobject]@{
                Path = $Path
                Headers = $Headers
            }

            [pscustomobject]@{}
        }

        Get-M365AdminPayAsYouGoService -Name DataLocationAndCommitments | Out-Null

        $script:lastPayGoDataLocationCall.Path | Should -Be '/admin/api/tenant/datalocationandcommitments'
        $script:lastPayGoDataLocationCall.Headers.Referer | Should -Be 'https://admin.cloud.microsoft/'
        $script:lastPayGoDataLocationCall.Headers.'x-adminapp-request' | Should -Be '/Settings/OrganizationProfile/:/Settings/L1/DataLocation'
    }
}