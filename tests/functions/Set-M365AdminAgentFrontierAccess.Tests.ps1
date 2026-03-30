Describe 'Set-M365AdminAgentFrontierAccess' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminAgentFrontierAccess {
            [pscustomobject]@{
                PolicyConfigurationId = 'policy-123'
                FrontierPolicy = 1
                GroupIds = $null
                UserIds = $null
            }
        }

        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod {
            [pscustomobject]@{ Success = $true }
        }

        Mock -ModuleName M365Internals Get-M365PortalTenantId { 'tenant-1234' }
        Mock -ModuleName M365Internals Clear-M365Cache { }
    }

    It 'posts a merged Frontier access payload to the policy endpoint' {
        Set-M365AdminAgentFrontierAccess -Settings @{ FrontierPolicy = 0 } -Confirm:$false | Out-Null

        Assert-MockCalled Get-M365AdminAgentFrontierAccess -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            -not $Force.IsPresent
        }

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/settings/company/frontier/access' -and
            $Method -eq 'Post' -and
            $Body.PolicyConfigurationId -eq 'policy-123' -and
            $Body.FrontierPolicy -eq 0
        }

        Assert-MockCalled Clear-M365Cache -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $TenantId -eq 'tenant-1234'
        }
    }

    It 'returns refreshed data when PassThru is used' {
        $script:getCallCount = 0
        Mock -ModuleName M365Internals Get-M365AdminAgentFrontierAccess {
            $script:getCallCount++
            if ($script:getCallCount -eq 1) {
                [pscustomobject]@{ FrontierPolicy = 1 }
            }
            else {
                [pscustomobject]@{ FrontierPolicy = 0 }
            }
        }

        $result = Set-M365AdminAgentFrontierAccess -Settings @{ FrontierPolicy = 0 } -PassThru -Confirm:$false

        $result.FrontierPolicy | Should -Be 0
        Assert-MockCalled Get-M365AdminAgentFrontierAccess -ModuleName M365Internals -Exactly 2
    }
}