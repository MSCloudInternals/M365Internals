param (
    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [string]$BrowserPlanPath
)

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $artifactRoot 'module-settings-surface-captures.json'
}

if ([string]::IsNullOrWhiteSpace($BrowserPlanPath)) {
    $BrowserPlanPath = Join-Path $artifactRoot 'settings-browser-capture-plan.json'
}

$null = New-Item -Path (Split-Path -Path $OutputPath -Parent) -ItemType Directory -Force
$null = New-Item -Path (Split-Path -Path $BrowserPlanPath -Parent) -ItemType Directory -Force

function Get-ActiveM365PortalModule {
    $module = Get-Module M365Internals
    if ($null -eq $module) {
        Import-Module (Join-Path $PSScriptRoot '..\M365Internals\M365Internals.psd1') -ErrorAction Stop
        $module = Get-Module M365Internals
    }

    if ($null -eq $module) {
        throw 'The M365Internals module is not loaded in the current PowerShell process.'
    }

    return $module
}

function Get-ResolvedTenantId {
    param (
        [Parameter(Mandatory)]
        $Module
    )

    $connection = $Module.SessionState.PSVariable.GetValue('m365PortalConnection')
    if ($null -eq $connection -or [string]::IsNullOrWhiteSpace([string]$connection.TenantId)) {
        throw 'The active M365 admin portal connection does not currently expose a tenant ID.'
    }

    return [string]$connection.TenantId
}

function Invoke-CaptureOperation {
    param (
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    try {
        return [ordered]@{
            CaptureStatus = 'Captured'
            ErrorMessage = $null
            Value = & $ScriptBlock
        }
    }
    catch {
        return [ordered]@{
            CaptureStatus = 'Error'
            ErrorMessage = $_.Exception.Message
            Value = $null
        }
    }
}

function New-BrowserRequest {
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('Get', 'Post', 'Put', 'Patch', 'Delete')]
        [string]$Method = 'Get',

        [Parameter()]
        $Body,

        [Parameter()]
        [hashtable]$Headers,

        [Parameter()]
        [int]$TimeoutMs = 20000
    )

    $request = [ordered]@{
        Name = $Name
        Path = $Path
        Method = $Method
        TimeoutMs = $TimeoutMs
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $request.Body = $Body
    }

    if ($Headers) {
        $request.Headers = $Headers
    }

    return $request
}

function New-PortalContextHeaders {
    param (
        [Parameter(Mandatory)]
        [ValidateSet('MicrosoftSearch', 'Viva')]
        [string]$Context
    )

    $headers = @{
        Accept = 'application/json;odata=minimalmetadata, text/plain, */*'
        'x-edge-shopping-flag' = '1'
        'Cache-Control' = 'no-cache'
        Pragma = 'no-cache'
        'x-ms-mac-appid' = 'f00c5fa5-eee4-4f57-88fa-c082d83b3c94'
        'x-ms-mac-hostingapp' = 'M365AdminPortal'
        'x-ms-mac-target-app' = 'MAC'
        'x-ms-mac-version' = 'host-mac_2026.3.2.6'
    }

    switch ($Context) {
        'MicrosoftSearch' {
            $headers['Referer'] = 'https://admin.cloud.microsoft/?'
            $headers['x-adminapp-request'] = '/MicrosoftSearch'
        }
        'Viva' {
            $headers['Referer'] = 'https://admin.cloud.microsoft/'
            $headers['x-adminapp-request'] = '/viva'
        }
    }

    return $headers
}

function New-GraphProxyHeaders {
    param (
        [Parameter(Mandatory)]
        [string]$AdminAppRequest,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter()]
        [hashtable]$Headers
    )

    $resolvedHeaders = @{
        Accept = 'application/json;odata=minimalmetadata, text/plain, */*'
        'client-request-id' = [guid]::NewGuid().Guid
        'x-adminapp-request' = $AdminAppRequest
        'x-ms-mac-appid' = 'f00c5fa5-eee4-4f57-88fa-c082d83b3c94'
        'x-ms-mac-hostingapp' = 'M365AdminPortal'
        'x-ms-mac-target-app' = 'Graph'
        'x-anchormailbox' = 'TID:{0}' -f $TenantId
    }

    if ($Headers) {
        foreach ($header in @($Headers.GetEnumerator())) {
            $resolvedHeaders[$header.Key] = $header.Value
        }
    }

    return $resolvedHeaders
}

$module = Get-ActiveM365PortalModule
$portalSession = $module.SessionState.PSVariable.GetValue('m365PortalSession')
$portalHeaders = $module.SessionState.PSVariable.GetValue('m365PortalHeaders')

