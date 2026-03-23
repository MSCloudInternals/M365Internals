function Get-M365AdminAgent {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Agents area data.

    .DESCRIPTION
        Reads the Agents > All agents route family, including the Registry, Map Frontier,
        Requests, and Catalog views and their shared payloads.

    .PARAMETER Name
        The All agents tab or payload group to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminAgent

        Retrieves the primary All agents payload set.

    .OUTPUTS
        Object
        Returns the selected All agents payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('AgentInsights', 'Agents', 'All', 'Catalog', 'MapFrontier', 'Registry', 'RequestSettings', 'Requests', 'RiskyAgents', 'SharedSettings')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        switch ($Name) {
            'All' {
                return [pscustomobject]@{
                    Registry = Get-M365AdminAgent -Name Registry -Force:$Force
                    MapFrontier = Get-M365AdminAgent -Name MapFrontier -Force:$Force
                    Requests = Get-M365AdminAgent -Name Requests -Force:$Force
                    Catalog = Get-M365AdminAgent -Name Catalog -Force:$Force
                }
            }
            'SharedSettings' {
                return Get-M365AdminPortalData -Path '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings' -CacheKey 'M365AdminAgent:SharedSettings' -Force:$Force
            }
            'RequestSettings' {
                return Get-M365AdminPortalData -Path '/fd/addins/api/v2/settings?keys=MetaOSCopilotExtensibilitySettings,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AdminRoles,AllowOrgWideSharing' -CacheKey 'M365AdminAgent:RequestSettings' -Force:$Force
            }
            'AgentInsights' {
                return Get-M365AdminPortalData -Path '/fd/addins/api/apps/insight?workload=SharedAgent&entraScopes=EntraAgentBlueprintSP,EntraAgentPVA,EntraAgentIdentity' -CacheKey 'M365AdminAgent:AgentInsights' -Force:$Force
            }
            'RiskyAgents' {
                return Get-M365AdminPortalData -Path '/admin/api/agentusers/metrics/agents/risky?maxCount=0' -CacheKey 'M365AdminAgent:RiskyAgents' -Force:$Force
            }
            'Agents' {
                return Get-M365AdminPortalData -Path '/fd/addins/api/agents?workloads=SharedAgent&scopes=Shared&limit=200&creatorId=none' -CacheKey 'M365AdminAgent:Agents' -Force:$Force
            }
            'Registry' {
                return [pscustomobject]@{
                    Settings = Get-M365AdminAgent -Name SharedSettings -Force:$Force
                    AgentInsights = Get-M365AdminAgent -Name AgentInsights -Force:$Force
                    RiskyAgents = Get-M365AdminAgent -Name RiskyAgents -Force:$Force
                    Agents = Get-M365AdminAgent -Name Agents -Force:$Force
                }
            }
            'MapFrontier' {
                return [pscustomobject]@{
                    Settings = Get-M365AdminAgent -Name SharedSettings -Force:$Force
                    AgentInsights = Get-M365AdminAgent -Name AgentInsights -Force:$Force
                    RiskyAgents = Get-M365AdminAgent -Name RiskyAgents -Force:$Force
                }
            }
            'Requests' {
                return [pscustomobject]@{
                    Settings = Get-M365AdminAgent -Name SharedSettings -Force:$Force
                    RequestSettings = Get-M365AdminAgent -Name RequestSettings -Force:$Force
                    AgentInsights = Get-M365AdminAgent -Name AgentInsights -Force:$Force
                    RiskyAgents = Get-M365AdminAgent -Name RiskyAgents -Force:$Force
                }
            }
            'Catalog' {
                return [pscustomobject]@{
                    Settings = Get-M365AdminAgent -Name SharedSettings -Force:$Force
                    AgentInsights = Get-M365AdminAgent -Name AgentInsights -Force:$Force
                    RiskyAgents = Get-M365AdminAgent -Name RiskyAgents -Force:$Force
                    CatalogItems = Get-M365AdminPortalData -Path '/fd/addins/api/actionableApps?workloads=MetaOS%2CSharedAgent&limit=200' -CacheKey 'M365AdminAgent:CatalogItems' -Force:$Force
                }
            }
        }
    }
}