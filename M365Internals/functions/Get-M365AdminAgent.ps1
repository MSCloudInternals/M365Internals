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

    .PARAMETER Raw
        Returns the underlying leaf payload bundle for the selected Agents view.

    .PARAMETER RawJson
        Returns the raw leaf payload bundle serialized as formatted JSON.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        function Get-AgentRawPayload {
            param (
                [Parameter(Mandatory)]
                [ValidateSet('All', 'Catalog', 'MapFrontier', 'Registry', 'Requests')]
                [string]$ViewName
            )

            switch ($ViewName) {
                'All' {
                    $result = [pscustomobject]@{
                        SharedSettings = Get-M365AdminAgent -Name SharedSettings -Force:$Force
                        RequestSettings = Get-M365AdminAgent -Name RequestSettings -Force:$Force
                        AgentInsights = Get-M365AdminAgent -Name AgentInsights -Force:$Force
                        RiskyAgents = Get-M365AdminAgent -Name RiskyAgents -Force:$Force
                        Agents = Get-M365AdminAgent -Name Agents -Force:$Force
                        CatalogItems = Get-M365AdminPortalData -Path '/fd/addins/api/actionableApps?workloads=MetaOS%2CSharedAgent&limit=200' -CacheKey 'M365AdminAgent:CatalogItems' -Force:$Force
                    }
                }
                'Registry' {
                    $result = [pscustomobject]@{
                        SharedSettings = Get-M365AdminAgent -Name SharedSettings -Force:$Force
                        AgentInsights = Get-M365AdminAgent -Name AgentInsights -Force:$Force
                        RiskyAgents = Get-M365AdminAgent -Name RiskyAgents -Force:$Force
                        Agents = Get-M365AdminAgent -Name Agents -Force:$Force
                    }
                }
                'MapFrontier' {
                    $result = [pscustomobject]@{
                        SharedSettings = Get-M365AdminAgent -Name SharedSettings -Force:$Force
                        AgentInsights = Get-M365AdminAgent -Name AgentInsights -Force:$Force
                        RiskyAgents = Get-M365AdminAgent -Name RiskyAgents -Force:$Force
                    }
                }
                'Requests' {
                    $result = [pscustomobject]@{
                        SharedSettings = Get-M365AdminAgent -Name SharedSettings -Force:$Force
                        RequestSettings = Get-M365AdminAgent -Name RequestSettings -Force:$Force
                        AgentInsights = Get-M365AdminAgent -Name AgentInsights -Force:$Force
                        RiskyAgents = Get-M365AdminAgent -Name RiskyAgents -Force:$Force
                    }
                }
                'Catalog' {
                    $result = [pscustomobject]@{
                        SharedSettings = Get-M365AdminAgent -Name SharedSettings -Force:$Force
                        AgentInsights = Get-M365AdminAgent -Name AgentInsights -Force:$Force
                        RiskyAgents = Get-M365AdminAgent -Name RiskyAgents -Force:$Force
                        CatalogItems = Get-M365AdminPortalData -Path '/fd/addins/api/actionableApps?workloads=MetaOS%2CSharedAgent&limit=200' -CacheKey 'M365AdminAgent:CatalogItems' -Force:$Force
                    }
                }
            }

            return Add-M365TypeName -InputObject $result -TypeName "M365Admin.Agent.$ViewName.Raw"
        }

        switch ($Name) {
            'All' {
                if ($Raw -or $RawJson) {
                    return Resolve-M365AdminOutput -RawValue (Get-AgentRawPayload -ViewName All) -Raw:$Raw -RawJson:$RawJson
                }

                $result = [pscustomobject]@{
                    Registry    = Get-M365AdminAgent -Name Registry -Force:$Force
                    MapFrontier = Get-M365AdminAgent -Name MapFrontier -Force:$Force
                    Requests    = Get-M365AdminAgent -Name Requests -Force:$Force
                    Catalog     = Get-M365AdminAgent -Name Catalog -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.Agent'
            }
            'SharedSettings' {
                $result = Get-M365AdminPortalData -Path '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings' -CacheKey 'M365AdminAgent:SharedSettings' -Force:$Force
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'RequestSettings' {
                $result = Get-M365AdminPortalData -Path '/fd/addins/api/v2/settings?keys=MetaOSCopilotExtensibilitySettings,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AdminRoles,AllowOrgWideSharing' -CacheKey 'M365AdminAgent:RequestSettings' -Force:$Force
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'AgentInsights' {
                $result = Get-M365AdminPortalData -Path '/fd/addins/api/apps/insight?workload=SharedAgent&entraScopes=EntraAgentBlueprintSP,EntraAgentPVA,EntraAgentIdentity' -CacheKey 'M365AdminAgent:AgentInsights' -Force:$Force
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'RiskyAgents' {
                $result = Get-M365AdminPortalData -Path '/admin/api/agentusers/metrics/agents/risky?maxCount=0' -CacheKey 'M365AdminAgent:RiskyAgents' -Force:$Force
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'Agents' {
                $result = Get-M365AdminPortalData -Path '/fd/addins/api/agents?workloads=SharedAgent&scopes=Shared&limit=200&creatorId=none' -CacheKey 'M365AdminAgent:Agents' -Force:$Force
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'Registry' {
                $rawResult = Get-AgentRawPayload -ViewName Registry
                $result = [pscustomobject]@{
                    Settings      = $rawResult.SharedSettings
                    AgentInsights = $rawResult.AgentInsights
                    RiskyAgents   = $rawResult.RiskyAgents
                    Agents        = $rawResult.Agents
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.Agent.Registry'
                return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
            }
            'MapFrontier' {
                $rawResult = Get-AgentRawPayload -ViewName MapFrontier
                $result = [pscustomobject]@{
                    Settings      = $rawResult.SharedSettings
                    AgentInsights = $rawResult.AgentInsights
                    RiskyAgents   = $rawResult.RiskyAgents
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.Agent.MapFrontier'
                return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
            }
            'Requests' {
                $rawResult = Get-AgentRawPayload -ViewName Requests
                $result = [pscustomobject]@{
                    Settings        = $rawResult.SharedSettings
                    RequestSettings = $rawResult.RequestSettings
                    AgentInsights   = $rawResult.AgentInsights
                    RiskyAgents     = $rawResult.RiskyAgents
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.Agent.Requests'
                return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
            }
            'Catalog' {
                $rawResult = Get-AgentRawPayload -ViewName Catalog
                $result = [pscustomobject]@{
                    Settings      = $rawResult.SharedSettings
                    AgentInsights = $rawResult.AgentInsights
                    RiskyAgents   = $rawResult.RiskyAgents
                    CatalogItems  = $rawResult.CatalogItems
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.Agent.Catalog'
                return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
            }
        }
    }
}