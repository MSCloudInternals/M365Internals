Describe 'Get-M365AdminCopilotPinPolicy' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            [pscustomobject]@{
                PolicyConfigurationId = 'policy-123'
                CopilotPinningPolicy = 1
                PinCopilotViewType = 1
            }
        }
    }

    It 'retrieves and types the Copilot pin policy payload' {
        $result = Get-M365AdminCopilotPinPolicy

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.CopilotPinPolicy'
        $result.CopilotPinningPolicy | Should -Be 1

        Assert-MockCalled Get-M365AdminPortalData -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/settings/company/copilotpolicy/pin' -and
            $CacheKey -eq 'M365AdminCopilotPinPolicy:Current'
        }
    }
}