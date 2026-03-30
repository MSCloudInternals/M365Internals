Describe 'Get-M365AdminAgentOverview' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            switch ($Path) {
                '/fd/addins/api/apps/insight?workload=SharedAgent&entraScopes=EntraAgentBlueprintSP,EntraAgentPVA,EntraAgentIdentity' {
                    [pscustomobject]@{
                        data = [pscustomobject]@{
                            titlesInsight = [pscustomobject]@{
                                Counts = [pscustomobject]@{
                                    AgentAggregatedMetricsResponse = [pscustomobject]@{
                                        summary = [pscustomobject]@{
                                            totalAgents = 5
                                            totalAgentsLastWeek = 4
                                            blockedAgents = 1
                                            totalRiskyAgentCount = 2
                                        }
                                        countsByAppType = @([pscustomobject]@{ Name = 'Custom' })
                                        countsByBuilder = @([pscustomobject]@{ Name = 'Microsoft' })
                                    }
                                    OrphanedAgents = 3
                                }
                            }
                        }
                    }
                }
                '/admin/api/agentusers/metrics/agents/risky?maxCount=3' {
                    [pscustomobject]@{
                        totalRiskyAgentCount = 7
                        riskyAgentsDetails = @([pscustomobject]@{ id = 'risky-agent-1' })
                    }
                }
                default {
                    throw "Unexpected path: $Path"
                }
            }
        }
    }

    It 'returns a derived admin-friendly summary by default' {
        $result = Get-M365AdminAgentOverview -Name Summary

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.AgentOverview.Summary'
        $result.TotalAgents | Should -Be 5
        $result.TotalAgentsLastWeek | Should -Be 4
        $result.BlockedAgents | Should -Be 1
        $result.TotalRiskyAgentCount | Should -Be 7
        $result.OrphanedAgents | Should -Be 3
        $result.RiskyAgentsDetails[0].id | Should -Be 'risky-agent-1'
    }

    It 'returns the underlying summary inputs when Raw is used' {
        $result = Get-M365AdminAgentOverview -Name Summary -Raw

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.AgentOverview.Summary.Raw'
        $result.AgentInsights.data.titlesInsight.Counts.OrphanedAgents | Should -Be 3
        $result.RiskyAgents.totalRiskyAgentCount | Should -Be 7
    }

    It 'returns the summary raw payload bundle as JSON when RawJson is used' {
        $result = Get-M365AdminAgentOverview -Name Summary -RawJson

        $result | Should -BeOfType ([string])
        $result | Should -Match '"AgentInsights"'
        $result | Should -Match '"RiskyAgents"'
        $result | Should -Match '"totalRiskyAgentCount"\s*:\s*7'
    }
}