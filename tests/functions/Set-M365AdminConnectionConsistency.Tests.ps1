InModuleScope M365Internals {
    Describe 'Connection consistency during confirmed settings updates' {
        BeforeEach {
            $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $script:m365PortalConnection = [pscustomobject]@{ ConnectionGeneration = [guid]::NewGuid() }
            Mock Get-M365AdminCopilotPinPolicy { [pscustomobject]@{ CopilotPinningPolicy = 1 } }
            Mock Get-M365AdminCopilotConnector {
                if ($Name -eq 'Connections') {
                    return [pscustomobject]@{ connections = @([pscustomobject]@{ connectionId = 'c1'; connectionName = 'Connector' }) }
                }
                return [pscustomobject]@{ LogicalId = 'all'; Payload = '{"Entities":[]}' }
            }
            Mock Invoke-M365AdminRestMethod { [pscustomobject]@{ Success = $true } }
            Mock Clear-M365Cache {}
            Mock Get-M365PortalTenantId { 'synthetic-tenant' }
        }

        AfterEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
        }

        It 'writes once when the connection remains unchanged' {
            Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = 0 } -Confirm:$false | Out-Null
            Should -Invoke Invoke-M365AdminRestMethod -Times 1 -Exactly
        }

        It 'does not write when confirmation is declined' {
            Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = 0 } -WhatIf
            Should -Invoke Invoke-M365AdminRestMethod -Times 0
        }

        It 'stops when the connection changes after pin-policy preflight' {
            Mock Merge-M365AdminSettingsPayload {
                $script:m365PortalConnection.ConnectionGeneration = [guid]::NewGuid()
                return @{ CopilotPinningPolicy = 0 }
            }
            { Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = 0 } -PassThru -Confirm:$false } |
                Should -Throw '*connection changed*new invocation*'
            Should -Invoke Invoke-M365AdminRestMethod -Times 0
            Should -Invoke Get-M365AdminCopilotPinPolicy -Times 1 -Exactly
        }

        It 'stops when the connection changes between connector preflight reads' {
            Mock Get-M365AdminCopilotConnector {
                $script:m365PortalConnection.ConnectionGeneration = [guid]::NewGuid()
                return [pscustomobject]@{ connections = @([pscustomobject]@{ connectionId = 'c1'; connectionName = 'Connector' }) }
            }
            { Set-M365AdminCopilotConnector -ConnectionId c1 -Enabled $false -PassThru -Confirm:$false } |
                Should -Throw '*connection changed*new invocation*'
            Should -Invoke Invoke-M365AdminRestMethod -Times 0
            Should -Invoke Get-M365AdminCopilotConnector -Times 1 -Exactly
        }

        It 'performs one connector write on the unchanged connection' {
            Set-M365AdminCopilotConnector -ConnectionId c1 -Enabled $false -Confirm:$false | Out-Null
            Should -Invoke Invoke-M365AdminRestMethod -Times 1 -Exactly
        }
    }

    Describe 'Portal connection generation' {
        BeforeEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
            $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            foreach ($pair in @(
                @('RootAuthToken', 'root'), @('SPAAuthCookie', 'spa'), @('OIDCAuthCookie', 'oidc'),
                @('s.AjaxSessionKey', 'ajax'), @('s.UserTenantId', '11111111-1111-1111-1111-111111111111'),
                @('x-portal-routekey', 'route'), @('UserLoginRef', '%2Fhomepage')
            )) {
                $session.Cookies.Add([System.Net.Cookie]::new($pair[0], $pair[1], '/', 'admin.cloud.microsoft'))
            }
            Mock Invoke-WebRequest { throw 'Unexpected network request' }
            Mock Invoke-RestMethod { throw 'Unexpected network request' }
            $null = Set-M365PortalConnectionSettings -WebSession $session -AuthFlow WebSession -SkipValidation
        }

        AfterEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
        }

        It 'retains the generation across refresh and changes it on same-session replacement' {
            $generation = Get-M365PortalConnectionGeneration
            Update-M365PortalConnectionSettings
            Get-M365PortalConnectionGeneration | Should -Be $generation
            $null = Set-M365PortalConnectionSettings -WebSession $session -AuthFlow WebSession -SkipValidation
            Get-M365PortalConnectionGeneration | Should -Not -Be $generation
            { Assert-M365PortalConnectionGeneration -Generation $generation } | Should -Throw '*connection changed*'
        }
    }
}
