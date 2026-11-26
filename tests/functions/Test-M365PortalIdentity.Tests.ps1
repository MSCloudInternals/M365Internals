InModuleScope M365Internals {
    Describe 'Test-M365PortalIdentity' {
        BeforeEach {
            $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $script:m365PortalConnection = [pscustomobject]@{ TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
            $script:identityFixturePrincipal = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            $script:identityFixtureGraphPrincipal = $script:identityFixturePrincipal
            $script:identityFixtureGraphTenant = $script:m365PortalConnection.TenantId
            Mock Invoke-M365PortalRequest {
                [pscustomobject]@{ UserInfo = [pscustomobject]@{ ObjectId = $script:identityFixturePrincipal } }
            } -ParameterFilter { $Path -eq '/admin/api/users/currentUser' }
            Mock Invoke-M365PortalRequest {
                'synthetic.graph.token'
            } -ParameterFilter { $Path -eq '/admin/api/users/getuseraccesstoken?tokenType=GraphAT&scenario=main' }
            Mock Invoke-RestMethod {
                [pscustomobject]@{ id = $script:identityFixtureGraphPrincipal }
            } -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/v1.0/me?$select=id' }
            Mock Invoke-RestMethod {
                [pscustomobject]@{ value = @([pscustomobject]@{ id = $script:identityFixtureGraphTenant }) }
            } -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/v1.0/organization?$select=id' }
        }

        AfterEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
        }

        It 'reports independent verdicts for <Scenario>' -ForEach @(
            @{ Scenario = 'matching evidence'; ExpectedAccount = 'Verified'; ExpectedTenant = 'Verified' }
            @{ Scenario = 'a different principal'; OtherAccount = $true; ExpectedAccount = 'Mismatch'; ExpectedTenant = 'Verified' }
            @{ Scenario = 'a different organization'; OtherTenant = $true; ExpectedAccount = 'Verified'; ExpectedTenant = 'Mismatch' }
            @{ Scenario = 'a missing portal principal'; MissingAccount = $true; ExpectedAccount = 'Unknown'; ExpectedTenant = 'Verified' }
        ) {
            if ($OtherAccount) { $script:identityFixtureGraphPrincipal = [guid]::NewGuid().ToString() }
            if ($OtherTenant) { $script:identityFixtureGraphTenant = [guid]::NewGuid().ToString() }
            if ($MissingAccount) { $script:identityFixturePrincipal = $null }

            $status = Test-M365PortalIdentity
            $status.Connected | Should -BeTrue
            $status.AccountVerification | Should -BeExactly $ExpectedAccount
            $status.ResourceTenantVerification | Should -BeExactly $ExpectedTenant
            ($status | ConvertTo-Json -Compress) | Should -Not -Match 'synthetic|aaaaaa|bbbbbb'
            Should -Invoke Invoke-M365PortalRequest -Times 2 -Exactly -ParameterFilter {
                $SkipConnectionRefresh -and $SkipAutoHeal -and [object]::ReferenceEquals($WebSession, $script:m365PortalSession)
            }
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -like '*/organization?*' -and $Authentication -eq 'Bearer' -and $Token -is [securestring] -and $MaximumRedirection -eq 0
            }
        }

        It 'stops when the active session changes during a probe' {
            Mock Invoke-RestMethod {
                $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
                [pscustomobject]@{ id = $script:identityFixtureGraphPrincipal }
            } -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/v1.0/me?$select=id' }

            { Test-M365PortalIdentity } | Should -Throw '*connection changed during identity verification*'
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Uri -like '*/organization?*' }
        }

        It 'leaves both verdicts unknown when the broker returns an error string' {
            Mock Invoke-M365PortalRequest { 'Broker request failed.' } -ParameterFilter { $Path -like '*/getuseraccesstoken?*' }

            $status = Test-M365PortalIdentity
            $status.AccountVerification | Should -BeExactly 'Unknown'
            $status.ResourceTenantVerification | Should -BeExactly 'Unknown'
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }
    }
}
