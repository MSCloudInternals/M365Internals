InModuleScope M365Internals {
    Describe 'Test-M365PortalIdentity' {
        BeforeEach {
            $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $script:m365PortalConnection = [pscustomobject]@{ TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
            $script:identityFixturePrincipal = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            $script:identityFixtureShellPrincipal = $script:identityFixturePrincipal
            $script:identityFixtureShellTenant = $script:m365PortalConnection.TenantId
            $script:identityFixtureShellUpn = 'fixture@example.test'
            Mock Invoke-M365PortalRequest {
                [pscustomobject]@{ UserInfo = [pscustomobject]@{ ObjectId = $script:identityFixturePrincipal; UserPrincipalName = 'fixture@example.test' } }
            } -ParameterFilter { $Path -eq '/admin/api/users/currentUser' }
            Mock Invoke-M365PortalRequest {
                $client = @{ UID = $script:identityFixtureShellPrincipal; TID = $script:identityFixtureShellTenant; UPN = $script:identityFixtureShellUpn } | ConvertTo-Json -Compress
                [pscustomobject]@{ shellInfo = [pscustomobject]@{ navBarJson = (@{ ClientData = $client } | ConvertTo-Json -Compress) } }
            } -ParameterFilter { $Path -eq '/admin/api/coordinatedbootstrap/shellinfo' }
        }

        AfterEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
        }

        It 'reports independent verdicts for <Scenario>' -ForEach @(
            @{ Scenario = 'matching evidence'; ExpectedAccount = 'Verified'; ExpectedTenant = 'Verified' }
            @{ Scenario = 'a different principal'; OtherAccount = $true; ExpectedAccount = 'Mismatch'; ExpectedTenant = 'Verified' }
            @{ Scenario = 'a conflicting UPN'; OtherUpn = $true; ExpectedAccount = 'Mismatch'; ExpectedTenant = 'Verified' }
            @{ Scenario = 'a different tenant'; OtherTenant = $true; ExpectedAccount = 'Verified'; ExpectedTenant = 'Mismatch' }
            @{ Scenario = 'a missing portal principal'; MissingAccount = $true; ExpectedAccount = 'Unknown'; ExpectedTenant = 'Verified' }
        ) {
            if ($OtherAccount) { $script:identityFixtureShellPrincipal = [guid]::NewGuid().ToString() }
            if ($OtherTenant) { $script:identityFixtureShellTenant = [guid]::NewGuid().ToString() }
            if ($OtherUpn) { $script:identityFixtureShellUpn = 'other@example.test' }
            if ($MissingAccount) { $script:identityFixturePrincipal = $null }

            $status = Test-M365PortalIdentity
            $status.Connected | Should -BeTrue
            $status.AccountVerification | Should -BeExactly $ExpectedAccount
            $status.ResourceTenantVerification | Should -BeExactly $ExpectedTenant
            ($status | ConvertTo-Json -Compress) | Should -Not -Match 'example.test|aaaaaa|bbbbbb'
            Should -Invoke Invoke-M365PortalRequest -Times 2 -Exactly -ParameterFilter {
                $SkipConnectionRefresh -and $SkipAutoHeal -and [object]::ReferenceEquals($WebSession, $script:m365PortalSession)
            }
        }

        It 'discards evidence when the active session changes during the shell probe' {
            Mock Invoke-M365PortalRequest {
                $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
                [pscustomobject]@{ shellInfo = [pscustomobject]@{ navBarJson = '{}' } }
            } -ParameterFilter { $Path -eq '/admin/api/coordinatedbootstrap/shellinfo' }

            { Test-M365PortalIdentity } | Should -Throw '*connection changed during identity verification*'
        }

        It 'leaves both verdicts unknown when the shell returns malformed client data' {
            Mock Invoke-M365PortalRequest {
                [pscustomobject]@{ shellInfo = [pscustomobject]@{ navBarJson = '{"ClientData":"not JSON"}' } }
            } -ParameterFilter { $Path -eq '/admin/api/coordinatedbootstrap/shellinfo' }

            $status = Test-M365PortalIdentity
            $status.AccountVerification | Should -BeExactly 'Unknown'
            $status.ResourceTenantVerification | Should -BeExactly 'Unknown'
        }
    }
}
