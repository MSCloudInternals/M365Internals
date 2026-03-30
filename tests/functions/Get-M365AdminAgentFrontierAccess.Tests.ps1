Describe 'Get-M365AdminAgentFrontierAccess' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            [pscustomobject]@{
                PolicyConfigurationId = 'policy-123'
                FrontierPolicy = 1
                GroupIds = $null
                UserIds = $null
            }
        }
    }

    It 'retrieves and types the Frontier access payload' {
        $result = Get-M365AdminAgentFrontierAccess

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.AgentFrontierAccess'
        $result.FrontierPolicy | Should -Be 1

        Assert-MockCalled Get-M365AdminPortalData -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/settings/company/frontier/access' -and
            $CacheKey -eq 'M365AdminAgentFrontierAccess:Current'
        }
    }
}