Describe 'Portal surface registry' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $global:testroot '..')).Path
        . (Join-Path $repoRoot 'build\PortalSurfaceRegistry.ps1')
    }

    It 'loads the canonical registry with the seeded browser plans' {
        $registry = Get-PortalSurfaceRegistry -RepositoryRoot $repoRoot

        $registry.SchemaVersion | Should -Be 2
        @($registry.PlaywrightPlans.Id) | Should -Contain 'settings-browser'
        @($registry.PlaywrightPlans.Id) | Should -Contain 'agent-copilot-browser'
        @($registry.DiscoveryRoutes.Route) | Should -Contain '#/MicrosoftSearch'
        @($registry.InteractiveSurfaces.Id) | Should -Contain 'search-account-linking'
        @($registry.WriteProbePlans.Id) | Should -Contain 'settings-write-probes'
        @($registry.WriteProbePlans.Id) | Should -Contain 'agent-copilot-write-probes'
    }

    It 'passes registry lint validation for the seeded metadata' {
        $issues = Test-PortalSurfaceRegistry -RepositoryRoot $repoRoot

        $issues | Should -BeNullOrEmpty
    }

    It 'generates a settings browser plan with resolved placeholders and expansion values' {
        $tenantId = '11111111-1111-1111-1111-111111111111'
        $subscriptionId = '22222222-2222-2222-2222-222222222222'
        $plan = New-PortalSurfaceBrowserCapturePlan -RepositoryRoot $repoRoot -PlanIds 'settings-browser' -TenantId $tenantId -DefaultHeaders @{ AjaxSessionKey = 'ajax-key' } -ExpansionValues @{
            AzureSubscriptionIds = @($subscriptionId)
        }
        $officeOnline = $plan.Requests.AppSettings | Where-Object Name -eq 'OfficeOnline'
        $brandCenter = $plan.Requests.BrandCenter | Where-Object Name -eq 'Configuration'
        $backupBillingFeature = $plan.Requests.Microsoft365Backup | Where-Object Name -eq 'BillingFeature'
        $backupGraph = $plan.Requests.Microsoft365Backup | Where-Object Name -eq 'EnhancedRestoreStatus'

        $plan.TenantId | Should -Be $tenantId
        $plan.DefaultHeaders.AjaxSessionKey | Should -Be 'ajax-key'
        ($plan.Requests.Microsoft365Backup | Where-Object Name -eq "AzureSubscriptionPermissions:$subscriptionId").Path | Should -Be "/admin/api/syntexbilling/azureSubscriptions/$subscriptionId/permissions"
        ($plan.Requests.Search | Where-Object Name -eq 'Qnas').Headers.'x-adminapp-request' | Should -Be '/MicrosoftSearch'
        $officeOnline.Headers.'x-adminapp-request' | Should -Be '/Settings/Services/:/Settings/L1/OfficeOnline'
        $officeOnline.Headers.'x-ms-mac-appid' | Should -Be '3fda709f-4f6c-4ba7-8da3-b3d031a4d675'
        $brandCenter.Headers.'x-ms-mac-target-app' | Should -Be 'SPO'
        $brandCenter.Headers.'x-ms-mac-appid' | Should -Be '9f8918eb-b2b7-4b90-b5bd-86b38f6d4d23'
        $backupBillingFeature.Headers.'x-adminapp-request' | Should -Be '/Settings/enhancedRestore'
        $backupBillingFeature.Headers.'x-ms-mac-appid' | Should -Be '08a68b73-8058-4c59-8bd5-7b6833e2af21'
        $backupGraph.Headers.'x-ms-mac-target-app' | Should -Be 'Graph'
        $backupGraph.Headers.'x-ms-mac-version' | Should -Be 'host-mac_2026.4.2.8'
    }

    It 'generates an agent and copilot browser plan with resolved Purview headers' {
        $tenantId = '11111111-1111-1111-1111-111111111111'
        $plan = New-PortalSurfaceBrowserCapturePlan -RepositoryRoot $repoRoot -PlanIds 'agent-copilot-browser' -TenantId $tenantId
        $aiBaselineSummary = $plan.Requests.Copilot | Where-Object Name -eq 'AIBaselineSummary'

        $aiBaselineSummary.Headers.tenantid | Should -Be $tenantId
        $aiBaselineSummary.Headers.'x-tid' | Should -Be $tenantId
    }

    It 'produces discovery templates without resolving route placeholders away' {
        $discoveryPlan = New-PortalSurfaceDiscoveryPlan -RepositoryRoot $repoRoot -PlanIds @('settings-browser', 'agent-copilot-browser') -TenantId '11111111-1111-1111-1111-111111111111'
        $knownBackupPermission = $discoveryPlan.KnownRequests | Where-Object Name -eq 'AzureSubscriptionPermissions:{AzureSubscriptionId}'
        $searchRoute = $discoveryPlan.Routes | Where-Object Name -eq 'SearchAndIntelligence'

        $discoveryPlan.TrackedPrefixes | Should -Contain '/fd/'
        @($discoveryPlan.Routes.Route) | Should -Contain '#/agents/all'
        $knownBackupPermission.PathTemplate | Should -Be '/admin/api/syntexbilling/azureSubscriptions/{AzureSubscriptionId}/permissions'
        $searchRoute.Metadata.DisplayName | Should -Be 'Search & intelligence'
        $searchRoute.Metadata.Workload | Should -Be 'Search'
        @($searchRoute.Interactions.Action) | Should -Contain 'ClickText'
    }

    It 'generates write probe plans with resolved placeholders' {
        $tenantId = '11111111-1111-1111-1111-111111111111'
        $plan = New-PortalSurfaceWriteProbePlan -RepositoryRoot $repoRoot -PlanIds @('settings-write-probes', 'agent-copilot-write-probes') -TenantId $tenantId
        $peoplePronouns = $plan.Requests | Where-Object Name -eq 'PeoplePronouns'
        $agentSharedSettings = $plan.Requests | Where-Object Name -eq 'AgentSharedSettings-Patch-SettingsWrapper'

        $peoplePronouns.Path | Should -Be "/fd/peopleadminservice/$tenantId/settings/pronouns"
        $peoplePronouns.Methods | Should -Contain 'Patch'
        $agentSharedSettings.BodySource | Should -Be 'AgentSharedSettingsSettings'
        $agentSharedSettings.BodyWrapperProperty | Should -Be 'settings'
    }

    It 'exports registry-backed mapping overrides for sync' {
        $mappings = Convert-PortalSurfaceRegistryToCmdletApiMappings -RepositoryRoot $repoRoot
        $enhancedRestoreMapping = $mappings | Where-Object Cmdlet -eq 'Get-M365AdminEnhancedRestoreStatus'

        $enhancedRestoreMapping.ApiUri | Should -Be 'https://admin.cloud.microsoft/fd/msgraph/beta/$batch'
        $enhancedRestoreMapping.Method | Should -Be 'POST'
        $enhancedRestoreMapping.MatchBodyIncludes | Should -Contain 'solutions/backupRestore/protectionUnits/microsoft.graph.mailboxProtectionUnit/$count'
    }

    It 'returns tracked request prefixes from the registry' {
        $trackedPrefixes = Get-PortalSurfaceTrackedRequestPrefixes -RepositoryRoot $repoRoot

        $trackedPrefixes | Should -Contain '/admin/api/'
        $trackedPrefixes | Should -Contain '/adminportal/home/'
        $trackedPrefixes | Should -Contain '/fd/'
        $trackedPrefixes | Should -Contain '/_api/'
    }
}
