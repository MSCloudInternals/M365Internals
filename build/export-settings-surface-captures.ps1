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

. (Join-Path $PSScriptRoot 'PortalSurfaceRegistry.ps1')

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

$browserPlan = New-PortalSurfaceBrowserCapturePlan -RepositoryRoot (Join-Path $PSScriptRoot '..') -PlanIds 'settings-browser' -TenantId $tenantId -DefaultHeaders $defaultBrowserHeaders -ExpansionValues @{
    AzureSubscriptionIds = @($azureSubscriptions.subscriptionId)
}

$results | ConvertTo-Json -Depth 60 | Set-Content -Path $OutputPath
$browserPlan | ConvertTo-Json -Depth 20 | Set-Content -Path $BrowserPlanPath

[ordered]@{
    OutputPath = $OutputPath
    BrowserPlanPath = $BrowserPlanPath
    TenantId = $tenantId
    BrowserRequestGroups = @($browserPlan.Requests.Keys)
} | ConvertTo-Json -Depth 6
