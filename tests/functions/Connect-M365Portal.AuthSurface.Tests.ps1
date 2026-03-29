Describe 'Connect-M365Portal auth surface' {
    It 'uses BrowserSignIn as the default parameter set' {
        $command = Get-Command Connect-M365Portal

        $command.DefaultParameterSet | Should -Be 'BrowserSignIn'
        ($command.ParameterSets | Where-Object Name -EQ 'BrowserSignIn').IsDefault | Should -BeTrue
    }

    It 'keeps UserId as an alias of Username for portal-cookie reuse' {
        $command = Get-Command Connect-M365Portal
        $usernameParameter = $command.Parameters['Username']
        $portalCookieParameterSet = $command.ParameterSets | Where-Object Name -EQ 'PortalCookies'

        $usernameParameter.Aliases | Should -Contain 'UserId'
        $portalCookieParameterSet.Parameters.Name | Should -Contain 'Username'
    }

    It 'accepts TenantId with the ESTS cookie parameter sets' {
        $command = Get-Command Connect-M365Portal
        $plainTextParameterSet = $command.ParameterSets | Where-Object Name -EQ 'EstsPlainText'
        $secureStringParameterSet = $command.ParameterSets | Where-Object Name -EQ 'EstsSecureString'

        $plainTextParameterSet.Parameters.Name | Should -Contain 'TenantId'
        $secureStringParameterSet.Parameters.Name | Should -Contain 'TenantId'
    }

    It 'exports the public auth wrapper cmdlets' {
        $wrapperCommands = @(
            'Connect-M365PortalByBrowser'
            'Connect-M365PortalByCredential'
            'Connect-M365PortalByEstsCookie'
            'Connect-M365PortalByPhoneSignIn'
            'Connect-M365PortalBySoftwarePasskey'
            'Connect-M365PortalBySSO'
            'Connect-M365PortalByTemporaryAccessPass'
        )

        foreach ($wrapperCommand in $wrapperCommands) {
            (Get-Command $wrapperCommand -ErrorAction Stop).Name | Should -Be $wrapperCommand
        }
    }

    It 'exposes the expected key parameters on the public auth wrappers' {
        (Get-Command Connect-M365PortalByBrowser).Parameters.Keys | Should -Contain 'PrivateSession'
        (Get-Command Connect-M365PortalByCredential).Parameters.Keys | Should -Contain 'MfaMethod'
        (Get-Command Connect-M365PortalByEstsCookie).Parameters.Keys | Should -Contain 'SecureEstsAuthCookieValue'
        (Get-Command Connect-M365PortalByPhoneSignIn).Parameters.Keys | Should -Contain 'TimeoutSeconds'
        (Get-Command Connect-M365PortalBySoftwarePasskey).Parameters.Keys | Should -Contain 'KeyFilePath'
        (Get-Command Connect-M365PortalBySSO).Parameters.Keys | Should -Contain 'Visible'
        (Get-Command Connect-M365PortalByTemporaryAccessPass).Parameters.Keys | Should -Contain 'TemporaryAccessPass'
        (Get-Command Connect-M365PortalByTemporaryAccessPass).Parameters['TemporaryAccessPass'].Aliases | Should -Contain 'TAP'
    }
}