if ($null -eq $portalSession) {
    throw 'No active M365 admin portal session is loaded in the current PowerShell process. Reuse the authenticated shell, connect first, and rerun this script without spawning a new PowerShell instance.'
}

$tenantId = Get-ResolvedTenantId -Module $module
$defaultBrowserHeaders = [ordered]@{}
foreach ($header in @($portalHeaders.GetEnumerator())) {
    $defaultBrowserHeaders[$header.Key] = $header.Value
}

$searchHeaders = New-PortalContextHeaders -Context MicrosoftSearch
$vivaHeaders = New-PortalContextHeaders -Context Viva
$enhancedRestoreBatchBody = @{
    requests = @(
        @{
            id = 'GetOffboardingSiteProtectionUnits'
            method = 'GET'
            url = 'solutions/backupRestore/protectionUnits/microsoft.graph.siteProtectionUnit/$count?$filter=offboardRequestedDateTime gt 0001-01-01'
        },
        @{
            id = 'GetOffboardingDriveProtectionUnits'
            method = 'GET'
            url = 'solutions/backupRestore/protectionUnits/microsoft.graph.driveProtectionUnit/$count?$filter=offboardRequestedDateTime gt 0001-01-01'
        },
        @{
            id = 'GetOffboardingMailboxProtectionUnits'
            method = 'GET'
            url = 'solutions/backupRestore/protectionUnits/microsoft.graph.mailboxProtectionUnit/$count?$filter=offboardRequestedDateTime gt 0001-01-01'
        }
    )
}

$appSettingNames = @(
    'Bookings',
    'CalendarSharing',
    'DirectorySynchronization',
    'Dynamics365ConnectionGraph',
    'Dynamics365SalesInsights',
    'DynamicsCrm',
    'EndUserCommunications',
    'Learning',
    'LoopPolicy',
    'Mail',
    'O365DataPlan',
    'OfficeForms',
    'OfficeFormsPro',
    'OfficeOnline',
    'OfficeScripts',
    'Project',
    'SitesSharing',
    'SkypeTeams',
    'Store',
    'Sway',
    'UserSoftware',
    'Whiteboard'
)

$companySettingNames = @(
    'CustomThemes',
    'CustomTilesForApps',
    'DataLocation',
    'HelpDesk',
    'KeyboardShortcuts',
    'OrganizationInformation',
    'ReleasePreferences',
    'SendEmailNotificationsFromYourDomain',
    'SupportIntegration'
)

$contentUnderstandingNames = @(
    'AutoFill',
    'BillingSettings',
    'ESignature',
    'ImageTagging',
    'Licensing',
    'PlaybackTranscriptTranslation',
    'PowerAppsEnvironments',
    'Setting',
    'TaxonomyTagging'
)

$peopleSettingNames = @(
    'ProfileCardProperties',
    'ConnectorProperties',
    'PersonInfoOnProfileCards',
    'NamePronunciation',
    'Pronouns'
)

$reportSettingNames = @(
    'TenantConfiguration',
    'ProductivityScoreConfig',
    'ProductivityScoreCustomerOption',
    'AdoptionScore'
)

$searchSettingNames = @(
    'AccountLinking',
    'Configurations',
    'ConfigurationSettings',
    'FirstRunExperience',
    'ModernResultTypes',
    'News',
    'NewsIndustry',
    'NewsMsbEnabled',
    'NewsOptions',
    'Pivots',
    'Qnas',
    'SearchIntelligenceHomeCards',
    'UdtConnectorsSummary'
)

$securitySettingNames = @(
    'ActivityBasedTimeout',
    'BaselineSecurityMode',
    'BingDataCollection',
    'CustomerLockbox',
    'DataAccess',
    'GuestUserPolicy',
    'MultiFactorAuth',
    'NamePronunciation',
    'O365GuestUser',
    'PasswordExpirationPolicy',
    'PrivacyPolicy',
    'Pronouns',
    'SecurityDefaults',
    'SecuritySettings',
    'SecuritySettingsOptIn',
    'SecuritySettingsStatus',
    'SelfServicePasswordReset',
    'TenantLockbox'
)

$serviceSettingNames = @(
    'AzureSpeechServices',
    'Cortana',
    'DeveloperPortal',
    'M365Lighthouse',
    'MicrosoftAzureInformationProtection',
    'ModernAuth',
    'Planner',
    'Sales',
    'SearchAndIntelligenceUsageAnalytics',
    'Todo',
    'VivaInsights',
    'WhatsNewInMicrosoft365'
)

$tenantSettingNames = @(
    'AADLink',
    'AccountSkus',
    'DataLocationAndCommitments',
    'EligibleToRemoveSac',
    'LocalDataLocation',
    'O365ActivationUserCounts',
    'ReportsPrivacyEnabled'
)

