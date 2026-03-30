Describe 'Get-M365AdminAgent' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            switch ($Path) {
                '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings' {
                    [pscustomobject]@{
                        settings = [pscustomobject]@{
                            isTenantEligibleForEntireOrgEmail = $true
                        }
                    }
                }
                '/fd/addins/api/apps/insight?workload=SharedAgent&entraScopes=EntraAgentBlueprintSP,EntraAgentPVA,EntraAgentIdentity' {
                    [pscustomobject]@{
                        data = 'insights'
                    }
                }
                '/admin/api/agentusers/metrics/agents/risky?maxCount=0' {
                    [pscustomobject]@{
                        totalRiskyAgentCount = 2
                    }
                }
                '/fd/addins/api/agents?workloads=SharedAgent&scopes=Shared&limit=200&creatorId=none' {
                    [pscustomobject]@{
                        value = @([pscustomobject]@{ id = 'agent-1' })
                    }
                }
                default {
                    throw "Unexpected path: $Path"
                }
            }
        }
    }

    It 'returns a friendly registry view by default' {
        $result = Get-M365AdminAgent -Name Registry

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.Agent.Registry'
        $result.Settings.settings.isTenantEligibleForEntireOrgEmail | Should -Be $true
        $result.RiskyAgents.totalRiskyAgentCount | Should -Be 2
        $result.Agents.value[0].id | Should -Be 'agent-1'
    }

    It 'returns the underlying registry payload bundle when Raw is used' {
        $result = Get-M365AdminAgent -Name Registry -Raw

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.Agent.Registry.Raw'
        $result.SharedSettings.settings.isTenantEligibleForEntireOrgEmail | Should -Be $true
        $result.RiskyAgents.totalRiskyAgentCount | Should -Be 2
        $result.Agents.value[0].id | Should -Be 'agent-1'
    }

    It 'returns the registry raw payload bundle as JSON when RawJson is used' {
        $result = Get-M365AdminAgent -Name Registry -RawJson

        $result | Should -BeOfType ([string])
        $result | Should -Match '"SharedSettings"'
        $result | Should -Match '"totalRiskyAgentCount"\s*:\s*2'
        $result | Should -Match '"agent-1"'
    }
}