InModuleScope M365Internals {
    Describe 'Complete-M365AdminPortalSignIn' {
        BeforeEach {
            Mock Invoke-WebRequest {
                param(
                    $Uri,
                    $Method,
                    $Body,
                    $WebSession,
                    $UserAgent
                )

                switch ("$Method $Uri") {
                    'Get https://admin.cloud.microsoft/login?ru=%2Fadminportal%3F' {
                        return [pscustomobject]@{
                            Headers      = @{ Location = '/common/oauth2/authorize?client_id=test-client' }
                            Content      = ''
                            BaseResponse = [pscustomobject]@{}
                        }
                    }
                    'Get https://login.microsoftonline.com/common/oauth2/authorize?client_id=test-client' {
                        return [pscustomobject]@{
                            Content      = @'
<html>
<body>
<script>
$Config = {"pgid":"ConvergedSignIn","arrSessions":[{"id":"session-123"}],"urlLogin":"/common/login?foo=bar","sessionId":"fallback-session","sErrorCode":"50058","sTenantId":"common"}
</script>
</body>
</html>
'@
                            BaseResponse = [pscustomobject]@{
                                ResponseUri = [uri]'https://login.microsoftonline.com/common/oauth2/authorize?client_id=test-client'
                            }
                        }
                    }
                    'Get https://login.microsoftonline.com/common/login?foo=bar&sessionid=session-123' {
                        return [pscustomobject]@{
                            Content      = @"
<html>
<body>
<form action="https://admin.cloud.microsoft/landing">
    <input type="hidden" name="code" value="abc" />
    <input type="hidden" name="id_token" value="def" />
    <input type="hidden" name="state" value="ghi" />
    <input type="hidden" name="session_state" value="jkl" />
</form>
</body>
</html>
"@
                            BaseResponse = [pscustomobject]@{
                                ResponseUri = [uri]'https://login.microsoftonline.com/common/login?foo=bar&sessionid=session-123'
                            }
                        }
                    }
                    'Post https://admin.cloud.microsoft/landing' {
                        return [pscustomobject]@{
                            Content = 'ok'
                        }
                    }
                    default {
                        throw "Unexpected request: $Method $Uri"
                    }
                }
            }

            Mock Invoke-M365PortalPostLandingBootstrap {
                param(
                    $WebSession,
                    $UserAgent
                )

                return [pscustomobject]@{
                    Completed = $true
                }
            }
        }

        It 'follows the ConvergedSignIn session handoff and completes the admin landing post' {
            $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()

            $result = Complete-M365AdminPortalSignIn -WebSession $session -UserAgent 'UnitTestAgent/1.0'

            $result.Completed | Should -BeTrue

            Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter {
                $Method -eq 'Get' -and $Uri -eq 'https://login.microsoftonline.com/common/login?foo=bar&sessionid=session-123'
            }

            Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter {
                $Method -eq 'Post' -and
                $Uri -eq 'https://admin.cloud.microsoft/landing' -and
                $Body['code'] -eq 'abc' -and
                $Body['id_token'] -eq 'def' -and
                $Body['state'] -eq 'ghi' -and
                $Body['session_state'] -eq 'jkl'
            }
        }
    }

    Describe 'browser launch argument handling' {
        It 'forces interactive browser sign-in to show account selection' {
            Mock Get-M365AdminLoginState {
                [pscustomobject]@{
                    LoginUrl = 'https://admin.cloud.microsoft/login?ru=%2Fadminportal%3Fref%3Dprelogin'
                }
            }

            $url = Get-M365BrowserInteractiveStartUrl -UserAgent 'UnitTestAgent/1.0'

            $url | Should -Be 'https://admin.cloud.microsoft/login?ru=%2Fadminportal%3Fref%3Dprelogin&prompt=select_account'
        }

        It 'uses a login prompt when a username is provided' {
            Mock Get-M365AdminLoginState {
                [pscustomobject]@{
                    LoginUrl = 'https://admin.cloud.microsoft/login?ru=%2Fadminportal%3Fref%3Dprelogin&login_hint=admin%40contoso.com'
                }
            }

            $url = Get-M365BrowserInteractiveStartUrl -Username 'admin@contoso.com' -UserAgent 'UnitTestAgent/1.0'

            $url | Should -Be 'https://admin.cloud.microsoft/login?ru=%2Fadminportal%3Fref%3Dprelogin&login_hint=admin%40contoso.com&prompt=login'
        }

        It 'does not duplicate an existing prompt parameter' {
            Mock Get-M365AdminLoginState {
                [pscustomobject]@{
                    LoginUrl = 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=test-client&prompt=login'
                }
            }

            $url = Get-M365BrowserInteractiveStartUrl -Username 'admin@contoso.com' -UserAgent 'UnitTestAgent/1.0'

            $url | Should -Be 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=test-client&prompt=login'
        }

        It 'quotes browser arguments that contain spaces' {
            $arguments = Get-M365BrowserLaunchArgumentList `
                -Browser ([pscustomobject]@{ Name = 'Microsoft Edge'; Path = 'C:\Edge\msedge.exe' }) `
                -UsePrivateSession:$false `
                -DebugPort 9222 `
                -ProfileDirectory 'C:\Users\Test User\AppData\Local\M365Internals\Browser Profile' `
                -StartUrl 'https://admin.cloud.microsoft/' `
                -UserAgent 'Mozilla/5.0 Test Agent'

            $arguments | Should -Contain '"--user-agent=Mozilla/5.0 Test Agent"'
            $arguments | Should -Contain '"--user-data-dir=C:\Users\Test User\AppData\Local\M365Internals\Browser Profile"'
        }

        It 'quotes SSO browser arguments that contain spaces' {
            $arguments = Get-M365SsoLaunchArgumentList `
                -ProfilePath 'C:\Users\Test User\AppData\Local\M365Internals\SSO Profile' `
                -DebugPort 9333 `
                -StartUrl 'https://admin.cloud.microsoft/' `
                -UserAgent 'Mozilla/5.0 Test Agent'

            $arguments | Should -Contain '"--user-agent=Mozilla/5.0 Test Agent"'
            $arguments | Should -Contain '"--user-data-dir=C:\Users\Test User\AppData\Local\M365Internals\SSO Profile"'
        }
    }

    Describe 'Connect-M365Portal credential forwarding' {
        BeforeEach {
            $script:credentialAuthMfaBound = $null

            Mock Invoke-M365CredentialAuthentication {
                $script:credentialAuthMfaBound = $PSBoundParameters.ContainsKey('MfaMethod')
                'ests-cookie'
            }

            Mock Connect-M365AuthArtifactSet {
                [pscustomobject]@{
                    Connected = $true
                }
            }
        }

        It 'does not bind an empty MFA method when none is specified' {
            $credential = [pscredential]::new(
                'admin@contoso.com',
                (ConvertTo-SecureString 'Password123!' -AsPlainText -Force)
            )

            $result = Connect-M365Portal -Credential $credential -SkipValidation

            $result.Connected | Should -BeTrue
            $script:credentialAuthMfaBound | Should -BeFalse

            Assert-MockCalled Invoke-M365CredentialAuthentication -Times 1 -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('MfaMethod')
            }
        }
    }

    Describe 'Invoke-M365BrowserAuthentication' {
        BeforeEach {
            $script:browserCookiePollCount = 0

            $script:browserProcess = [pscustomobject]@{
                HasExited = $false
                Id        = 1234
            }
            $script:browserProcess | Add-Member -MemberType ScriptMethod -Name Refresh -Value { }

            Mock Resolve-M365BrowserPath {
                [pscustomobject]@{
                    Name = 'Microsoft Edge'
                    Path = 'C:\Edge\msedge.exe'
                }
            }

            Mock Get-M365BrowserFreeTcpPort { 9222 }

            Mock Resolve-M365BrowserProfileConfiguration {
                [pscustomobject]@{
                    ProfilePath          = 'C:\Temp\M365Internals\BrowserProfile'
                    UsePrivateSession    = $false
                    CleanupProfileOnExit = $false
                }
            }

            Mock Get-M365BrowserInteractiveStartUrl { 'https://admin.cloud.microsoft/' }
            Mock Get-M365BrowserLaunchArgumentList { @('--headless=new') }
            Mock Start-Process { $script:browserProcess }
            Mock Stop-Process { }
            Mock Get-M365BrowserCdpVersion {
                [pscustomobject]@{
                    webSocketDebuggerUrl = 'ws://127.0.0.1:9222/devtools/browser/test'
                }
            }
            Mock Get-M365BrowserPreferredWebSocketUrl { 'ws://127.0.0.1:9222/devtools/browser/test' }
            Mock Start-Sleep { }

            Mock Get-M365BrowserCookieJar {
                $script:browserCookiePollCount++

                if ($script:browserCookiePollCount -eq 1) {
                    return @(
                        [pscustomobject]@{ name = 'ESTSAUTH'; value = 'ests-cookie'; domain = 'login.microsoftonline.com' }
                    )
                }

                return @(
                    [pscustomobject]@{ name = 'ESTSAUTH'; value = 'ests-cookie'; domain = 'login.microsoftonline.com' }
                    [pscustomobject]@{ name = 'RootAuthToken'; value = 'root-token'; domain = 'admin.cloud.microsoft' }
                    [pscustomobject]@{ name = 'SPAAuthCookie'; value = 'spa-cookie'; domain = 'admin.cloud.microsoft' }
                    [pscustomobject]@{ name = 'OIDCAuthCookie'; value = 'oidc-cookie'; domain = 'admin.cloud.microsoft' }
                    [pscustomobject]@{ name = 's.AjaxSessionKey'; value = 'ajax-key'; domain = 'admin.cloud.microsoft' }
                )
            }
        }

        It 'keeps polling briefly after ESTS appears so portal cookies can win' {
            $result = Invoke-M365BrowserAuthentication -TimeoutSeconds 30 -UserAgent 'UnitTestAgent/1.0'

            $result.EstsAuthCookieValue | Should -Be 'ests-cookie'
            $result.PortalWebSession | Should -Not -BeNullOrEmpty
            $script:browserCookiePollCount | Should -Be 2
        }
    }
}
