@{

    RootModule        = 'M365Internals.psm1'

    ModuleVersion     = '0.0.1'

    GUID              = '2f16c0f4-7064-4f0c-b296-24df7f12f0c1'

    Author            = 'Nathan McNulty'

    CompanyName       = 'Community Contributors'

    Copyright         = '(c) Nathan McNulty. All rights reserved.'

    Description       = 'The unofficial PowerShell module scaffold for interacting with the Microsoft 365 admin center.'

    FormatsToProcess  = @('M365Internals.Format.ps1xml')

    FunctionsToExport = @('Connect-M365Portal', 'Connect-M365PortalBySoftwarePasskey', 'Get-M365AdminAppSetting', 'Get-M365AdminCompanySetting', 'Get-M365AdminContentUnderstandingSetting', 'Get-M365AdminDomain', 'Get-M365AdminEnhancedRestoreStatus', 'Get-M365AdminFeature', 'Get-M365AdminGroup', 'Get-M365AdminHomeData', 'Get-M365AdminNavigation', 'Get-M365AdminPartnerClient', 'Get-M365AdminRecommendation', 'Get-M365AdminReportSetting', 'Get-M365AdminSearchSetting', 'Get-M365AdminSecuritySetting', 'Get-M365AdminService', 'Get-M365AdminShellInfo', 'Get-M365AdminTenantRelationship', 'Get-M365AdminTenantSetting', 'Get-M365AdminUserSetting', 'Get-M365AdminVivaSetting', 'Invoke-M365RestMethod')

    PrivateData       = @{

        PSData = @{

            Tags         = @('M365', 'Microsoft365', 'AdminCenter', 'PowerShell', 'Community')

            LicenseUri   = 'https://github.com/MSCloudInternals/M365Internals/blob/main/LICENSE'

            ProjectUri   = 'https://github.com/MSCloudInternals/M365Internals'

            ReleaseNotes = 'Added local software-passkey authentication for Connect-M365Portal, grouped read-only admin settings cmdlets, a shared cached portal data helper, and expanded Microsoft 365 admin coverage across settings, tenant, domain, search, Viva, reporting, and recommendation endpoints.'

        }

    }

}