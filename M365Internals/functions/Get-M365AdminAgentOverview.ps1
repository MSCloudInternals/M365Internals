function Get-M365AdminAgentOverview {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Agents overview data.

    .DESCRIPTION
        Reads the Agents > Overview payloads used for agent inventory, adoption, top-agent,
        risky-agent, and eligibility views.

    .PARAMETER Name
        The overview payload group to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminAgentOverview

        Retrieves the primary Agents overview payload set.

    .OUTPUTS
        Object
        Returns the selected Agents overview payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('ActionableApps', 'AgentInsights', 'Agents', 'All', 'FrontierAccess', 'OfferRecommendations', 'Products', 'RiskyAgents', 'TopAgentsByDailyActiveUsers', 'UsageDailyMetrics', 'UsageMetrics', 'UsageWoWMetrics')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        switch ($Name) {
            'All' {
                return [pscustomobject]@{
                    Products = Get-M365AdminAgentOverview -Name Products -Force:$Force
                    OfferRecommendations = Get-M365AdminAgentOverview -Name OfferRecommendations -Force:$Force
                    UsageMetrics = Get-M365AdminAgentOverview -Name UsageMetrics -Force:$Force
                    UsageWoWMetrics = Get-M365AdminAgentOverview -Name UsageWoWMetrics -Force:$Force
                    UsageDailyMetrics = Get-M365AdminAgentOverview -Name UsageDailyMetrics -Force:$Force
                    TopAgentsByDailyActiveUsers = Get-M365AdminAgentOverview -Name TopAgentsByDailyActiveUsers -Force:$Force
                    Agents = Get-M365AdminAgentOverview -Name Agents -Force:$Force
                    ActionableApps = Get-M365AdminAgentOverview -Name ActionableApps -Force:$Force
                    AgentInsights = Get-M365AdminAgentOverview -Name AgentInsights -Force:$Force
                    FrontierAccess = Get-M365AdminAgentOverview -Name FrontierAccess -Force:$Force
                    RiskyAgents = Get-M365AdminAgentOverview -Name RiskyAgents -Force:$Force
                }
            }
            'Products' {
                return Get-M365AdminPortalData -Path '/admin/api/users/products' -CacheKey 'M365AdminAgentOverview:Products' -Force:$Force
            }
            'OfferRecommendations' {
                return [pscustomobject]@{
                    Offer48 = Get-M365AdminPortalData -Path '/admin/api/offerrec/offer/48' -CacheKey 'M365AdminAgentOverview:Offer48' -Force:$Force
                    Offer49 = Get-M365AdminPortalData -Path '/admin/api/offerrec/offer/49' -CacheKey 'M365AdminAgentOverview:Offer49' -Force:$Force
                }
            }
            'UsageMetrics' {
                return Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityname=getCopilotAgentActiveUserRL30Metrics&pagesize=100' -CacheKey 'M365AdminAgentOverview:UsageMetrics' -Force:$Force
            }
            'UsageWoWMetrics' {
                return Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityname=getCopilotAgentActiveUserRL30WoWMetrics&pagesize=100' -CacheKey 'M365AdminAgentOverview:UsageWoWMetrics' -Force:$Force
            }
            'UsageDailyMetrics' {
                return Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityname=getCopilotAgentActiveUserRL30DailyMetrics&pagesize=100' -CacheKey 'M365AdminAgentOverview:UsageDailyMetrics' -Force:$Force
            }
            'TopAgentsByDailyActiveUsers' {
                return Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityname=getCopilotTenantTopAgentsByDAU&pagesize=100' -CacheKey 'M365AdminAgentOverview:TopAgentsByDailyActiveUsers' -Force:$Force
            }
            'Agents' {
                return Get-M365AdminPortalData -Path '/fd/addins/api/agents?workloads=SharedAgent&scopes=Shared&limit=200&creatorId=none' -CacheKey 'M365AdminAgentOverview:Agents' -Force:$Force
            }
            'ActionableApps' {
                return Get-M365AdminPortalData -Path '/fd/addins/api/actionableApps?workloads=MetaOS%2CSharedAgent&limit=200' -CacheKey 'M365AdminAgentOverview:ActionableApps' -Force:$Force
            }
            'AgentInsights' {
                return Get-M365AdminPortalData -Path '/fd/addins/api/apps/insight?workload=SharedAgent&entraScopes=EntraAgentBlueprintSP,EntraAgentPVA,EntraAgentIdentity' -CacheKey 'M365AdminAgentOverview:AgentInsights' -Force:$Force
            }
            'FrontierAccess' {
                return Get-M365AdminPortalData -Path '/admin/api/settings/company/frontier/access' -CacheKey 'M365AdminAgentOverview:FrontierAccess' -Force:$Force
            }
            'RiskyAgents' {
                return Get-M365AdminPortalData -Path '/admin/api/agentusers/metrics/agents/risky?maxCount=3' -CacheKey 'M365AdminAgentOverview:RiskyAgents' -Force:$Force
            }
        }
    }
}