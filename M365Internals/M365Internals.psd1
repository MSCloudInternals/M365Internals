@{

    RootModule        = 'M365Internals.psm1'

    ModuleVersion     = '0.0.1'

    GUID              = '2f16c0f4-7064-4f0c-b296-24df7f12f0c1'

    Author            = 'Nathan McNulty'

    CompanyName       = 'Community Contributors'

    Copyright         = '(c) Nathan McNulty. All rights reserved.'

    Description       = 'The unofficial PowerShell module for interacting with the Microsoft 365 admin center.'

    FormatsToProcess  = @('M365Internals.Format.ps1xml')

    FunctionsToExport = @('Connect-M365Portal', 'Connect-M365PortalByBrowser', 'Connect-M365PortalByCredential', 'Connect-M365PortalByEstsCookie', 'Connect-M365PortalByPhoneSignIn', 'Connect-M365PortalBySoftwarePasskey', 'Connect-M365PortalBySSO', 'Connect-M365PortalByTemporaryAccessPass', 'Get-M365AdminAgent', 'Get-M365AdminAgentOverview', 'Get-M365AdminAgentSetting', 'Get-M365AdminAgentTool', 'Get-M365AdminAppSetting', 'Get-M365AdminBookingsSetting', 'Get-M365AdminBrandCenterSetting', 'Get-M365AdminCompanySetting', 'Get-M365AdminCopilotBillingUsage', 'Get-M365AdminCopilotConnector', 'Get-M365AdminCopilotOverview', 'Get-M365AdminCopilotSetting', 'Get-M365AdminContentUnderstandingSetting', 'Get-M365AdminDirectorySyncError', 'Get-M365AdminDomain', 'Get-M365AdminEdgeSiteList', 'Get-M365AdminEnhancedRestoreStatus', 'Get-M365AdminFeature', 'Get-M365AdminGroup', 'Get-M365AdminHomeData', 'Get-M365AdminIntegratedAppSetting', 'Get-M365AdminMicrosoft365BackupSetting', 'Get-M365AdminMicrosoft365GroupSetting', 'Get-M365AdminMicrosoft365InstallationOption', 'Get-M365AdminMicrosoftEdgeSetting', 'Get-M365AdminNavigation', 'Get-M365AdminPartnerClient', 'Get-M365AdminPartnerRelationship', 'Get-M365AdminPayAsYouGoService', 'Get-M365AdminPeopleSetting', 'Get-M365AdminRecommendation', 'Get-M365AdminReportSetting', 'Get-M365AdminSearchAndIntelligenceSetting', 'Get-M365AdminSearchSetting', 'Get-M365AdminSecuritySetting', 'Get-M365AdminSelfServicePurchaseSetting', 'Get-M365AdminService', 'Get-M365AdminShellInfo', 'Get-M365AdminTenantRelationship', 'Get-M365AdminTenantSetting', 'Get-M365AdminUserOwnedAppSetting', 'Get-M365AdminUserSetting', 'Get-M365AdminVivaSetting', 'Invoke-M365AdminRestMethod', 'Set-M365AdminAppSetting', 'Set-M365AdminUserOwnedAppSetting')

    PrivateData       = @{

        PSData = @{

            Tags         = @('M365', 'Microsoft365', 'AdminCenter', 'PowerShell', 'Community')

            LicenseUri   = 'https://github.com/MSCloudInternals/M365Internals/blob/main/LICENSE'

            ProjectUri   = 'https://github.com/MSCloudInternals/M365Internals'

            ReleaseNotes = 'Expanded the Microsoft 365 admin authentication surface with credential, ESTS cookie, Temporary Access Pass, phone sign-in, browser, SSO, and software passkey connection flows, and added read-only plus write-capable app-setting and user-owned app cmdlets.'

        }

    }

}
