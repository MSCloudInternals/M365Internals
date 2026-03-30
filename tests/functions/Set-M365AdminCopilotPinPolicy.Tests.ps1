Describe 'Set-M365AdminCopilotPinPolicy' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminCopilotPinPolicy {
            [pscustomobject]@{
                PolicyConfigurationId = 'policy-123'
                CopilotPinningPolicy = 1
                IsEligibleForNewPinDefault = $true
                PinCopilotViewType = 1
                PinningStateForCopilotApp = $null
                IsPinCategoryEnabled = $true
                ManageInOCPS = $null
            }
        }

        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod {
            [pscustomobject]@{ Success = $true }
        }

        Mock -ModuleName M365Internals Get-M365PortalTenantId { 'tenant-1234' }
        Mock -ModuleName M365Internals Clear-M365Cache { }
    }

    It 'posts a merged Copilot pin policy payload to the policy endpoint' {
        Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = 0 } -Confirm:$false | Out-Null

        Assert-MockCalled Get-M365AdminCopilotPinPolicy -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            -not $Force.IsPresent
        }

        Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/settings/company/copilotpolicy/pin' -and
            $Method -eq 'Post' -and
            $Body.PolicyConfigurationId -eq 'policy-123' -and
            $Body.CopilotPinningPolicy -eq 0 -and
            $Body.PinCopilotViewType -eq 1
        }

        Assert-MockCalled Clear-M365Cache -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $TenantId -eq 'tenant-1234'
        }
    }

    It 'returns refreshed data when PassThru is used' {
        $script:getCallCount = 0
        Mock -ModuleName M365Internals Get-M365AdminCopilotPinPolicy {
            $script:getCallCount++
            if ($script:getCallCount -eq 1) {
                [pscustomobject]@{ CopilotPinningPolicy = 1 }
            }
            else {
                [pscustomobject]@{ CopilotPinningPolicy = 0 }
            }
        }

        $result = Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = 0 } -PassThru -Confirm:$false

        $result.CopilotPinningPolicy | Should -Be 0
        Assert-MockCalled Get-M365AdminCopilotPinPolicy -ModuleName M365Internals -Exactly 2
    }
}