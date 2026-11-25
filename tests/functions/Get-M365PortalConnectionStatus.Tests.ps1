InModuleScope M365Internals {
    Describe 'Get-M365PortalConnectionStatus' {
        BeforeEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
            Mock Clear-M365Cache {}
            Mock Invoke-M365BrowserAuthentication {
                [pscustomobject]@{
                    PortalWebSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
                    RetainedBrowserProfile = -not $PrivateSession
                    ProfilePath = $TestDrive
                }
            }
            Mock Invoke-M365SsoAuthentication {
                [pscustomobject]@{
                    PortalWebSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
                    RetainedBrowserProfile = -not $PrivateSession
                    ProfilePath = $TestDrive
                }
            }
            Mock Invoke-WebRequest { throw 'Unexpected network request' }
            Mock Invoke-RestMethod { throw 'Unexpected network request' }
            Mock Connect-M365AuthArtifactSet {
                $script:m365PortalSession = $PortalWebSession
                $script:m365PortalConnection = [pscustomobject]@{ AuthFlow = $AuthFlow }
                return $script:m365PortalConnection
            }
        }

        AfterEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
        }

        It 'reports only local flags when disconnected' {
            $status = Get-M365PortalConnectionStatus
            $status.ConnectionPresent | Should -BeFalse
            $status.RetainedBrowserProfile | Should -BeFalse
            @($status.PSObject.Properties.Name) | Should -HaveCount 2
        }

        It 'reports an existing persistent browser profile without revealing its path' {
            Connect-M365Portal -BrowserSignIn -SkipValidation | Out-Null
            $status = Get-M365PortalConnectionStatus
            $status.ConnectionPresent | Should -BeTrue
            $status.RetainedBrowserProfile | Should -BeTrue
            @($status.PSObject.Properties.Name) | Should -HaveCount 2
        }

        It 'does not report a private browser profile as retained' {
            Connect-M365Portal -BrowserSignIn -PrivateSession -SkipValidation | Out-Null
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeFalse
        }

        It 'reports SSO profile retention for persistent and private sessions' {
            Connect-M365Portal -SSO -SkipValidation | Out-Null
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeTrue
            Connect-M365Portal -SSO -PrivateSession -SkipValidation | Out-Null
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeFalse
        }

        It 'does not report a deleted profile as available' {
            Connect-M365Portal -BrowserSignIn -SkipValidation | Out-Null
            $script:m365PortalSession.M365BrowserProfilePath = Join-Path $TestDrive 'missing'
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeFalse
        }

        It 'does not change status when browser authentication fails' {
            $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $script:m365PortalConnection = [pscustomobject]@{ RetainedBrowserProfile = $false }
            Mock Invoke-M365BrowserAuthentication { throw 'Synthetic authentication failure' }
            { Connect-M365Portal -BrowserSignIn -SkipValidation } | Should -Throw '*Synthetic authentication failure*'
            $status = Get-M365PortalConnectionStatus
            $status.ConnectionPresent | Should -BeTrue
            $status.RetainedBrowserProfile | Should -BeFalse
        }

        It 'does not make a network request to obtain local status' {
            Connect-M365Portal -BrowserSignIn -SkipValidation | Out-Null
            $null = Get-M365PortalConnectionStatus
            Should -Invoke Invoke-WebRequest -Times 0
            Should -Invoke Invoke-RestMethod -Times 0
        }
    }

    Describe 'Connection status across session refresh and replacement' {
        BeforeEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
            Mock Invoke-WebRequest { throw 'Unexpected network request' }
            Mock Invoke-RestMethod { throw 'Unexpected network request' }
            $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            foreach ($pair in @(
                @('RootAuthToken', 'root'), @('SPAAuthCookie', 'spa'), @('OIDCAuthCookie', 'oidc'),
                @('s.AjaxSessionKey', 'ajax'), @('s.UserTenantId', '11111111-1111-1111-1111-111111111111'),
                @('x-portal-routekey', 'route'), @('UserLoginRef', '%2Fhomepage')
            )) {
                $session.Cookies.Add([System.Net.Cookie]::new($pair[0], $pair[1], '/', 'admin.cloud.microsoft'))
            }
            $null = Set-M365PortalConnectionSettings -WebSession $session -AuthFlow BrowserSignIn -SkipValidation
            $script:m365PortalConnection.RetainedBrowserProfile = $true
            $session | Add-Member -NotePropertyName M365BrowserProfilePath -NotePropertyValue $TestDrive -Force
        }

        AfterEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
        }

        It 'preserves retained status during an ordinary refresh' {
            Update-M365PortalConnectionSettings
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeTrue
        }

        It 'clears retained status for a non-browser replacement using the same web session' {
            $null = Set-M365PortalConnectionSettings -WebSession $session -AuthFlow WebSession -SkipValidation
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeFalse
        }
    }
}
