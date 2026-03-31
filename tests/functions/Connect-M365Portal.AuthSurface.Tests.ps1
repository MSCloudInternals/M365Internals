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

    It 'treats AjaxSessionKey as optional for portal-cookie reuse' {
        $command = Get-Command Connect-M365Portal
        $portalCookieParameterSet = $command.ParameterSets | Where-Object Name -EQ 'PortalCookies'
        $ajaxParameter = $portalCookieParameterSet.Parameters | Where-Object Name -EQ 'AjaxSessionKey'

        $ajaxParameter.IsMandatory | Should -BeFalse
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
        (Get-Command Connect-M365PortalBySoftwarePasskey).Parameters.Keys | Should -Contain 'KeyVaultTenantId'
        (Get-Command Connect-M365PortalBySoftwarePasskey).Parameters.Keys | Should -Contain 'KeyVaultClientId'
        (Get-Command Connect-M365PortalBySSO).Parameters.Keys | Should -Contain 'Visible'
        (Get-Command Connect-M365PortalByTemporaryAccessPass).Parameters.Keys | Should -Contain 'TemporaryAccessPass'
        (Get-Command Connect-M365PortalByTemporaryAccessPass).Parameters['TemporaryAccessPass'].Aliases | Should -Contain 'TAP'
    }

    It 'exposes Key Vault passkey parameters on the SoftwarePasskey parameter set' {
        $command = Get-Command Connect-M365Portal
        $softwarePasskeyParameterSet = $command.ParameterSets | Where-Object Name -EQ 'SoftwarePasskey'

        $softwarePasskeyParameterSet.Parameters.Name | Should -Contain 'KeyVaultTenantId'
        $softwarePasskeyParameterSet.Parameters.Name | Should -Contain 'KeyVaultClientId'
        $softwarePasskeyParameterSet.Parameters.Name | Should -Contain 'KeyVaultApiVersion'
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

        It 'quotes process arguments whose values contain spaces' {
            $arguments = Format-M365BrowserProcessArgumentList -Arguments @(
                '--remote-debugging-port=9222'
                '--user-data-dir=C:\Users\Test User\AppData\Local\M365Internals\Browser Profile'
                '--user-agent=Mozilla/5.0 Test Agent'
                'https://admin.cloud.microsoft/'
            )

            $arguments | Should -Contain '--remote-debugging-port=9222'
            $arguments | Should -Contain '--user-data-dir="C:\Users\Test User\AppData\Local\M365Internals\Browser Profile"'
            $arguments | Should -Contain '--user-agent="Mozilla/5.0 Test Agent"'
            $arguments | Should -Contain 'https://admin.cloud.microsoft/'
        }

        It 'uses the M365Internals Chromium profile directory when launching browser auth' {
            $arguments = Get-M365BrowserLaunchArgumentList `
                -Browser ([pscustomobject]@{ Name = 'Microsoft Edge'; Path = 'C:\Edge\msedge.exe' }) `
                -UsePrivateSession:$false `
                -DebugPort 9222 `
                -ProfileDirectory 'C:\Users\Test User\AppData\Local\M365Internals\Browser Profile' `
                -StartUrl 'https://admin.cloud.microsoft/'

            $arguments | Should -Contain '--profile-directory=M365Internals'
        }

        It 'returns SSO launch arguments that can be formatted for spaced profile paths' {
            $arguments = Get-M365SsoLaunchArgumentList `
                -ProfilePath 'C:\Users\Test User\AppData\Local\M365Internals\SSO Profile' `
                -DebugPort 9333 `
                -StartUrl 'https://admin.cloud.microsoft/' `
                -UserAgent 'Mozilla/5.0 Test Agent'

            $formattedArguments = Format-M365BrowserProcessArgumentList -Arguments $arguments

            $formattedArguments | Should -Contain '--user-agent="Mozilla/5.0 Test Agent"'
            $formattedArguments | Should -Contain '--user-data-dir="C:\Users\Test User\AppData\Local\M365Internals\SSO Profile"'
        }
    }

    Describe 'browser profile preparation' {
        It 'initializes the dedicated Chromium profile as M365Internals without restoring previous tabs' {
            $profileRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('m365internals-browser-profile-' + [guid]::NewGuid().ToString('N'))

            try {
                Initialize-M365BrowserProfile -ProfilePath $profileRoot

                $namedProfilePath = Join-Path $profileRoot 'M365Internals'
                $preferencesPath = Join-Path $namedProfilePath 'Preferences'
                $localStatePath = Join-Path $profileRoot 'Local State'
                $preferences = Get-Content -LiteralPath $preferencesPath -Raw | ConvertFrom-Json
                $localState = Get-Content -LiteralPath $localStatePath -Raw | ConvertFrom-Json

                Test-Path -LiteralPath $namedProfilePath -PathType Container | Should -BeTrue
                $preferences.profile.name | Should -Be 'M365Internals'
                $preferences.profile.exit_type | Should -Be 'Normal'
                $preferences.session.restore_on_startup | Should -Be 5
                @($preferences.session.startup_urls).Count | Should -Be 0
                $preferences.sync.requested | Should -BeFalse
                $preferences.signin.allowed | Should -BeTrue
                $preferences.browser.has_seen_welcome_page | Should -BeTrue
                $localState.profile.last_used | Should -Be 'M365Internals'
            }
            finally {
                Remove-Item -Path $profileRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'migrates the legacy Default browser profile to M365Internals' {
            $profileRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('m365internals-browser-migration-' + [guid]::NewGuid().ToString('N'))
            $legacyProfilePath = Join-Path $profileRoot 'Default'
            $sentinelPath = Join-Path $legacyProfilePath 'Sentinel.txt'

            try {
                $null = New-Item -ItemType Directory -Path $legacyProfilePath -Force
                Set-Content -LiteralPath $sentinelPath -Value 'legacy profile data'

                Initialize-M365BrowserProfile -ProfilePath $profileRoot

                Test-Path -LiteralPath (Join-Path $profileRoot 'Default') -PathType Container | Should -BeFalse
                Test-Path -LiteralPath (Join-Path $profileRoot 'M365Internals/Sentinel.txt') -PathType Leaf | Should -BeTrue
            }
            finally {
                Remove-Item -Path $profileRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Describe 'browser candidate resolution' {
        It 'includes user application installs in the macOS browser candidate set' {
            $candidates = @(Get-M365MacOSBrowserCandidateSet)
            $userApplicationRoot = Join-Path $HOME 'Applications'

            $candidates.FilePath | Should -Contain (Join-Path $userApplicationRoot 'Microsoft Edge.app/Contents/MacOS/Microsoft Edge')
            $candidates.FilePath | Should -Contain (Join-Path $userApplicationRoot 'Google Chrome.app/Contents/MacOS/Google Chrome')
            $candidates.FilePath | Should -Contain (Join-Path $userApplicationRoot 'Brave Browser.app/Contents/MacOS/Brave Browser')
            $candidates.FilePath | Should -Contain (Join-Path $userApplicationRoot 'Chromium.app/Contents/MacOS/Chromium')
        }

        It 'resolves a macOS app bundle path to its executable path' {
            $bundleRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('m365internals-browser-bundle-' + [guid]::NewGuid().ToString('N'))
            $bundlePath = Join-Path $bundleRoot 'Contoso Browser.app'
            $macOsPath = Join-Path $bundlePath 'Contents/MacOS'
            $executablePath = Join-Path $macOsPath 'ContosoBrowserExecutable'

            try {
                $null = New-Item -ItemType Directory -Path $macOsPath -Force
                $null = New-Item -ItemType File -Path $executablePath -Force

                $result = Resolve-M365MacOSAppBundleExecutablePath -BundlePath $bundlePath

                $result.Name | Should -Be 'ContosoBrowserExecutable'
                $result.Path | Should -Be $executablePath
            }
            finally {
                Remove-Item -Path $bundleRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'suppresses interactive browser stdout and stderr on non-Windows platforms by default' {
            if ($IsWindows) {
                Set-ItResult -Skipped -Because 'Non-Windows launch behavior is not applicable on Windows.'
                return
            }

            Mock Start-Process {
                param(
                    $FilePath,
                    $ArgumentList,
                    [switch]$PassThru,
                    $RedirectStandardOutput,
                    $RedirectStandardError
                )

                [pscustomobject]@{
                    Id                     = 1234
                    HasExited              = $false
                    FilePath               = $FilePath
                    RedirectStandardOutput = $RedirectStandardOutput
                    RedirectStandardError  = $RedirectStandardError
                }
            }

            $result = Start-M365BrowserProcess -BrowserPath '/usr/bin/microsoft-edge-stable' -ArgumentList @('https://admin.cloud.microsoft/') -SuppressBrowserOutput

            $result.FilePath | Should -Be '/usr/bin/microsoft-edge-stable'
            $result.RedirectStandardOutput | Should -Not -BeNullOrEmpty
            $result.RedirectStandardError | Should -Not -BeNullOrEmpty
            $result.RedirectStandardOutput | Should -Not -Be $result.RedirectStandardError
            $result.StandardOutputPath | Should -Be $result.RedirectStandardOutput
            $result.StandardErrorPath | Should -Be $result.RedirectStandardError
            $result.StandardOutputPath | Should -Not -BeNullOrEmpty
            $result.StandardErrorPath | Should -Not -BeNullOrEmpty
            $result.StandardOutputPath | Should -Not -Be $result.StandardErrorPath
        }
    }

    Describe 'software passkey forwarding' {
        BeforeEach {
            Mock Invoke-M365PasskeyAuthentication {
                [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            }

            Mock Connect-M365AuthArtifactSet {
                [pscustomobject]@{
                    Connected = $true
                }
            }
        }

        It 'forwards Key Vault passkey parameters from the public wrapper' {
            Mock Connect-M365Portal {
                [pscustomobject]@{
                    Connected = $true
                }
            }

            $result = Connect-M365PortalBySoftwarePasskey -KeyFilePath '.\admin-kv.passkey' -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2' -KeyVaultTenantId '72f988bf-86f1-41af-91ab-2d7cd011db47' -KeyVaultClientId '11111111-2222-3333-4444-555555555555' -KeyVaultApiVersion '7.5'

            $result.Connected | Should -BeTrue
            Should -Invoke Connect-M365Portal -Times 1 -Exactly -ParameterFilter {
                $KeyFilePath -eq '.\admin-kv.passkey' -and
                $TenantId -eq '8612f621-73ca-4c12-973c-0da732bc44c2' -and
                $KeyVaultTenantId -eq '72f988bf-86f1-41af-91ab-2d7cd011db47' -and
                $KeyVaultClientId -eq '11111111-2222-3333-4444-555555555555' -and
                $KeyVaultApiVersion -eq '7.5'
            }
        }

        It 'forwards Key Vault passkey parameters from Connect-M365Portal to the internal helper' {
            $result = Connect-M365Portal -KeyFilePath '.\admin-kv.passkey' -KeyVaultTenantId '72f988bf-86f1-41af-91ab-2d7cd011db47' -KeyVaultClientId '11111111-2222-3333-4444-555555555555' -KeyVaultApiVersion '7.5' -SkipValidation

            $result.Connected | Should -BeTrue
            Should -Invoke Invoke-M365PasskeyAuthentication -Times 1 -Exactly -ParameterFilter {
                $KeyFilePath -eq '.\admin-kv.passkey' -and
                $KeyVaultTenantId -eq '72f988bf-86f1-41af-91ab-2d7cd011db47' -and
                $KeyVaultClientId -eq '11111111-2222-3333-4444-555555555555' -and
                $KeyVaultApiVersion -eq '7.5'
            }
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

    Describe 'portal cookie reuse' {
        BeforeEach {
            $script:lastPortalCookieSession = $null

            Mock Set-M365PortalConnectionSettings {
                $script:lastPortalCookieSession = $WebSession
                [pscustomobject]@{
                    Connected = $true
                }
            }
        }

        It 'can reuse portal cookies without an AjaxSessionKey value' {
            $result = Connect-M365Portal -RootAuthToken 'root-token' -SPAAuthCookie 'spa-cookie' -OIDCAuthCookie 'oidc-cookie' -SkipValidation

            $result.Connected | Should -BeTrue
            ($script:lastPortalCookieSession.Cookies.GetCookies('https://admin.cloud.microsoft/') | Where-Object Name -eq 's.AjaxSessionKey') | Should -BeNullOrEmpty
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
            Mock Start-M365BrowserProcess { $script:browserProcess }
            Mock Stop-M365BrowserProcess { }
            Mock Remove-M365BrowserProcessRedirectFiles { }
            Mock Get-M365BrowserCdpVersion {
                [pscustomobject]@{
                    webSocketDebuggerUrl = 'ws://127.0.0.1:9222/devtools/browser/test'
                }
            }
            Mock Get-M365BrowserPreferredTargetContext {
                [pscustomobject]@{
                    Url          = 'https://admin.cloud.microsoft/'
                    Title        = 'Microsoft 365 admin center'
                    Type         = 'page'
                    WebSocketUrl = 'ws://127.0.0.1:9222/devtools/browser/test'
                }
            }
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