$results = [ordered]@{
    CapturedAt = (Get-Date).ToUniversalTime().ToString('o')
    TenantId = $tenantId
    Settings = [ordered]@{}
}

$results.Settings.AppSetting = [ordered]@{}
foreach ($name in $appSettingNames) {
    $results.Settings.AppSetting[$name] = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminAppSetting -Name $name -Force }
}

$results.Settings.BookingsSetting = [ordered]@{
    Friendly = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminBookingsSetting -Force }
    Raw = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminBookingsSetting -Raw -Force }
}

$results.Settings.BrandCenterSetting = [ordered]@{
    Configuration = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminBrandCenterSetting -Name Configuration -Force }
    SiteUrl = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminBrandCenterSetting -Name SiteUrl -Force }
    All = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminBrandCenterSetting }
}

$results.Settings.CompanySetting = [ordered]@{}
foreach ($name in $companySettingNames) {
    $results.Settings.CompanySetting[$name] = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminCompanySetting -Name $name -Force }
}

$results.Settings.ContentUnderstandingSetting = [ordered]@{}
foreach ($name in $contentUnderstandingNames) {
    $results.Settings.ContentUnderstandingSetting[$name] = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminContentUnderstandingSetting -Name $name -Force }
}

$results.Settings.DirectorySyncError = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminDirectorySyncError -Force }

$results.Settings.IntegratedAppSetting = [ordered]@{
    Settings = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminIntegratedAppSetting -Name Settings -Force }
    AppCatalog = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminIntegratedAppSetting -Name AppCatalog -Force }
    AvailableApps = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminIntegratedAppSetting -Name AvailableApps -Force }
    ActionableApps = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminIntegratedAppSetting -Name ActionableApps -Force }
    PopularAppRecommendations = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminIntegratedAppSetting -Name PopularAppRecommendations -Force }
    All = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminIntegratedAppSetting }
}

$results.Settings.Microsoft365BackupSetting = [ordered]@{
    AzureSubscriptions = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365BackupSetting -Name AzureSubscriptions -Force }
    AzureSubscriptionPermissions = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365BackupSetting -Name AzureSubscriptionPermissions -Force }
    BillingFeature = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365BackupSetting -Name BillingFeature -Force }
    EnhancedRestoreFeature = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365BackupSetting -Name EnhancedRestoreFeature -Force }
    EnhancedRestoreStatus = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365BackupSetting -Name EnhancedRestoreStatus -Force }
    All = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365BackupSetting }
}

$results.Settings.Microsoft365GroupSetting = [ordered]@{
    GuestAccess = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365GroupSetting -Name GuestAccess -Force }
    GuestUserPolicy = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365GroupSetting -Name GuestUserPolicy -Force }
    OwnerlessGroupPolicy = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365GroupSetting -Name OwnerlessGroupPolicy -Force }
    All = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365GroupSetting }
}

$results.Settings.Microsoft365InstallationOption = [ordered]@{
    UserSoftware = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365InstallationOption -Name UserSoftware -Force }
    TenantInfo = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365InstallationOption -Name TenantInfo -Force }
    DefaultReleaseRule = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365InstallationOption -Name DefaultReleaseRule -Force }
    ReleaseManagement = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365InstallationOption -Name ReleaseManagement -Force }
    MecReleaseInfo = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365InstallationOption -Name MecReleaseInfo -Force }
    SacReleaseInfo = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365InstallationOption -Name SacReleaseInfo -Force }
    MonthlyReleaseInfo = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365InstallationOption -Name MonthlyReleaseInfo -Force }
    EligibleToRemoveSac = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365InstallationOption -Name EligibleToRemoveSac -Force }
    All = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoft365InstallationOption }
}

$results.Settings.MicrosoftEdgeSetting = [ordered]@{
    ConfigurationPolicies = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoftEdgeSetting -Name ConfigurationPolicies -Force }
    DeviceCount = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoftEdgeSetting -Name DeviceCount -Force }
    FeatureProfiles = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoftEdgeSetting -Name FeatureProfiles -Force }
    ExtensionPolicies = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoftEdgeSetting -Name ExtensionPolicies -Force }
    ExtensionFeedback = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoftEdgeSetting -Name ExtensionFeedback -Force }
    SiteLists = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoftEdgeSetting -Name SiteLists -Force }
    All = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminMicrosoftEdgeSetting }
}

$results.Settings.PartnerRelationship = [ordered]@{
    DAP = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPartnerRelationship -Name DAP -Force }
    GDAP = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPartnerRelationship -Name GDAP -Force }
    All = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPartnerRelationship }
}

