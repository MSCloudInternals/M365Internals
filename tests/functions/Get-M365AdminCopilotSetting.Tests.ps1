Describe 'Get-M365AdminCopilotSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365PortalTenantId { 'tenant-1234' }
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            throw 'Response status code does not indicate success: 404 (Not Found).'
        } -ParameterFilter { $Path -eq '/admin/api/copilotsettings/securitycopilot/auth' }
    }

    It 'wraps tenant-scoped setting failures with licensing or provisioning guidance' {
        $result = Get-M365AdminCopilotSetting -Name SecurityCopilotAuth

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
        $result.Name | Should -Be 'SecurityCopilotAuth'
        $result.Reason | Should -Be 'ProvisioningOrLicensing'
        $result.HttpStatusCode | Should -Be 404
        $result.SuggestedAction | Should -Match 'license|provision'
    }
}