Describe 'Get-M365AdminAgentSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            switch ($Path) {
                '/admin/api/agenttemplates/getagenttemplates' {
                    throw 'Response status code does not indicate success: 400 (Bad Request).'
                }
                '/admin/api/agenttemplates/getpolicies?expand=true' {
                    [pscustomobject]@{ value = @() }
                }
                '/admin/api/tenant/billingAccountsWithShell' {
                    @()
                }
                '/_api/SPOInternalUseOnly.TenantAdminSettings/AutoQuotaEnabled' {
                    $false
                }
                '/admin/api/tenant/customviewfilterdefaults' {
                    [pscustomobject]@{}
                }
                default {
                    throw "Unexpected path: $Path"
                }
            }
        }

        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod { @() }
    }

    It 'wraps template endpoint failures with licensing or provisioning guidance' {
        $result = Get-M365AdminAgentSetting -Name Templates

        $result.Templates.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
        $result.Templates.Name | Should -Be 'Templates'
        $result.Templates.Reason | Should -Be 'ProvisioningOrLicensing'
        $result.Templates.HttpStatusCode | Should -Be 400
        $result.Templates.SuggestedAction | Should -Match 'license|provision'
    }
}