$results.Settings.PayAsYouGoService = [ordered]@{
    BillingFeature = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name BillingFeature -Force }
    AzureSubscriptions = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name AzureSubscriptions -Force }
    EnhancedRestoreFeature = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name EnhancedRestoreFeature -Force }
    DataLocationAndCommitments = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name DataLocationAndCommitments -Force }
    PrimarySetting = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name PrimarySetting -Force }
    AutoFill = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name AutoFill -Force }
    Licensing = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name Licensing -Force }
    ImageTagging = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name ImageTagging -Force }
    ESignature = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name ESignature -Force }
    TaxonomyTagging = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name TaxonomyTagging -Force }
    PlaybackTranscriptTranslation = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name PlaybackTranscriptTranslation -Force }
    Telemetry = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService -Name Telemetry -Force }
    All = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPayAsYouGoService }
}

$results.Settings.PeopleSetting = [ordered]@{}
foreach ($name in $peopleSettingNames) {
    $results.Settings.PeopleSetting[$name] = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminPeopleSetting -Name $name -Force }
}

$results.Settings.ReportSetting = [ordered]@{}
foreach ($name in $reportSettingNames) {
    $results.Settings.ReportSetting[$name] = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminReportSetting -Name $name -Force }
}

$results.Settings.SearchSetting = [ordered]@{}
foreach ($name in $searchSettingNames) {
    $results.Settings.SearchSetting[$name] = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminSearchSetting -Name $name -Force }
}

$results.Settings.SearchAndIntelligenceSetting = [ordered]@{
    Overview = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name Overview }
    Insights = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name Insights }
    Answers = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name Answers }
    DataSources = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name DataSources }
    Customizations = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name Customizations }
    Configurations = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name Configurations }
    All = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting }
    Raw = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Raw }
}

$results.Settings.SecuritySetting = [ordered]@{}
foreach ($name in $securitySettingNames) {
    $results.Settings.SecuritySetting[$name] = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminSecuritySetting -Name $name -Force }
}

$results.Settings.SelfServicePurchaseSetting = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminSelfServicePurchaseSetting -Force }

$results.Settings.Service = [ordered]@{}
foreach ($name in $serviceSettingNames) {
    $results.Settings.Service[$name] = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminService -Name $name -Force }
}

$results.Settings.TenantSetting = [ordered]@{}
foreach ($name in $tenantSettingNames) {
    $results.Settings.TenantSetting[$name] = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminTenantSetting -Name $name -Force }
}

$results.Settings.UserOwnedAppSetting = [ordered]@{
    StoreAccess = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminUserOwnedAppSetting -Name StoreAccess -Force }
    InAppPurchasesAllowed = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminUserOwnedAppSetting -Name InAppPurchasesAllowed -Force }
    AutoClaimPolicy = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminUserOwnedAppSetting -Name AutoClaimPolicy -Force }
    All = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminUserOwnedAppSetting }
}

$results.Settings.VivaSetting = [ordered]@{
    Modules = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminVivaSetting -Name Modules -Force }
    Roles = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminVivaSetting -Name Roles -Force }
    GlintClient = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminVivaSetting -Name GlintClient -Force }
    AccountSkus = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminVivaSetting -Name AccountSkus -Force }
    All = Invoke-CaptureOperation -ScriptBlock { Get-M365AdminVivaSetting }
}

$azureSubscriptions = @()
if ($results.Settings.Microsoft365BackupSetting.AzureSubscriptions.CaptureStatus -eq 'Captured') {
    $azureSubscriptions = @($results.Settings.Microsoft365BackupSetting.AzureSubscriptions.Value.value)
}

$defaultReleaseRuleFilter = [uri]::EscapeDataString('FFN eq 55336b82-a18d-4dd6-b5f6-9e5095c314a6 and IsDefault eq true')
$mecReleaseFilter = [uri]::EscapeDataString("ServicingChannel eq 'MEC'")
$sacReleaseFilter = [uri]::EscapeDataString("ServicingChannel eq 'SAC'")
$monthlyReleaseFilter = [uri]::EscapeDataString("ServicingChannel eq 'Monthly'")

$browserPlan = [ordered]@{
    GeneratedAt = (Get-Date).ToUniversalTime().ToString('o')
    TenantId = $tenantId
    DefaultHeaders = $defaultBrowserHeaders
    Requests = [ordered]@{
        AppSettings = @(
            (New-BrowserRequest -Name 'Bookings' -Path '/admin/api/settings/apps/bookings'),
            (New-BrowserRequest -Name 'CalendarSharing' -Path '/admin/api/settings/apps/calendarsharing'),
            (New-BrowserRequest -Name 'DirectorySynchronization' -Path '/admin/api/settings/apps/dirsync'),
            (New-BrowserRequest -Name 'Dynamics365ConnectionGraph' -Path '/admin/api/settings/apps/dcg'),
            (New-BrowserRequest -Name 'Dynamics365SalesInsights' -Path '/admin/api/settings/apps/dci'),
            (New-BrowserRequest -Name 'DynamicsCrm' -Path '/admin/api/settings/apps/dynamicscrm'),
            (New-BrowserRequest -Name 'EndUserCommunications' -Path '/admin/api/settings/apps/EndUserCommunications'),
            (New-BrowserRequest -Name 'Learning' -Path '/admin/api/settings/apps/learning'),
            (New-BrowserRequest -Name 'LoopPolicy' -Path '/admin/api/settings/apps/looppolicy'),
            (New-BrowserRequest -Name 'Mail' -Path '/admin/api/settings/apps/mail'),
            (New-BrowserRequest -Name 'O365DataPlan' -Path '/admin/api/settings/apps/o365dataplan'),
            (New-BrowserRequest -Name 'OfficeForms' -Path '/admin/api/settings/apps/officeforms'),
            (New-BrowserRequest -Name 'OfficeFormsPro' -Path '/admin/api/settings/apps/officeformspro' -TimeoutMs 60000),
            (New-BrowserRequest -Name 'OfficeOnline' -Path '/admin/api/settings/apps/officeonline'),
            (New-BrowserRequest -Name 'OfficeScripts' -Path '/admin/api/settings/apps/officescripts'),
            (New-BrowserRequest -Name 'Project' -Path '/admin/api/settings/apps/projectonline'),
            (New-BrowserRequest -Name 'SitesSharing' -Path '/admin/api/settings/apps/sitessharing'),
            (New-BrowserRequest -Name 'SkypeTeams' -Path '/admin/api/settings/apps/skypeteams'),
            (New-BrowserRequest -Name 'Store' -Path '/admin/api/settings/apps/store'),
            (New-BrowserRequest -Name 'Sway' -Path '/admin/api/settings/apps/Sway'),
            (New-BrowserRequest -Name 'UserSoftware' -Path '/admin/api/settings/apps/usersoftware'),
            (New-BrowserRequest -Name 'Whiteboard' -Path '/admin/api/settings/apps/whiteboard')
        )
        CompanySettings = @(
            (New-BrowserRequest -Name 'Theme' -Path '/admin/api/Settings/company/theme/v2'),
            (New-BrowserRequest -Name 'Tile' -Path '/admin/api/Settings/company/tile'),
            (New-BrowserRequest -Name 'HelpDesk' -Path '/admin/api/Settings/company/helpdesk'),
            (New-BrowserRequest -Name 'Profile' -Path '/admin/api/Settings/company/profile'),
            (New-BrowserRequest -Name 'ReleaseTrack' -Path '/admin/api/Settings/company/releasetrack'),
            (New-BrowserRequest -Name 'SendFromAddress' -Path '/admin/api/Settings/company/sendfromaddress'),
            (New-BrowserRequest -Name 'SupportIntegration' -Path '/admin/api/supportRepository/my'),
            (New-BrowserRequest -Name 'DataLocationAndCommitments' -Path '/admin/api/tenant/datalocationandcommitments'),
            (New-BrowserRequest -Name 'LocalDataLocation' -Path '/admin/api/tenant/localdatalocation')
        )
        BrandCenter = @(
            (New-BrowserRequest -Name 'Configuration' -Path '/_api/spo.tenant/GetBrandCenterConfiguration'),
            (New-BrowserRequest -Name 'SiteUrl' -Path "/_api/GroupSiteManager/GetValidSiteUrlFromAlias?alias='BrandGuide'&managedPath='sites'")
        )
        ContentUnderstanding = @(
            (New-BrowserRequest -Name 'AutoFill' -Path '/admin/api/contentunderstanding/autofillsetting'),
            (New-BrowserRequest -Name 'BillingSettings' -Path '/admin/api/contentunderstanding/billingSettings'),
            (New-BrowserRequest -Name 'ESignature' -Path '/admin/api/contentunderstanding/esignaturesettings'),
            (New-BrowserRequest -Name 'ImageTagging' -Path '/admin/api/contentunderstanding/imagetaggingsetting'),
            (New-BrowserRequest -Name 'Licensing' -Path '/admin/api/contentunderstanding/licensing'),
            (New-BrowserRequest -Name 'PlaybackTranscriptTranslation' -Path '/admin/api/contentunderstanding/playbacktranscripttranslationsettings'),
            (New-BrowserRequest -Name 'PowerAppsEnvironments' -Path '/admin/api/contentunderstanding/powerAppsEnvironments'),
            (New-BrowserRequest -Name 'Setting' -Path '/admin/api/contentunderstanding/setting'),
            (New-BrowserRequest -Name 'TaxonomyTagging' -Path '/admin/api/contentunderstanding/taxonomytaggingsetting')
        )
        DirectorySyncError = @(
            (New-BrowserRequest -Name 'ListDirsyncErrors' -Path '/admin/api/dirsyncerrors/listdirsyncerrors' -Method Post)
        )
        IntegratedApps = @(
            (New-BrowserRequest -Name 'Settings' -Path '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings'),
            (New-BrowserRequest -Name 'AppCatalog' -Path '/fd/addins/api/apps?workloads=AzureActiveDirectory,WXPO,MetaOS,SharePoint'),
            (New-BrowserRequest -Name 'AvailableApps' -Path '/fd/addins/api/availableApps?workloads=MetaOS' -TimeoutMs 60000),
            (New-BrowserRequest -Name 'ActionableApps' -Path '/fd/addins/api/actionableApps?workloads=MetaOS'),
            (New-BrowserRequest -Name 'PopularAppRecommendations' -Path '/fd/addins/api/recommendations/appRecommendations?appRecommendationType=PopularApps')
        )
        Microsoft365Backup = @(
            (New-BrowserRequest -Name 'BillingFeature' -Path "/_api/v2.1/billingFeatures('M365Backup')"),
            (New-BrowserRequest -Name 'AzureSubscriptions' -Path '/admin/api/syntexbilling/azureSubscriptions'),
            (New-BrowserRequest -Name 'EnhancedRestoreFeature' -Path '/fd/enhancedRestorev2/v1/featureSetting'),
            (New-BrowserRequest -Name 'EnhancedRestoreStatus' -Path '/fd/msgraph/beta/$batch' -Method Post -Body $enhancedRestoreBatchBody -Headers (New-GraphProxyHeaders -AdminAppRequest '/Settings/enhancedRestore' -TenantId $tenantId) -TimeoutMs 30000)
        )
        Microsoft365Group = @(
            (New-BrowserRequest -Name 'GuestAccess' -Path '/admin/api/settings/security/o365guestuser'),
            (New-BrowserRequest -Name 'GuestUserPolicy' -Path '/admin/api/Settings/security/guestUserPolicy'),
            (New-BrowserRequest -Name 'OwnerlessGroupPolicy' -Path ("/fd/speedwayB2Service/v1.0/organizations('TID:{0}')/policy/ownerlessGroupPolicy" -f $tenantId))
        )
        Microsoft365InstallationOption = @(
            (New-BrowserRequest -Name 'UserSoftware' -Path '/admin/api/settings/apps/usersoftware'),
            (New-BrowserRequest -Name 'TenantInfo' -Path ("/fd/dms/odata/TenantInfo({0})" -f $tenantId)),
            (New-BrowserRequest -Name 'DefaultReleaseRule' -Path ("/fd/dms/odata/C2RReleaseRule?`$filter={0}" -f $defaultReleaseRuleFilter)),
            (New-BrowserRequest -Name 'ReleaseManagement' -Path ("/fd/oacms/api/ReleaseManagement/admin?tenantId={0}" -f $tenantId)),
            (New-BrowserRequest -Name 'MecReleaseInfo' -Path ("/fd/dms/odata/C2RReleaseInfo?`$filter={0}&`$orderby=ReleaseVersion desc&`$top=1" -f $mecReleaseFilter)),
            (New-BrowserRequest -Name 'SacReleaseInfo' -Path ("/fd/dms/odata/C2RReleaseInfo?`$filter={0}&`$orderby=ReleaseVersion desc&`$top=1" -f $sacReleaseFilter)),
            (New-BrowserRequest -Name 'MonthlyReleaseInfo' -Path ("/fd/dms/odata/C2RReleaseInfo?`$filter={0}&`$orderby=ReleaseVersion desc&`$top=1" -f $monthlyReleaseFilter)),
            (New-BrowserRequest -Name 'EligibleToRemoveSac' -Path '/admin/api/tenant/isTenantEligibleToRemoveSAC')
        )
        MicrosoftEdge = @(
            (New-BrowserRequest -Name 'ConfigurationPolicies' -Path '/fd/OfficePolicyAdmin/v1.0/edge/policies'),
            (New-BrowserRequest -Name 'DeviceCount' -Path '/fd/msgraph/v1.0/devices?$count=true&$top=1' -Headers @{ ConsistencyLevel = 'eventual' }),
            (New-BrowserRequest -Name 'FeatureProfiles' -Path '/fd/edgeenterpriseextensionsmanagement/api/featureManagement/profiles'),
            (New-BrowserRequest -Name 'ExtensionPolicies' -Path '/fd/edgeenterpriseextensionsmanagement/api/policies'),
            (New-BrowserRequest -Name 'ExtensionFeedback' -Path '/fd/edgeenterpriseextensionsmanagement/api/extensions/extensionFeedback'),
            (New-BrowserRequest -Name 'SiteLists' -Path '/fd/edgeenterprisesitemanagement/api/v2/emiesitelists'),
            (New-BrowserRequest -Name 'Notifications' -Path '/fd/edgeenterprisesitemanagement/api/v2/notifications')
        )
        PartnerRelationships = @(
            (New-BrowserRequest -Name 'DAP' -Path '/admin/api/partners/AOBOClients?partnerType=DAP'),
            (New-BrowserRequest -Name 'GDAP' -Path '/admin/api/partners/AOBOClients?partnerType=GDAP')
        )
        PeopleSettings = @(
            (New-BrowserRequest -Name 'ProfileCardProperties' -Path ("/fd/peopleadminservice/{0}/profilecard/properties" -f $tenantId)),
            (New-BrowserRequest -Name 'ConnectorProperties' -Path ("/fd/peopleadminservice/{0}/connectorProperties" -f $tenantId)),
            (New-BrowserRequest -Name 'NamePronunciation' -Path ("/fd/peopleadminservice/{0}/settings/namePronunciation" -f $tenantId)),
            (New-BrowserRequest -Name 'Pronouns' -Path ("/fd/peopleadminservice/{0}/settings/pronouns" -f $tenantId))
        )
        Reports = @(
            (New-BrowserRequest -Name 'TenantConfiguration' -Path '/admin/api/reports/config/GetTenantConfiguration'),
            (New-BrowserRequest -Name 'ProductivityScoreConfig' -Path '/admin/api/reports/productivityScoreConfig/GetProductivityScoreConfig'),
            (New-BrowserRequest -Name 'ProductivityScoreCustomerOption' -Path '/admin/api/reports/productivityScoreCustomerOption')
        )
        Search = @(
            (New-BrowserRequest -Name 'UsageAnalytics' -Path '/admin/api/services/apps/searchintelligenceanalytics'),
            (New-BrowserRequest -Name 'SearchIntelligenceHomeCards' -Path '/admin/api/searchadminapi/searchintelligencehome/cards' -Headers $searchHeaders),
            (New-BrowserRequest -Name 'Configurations' -Path '/admin/api/searchadminapi/configurations' -Headers $searchHeaders -TimeoutMs 60000),
            (New-BrowserRequest -Name 'ConfigurationSettings' -Path '/admin/api/searchadminapi/ConfigurationSettings' -Headers $searchHeaders),
            (New-BrowserRequest -Name 'FirstRunExperience' -Path '/admin/api/searchadminapi/firstrunexperience/get' -Method Post -Body @('SearchHomepageBannerFirstTime', 'SearchHomepageBannerReturning', 'SearchHomepageLearningFeedback', 'SearchHomepageAnalyticsFirstTime', 'SearchHomepageAnalyticsReturning') -Headers $searchHeaders),
            (New-BrowserRequest -Name 'ModernResultTypes' -Path '/admin/api/searchadminapi/modernResultTypes' -Headers $searchHeaders),
            (New-BrowserRequest -Name 'NewsOptions' -Path '/admin/api/searchadminapi/news/options/Bing' -Headers $searchHeaders),
            (New-BrowserRequest -Name 'NewsIndustry' -Path '/admin/api/searchadminapi/news/industry/Bing' -Headers $searchHeaders),
            (New-BrowserRequest -Name 'NewsMsbEnabled' -Path '/admin/api/searchadminapi/news/msbenabled/Bing' -Headers $searchHeaders),
            (New-BrowserRequest -Name 'Pivots' -Path '/admin/api/searchadminapi/Pivots' -Headers $searchHeaders),
            (New-BrowserRequest -Name 'Qnas' -Path '/admin/api/searchadminapi/Qnas' -Method Post -Body @{ ServiceType = 'Bing'; Filter = 'Published' } -Headers $searchHeaders),
            (New-BrowserRequest -Name 'UdtConnectorsSummary' -Path '/admin/api/searchadminapi/UDTConnectorsSummary' -Headers $searchHeaders)
        )
        Security = @(
            (New-BrowserRequest -Name 'ActivityBasedTimeout' -Path '/admin/api/settings/security/activitybasedtimeout'),
            (New-BrowserRequest -Name 'SecurityDefaults' -Path '/admin/api/identitysecurity/securitydefaults'),
            (New-BrowserRequest -Name 'BingDataCollection' -Path '/admin/api/settings/security/bingdatacollection'),
            (New-BrowserRequest -Name 'TenantLockbox' -Path '/admin/api/Settings/security/tenantLockbox'),
            (New-BrowserRequest -Name 'DataAccess' -Path '/admin/api/settings/security/dataaccess'),
            (New-BrowserRequest -Name 'GuestUserPolicy' -Path '/admin/api/Settings/security/guestUserPolicy'),
            (New-BrowserRequest -Name 'MultiFactorAuth' -Path '/admin/api/settings/security/multifactorauth'),
            (New-BrowserRequest -Name 'O365GuestUser' -Path '/admin/api/settings/security/o365guestuser'),
            (New-BrowserRequest -Name 'PasswordPolicy' -Path '/admin/api/Settings/security/passwordpolicy'),
            (New-BrowserRequest -Name 'PrivacyPolicy' -Path '/admin/api/Settings/security/privacypolicy'),
            (New-BrowserRequest -Name 'SecuritySettings' -Path '/admin/api/securitysettings/settings'),
            (New-BrowserRequest -Name 'SecuritySettingsStatus' -Path '/admin/api/securitysettings/settings/status'),
            (New-BrowserRequest -Name 'SecuritySettingsOptIn' -Path '/admin/api/securitysettings/optIn'),
            (New-BrowserRequest -Name 'AADLink' -Path '/admin/api/tenant/AADLink')
        )
        SelfServicePurchases = @(
            (New-BrowserRequest -Name 'Products' -Path '/admin/api/selfServicePurchasePolicy/products')
        )
        Services = @(
            (New-BrowserRequest -Name 'AzureSpeechServices' -Path '/admin/api/services/apps/azurespeechservices'),
            (New-BrowserRequest -Name 'Cortana' -Path '/admin/api/services/apps/cortana'),
            (New-BrowserRequest -Name 'DeveloperPortal' -Path '/admin/api/services/apps/developerportal'),
            (New-BrowserRequest -Name 'M365Lighthouse' -Path '/admin/api/services/apps/m365lighthouse'),
            (New-BrowserRequest -Name 'ModernAuth' -Path '/admin/api/services/apps/modernAuth'),
            (New-BrowserRequest -Name 'Planner' -Path '/admin/api/services/apps/planner'),
            (New-BrowserRequest -Name 'Todo' -Path '/admin/api/services/apps/todo'),
            (New-BrowserRequest -Name 'VivaInsights' -Path '/admin/api/services/apps/vivainsights')
        )
        Tenant = @(
            (New-BrowserRequest -Name 'AADLink' -Path '/admin/api/tenant/AADLink'),
            (New-BrowserRequest -Name 'AccountSkus' -Path '/admin/api/tenant/accountSkus'),
            (New-BrowserRequest -Name 'DataLocationAndCommitments' -Path '/admin/api/tenant/datalocationandcommitments'),
            (New-BrowserRequest -Name 'EligibleToRemoveSac' -Path '/admin/api/tenant/isTenantEligibleToRemoveSAC'),
            (New-BrowserRequest -Name 'LocalDataLocation' -Path '/admin/api/tenant/localdatalocation'),
            (New-BrowserRequest -Name 'O365ActivationUserCounts' -Path '/admin/api/tenant/o365activationusercounts'),
            (New-BrowserRequest -Name 'ReportsPrivacyEnabled' -Path '/admin/api/tenant/isReportsPrivacyEnabled')
        )
        UserOwnedApps = @(
            (New-BrowserRequest -Name 'StoreAccess' -Path '/admin/api/settings/apps/store'),
            (New-BrowserRequest -Name 'InAppPurchasesAllowed' -Path '/admin/api/storesettings/iwpurchaseallowed'),
            (New-BrowserRequest -Name 'AutoClaimPolicy' -Path '/fd/m365licensing/v1/policies/autoclaim')
        )
        Viva = @(
            (New-BrowserRequest -Name 'Modules' -Path '/admin/api/viva/modules' -Headers $vivaHeaders),
            (New-BrowserRequest -Name 'Roles' -Path '/admin/api/viva/roles' -Headers $vivaHeaders),
            (New-BrowserRequest -Name 'GlintClient' -Path '/admin/api/viva/glint/lookupClient' -Headers $vivaHeaders)
        )
    }
}

foreach ($subscription in @($azureSubscriptions)) {
    $browserPlan.Requests.Microsoft365Backup += New-BrowserRequest -Name ("AzureSubscriptionPermissions:{0}" -f $subscription.subscriptionId) -Path ("/admin/api/syntexbilling/azureSubscriptions/{0}/permissions" -f $subscription.subscriptionId)
}

$results | ConvertTo-Json -Depth 60 | Set-Content -Path $OutputPath
$browserPlan | ConvertTo-Json -Depth 20 | Set-Content -Path $BrowserPlanPath

[ordered]@{
    OutputPath = $OutputPath
    BrowserPlanPath = $BrowserPlanPath
    TenantId = $tenantId
    BrowserRequestGroups = @($browserPlan.Requests.Keys)
} | ConvertTo-Json -Depth 6