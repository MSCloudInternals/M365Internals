Describe 'Browser entry point in a fresh PowerShell process' {
    It 'reaches browser discovery with only M365Internals imported' {
        $manifest = Join-Path (Get-Module M365Internals).ModuleBase 'M365Internals.psd1'
        $fixturePath = Join-Path $TestDrive 'Test-M365ColdStartup.ps1'
        $missingBrowser = Join-Path $TestDrive 'missing-browser'
        @'
param($Manifest, $BrowserPath, $ProfilePath)
$ErrorActionPreference = 'Stop'
Import-Module $Manifest
try {
    $null = Connect-M365Portal -BrowserSignIn -BrowserPath $BrowserPath -ProfilePath $ProfilePath
} catch {
    if ($_.Exception.Message -ne "Browser executable '$BrowserPath' was not found. Specify a valid path or command name.") {
        throw
    }
    if ([IO.Directory]::Exists($ProfilePath)) {
        throw 'Browser discovery unexpectedly created the profile directory.'
    }
    'BrowserDiscoveryReached'
    exit 0
}
throw 'Connection unexpectedly succeeded.'
'@ | Set-Content -LiteralPath $fixturePath

        $powerShellPath = (Get-Process -Id $PID).Path
        $result = & $powerShellPath -NoProfile -NonInteractive -File $fixturePath $manifest $missingBrowser (Join-Path $TestDrive 'profile')
        $LASTEXITCODE | Should -Be 0
        $result | Should -Be 'BrowserDiscoveryReached'
    }
}

InModuleScope M365Internals {
    Describe 'browser startup diagnostics' {
        It 'reports an already-exited browser before polling DevTools' {
            $process = [pscustomobject]@{ HasExited = $true }
            $process | Add-Member -MemberType ScriptMethod -Name Refresh -Value {}
            Mock Invoke-RestMethod { throw 'should not execute' }
            { Get-M365BrowserCdpVersion -Port 1234 -Process $process } | Should -Throw '*launch failed*exited*'
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }

        It 'reports startup timeout without exposing transport errors' {
            $script:clock = [datetime]::UtcNow
            Mock Get-Date { $script:clock = $script:clock.AddSeconds(30); $script:clock }
            Mock Start-Sleep {}
            Mock Invoke-RestMethod { throw 'private transport details' }
            { Get-M365BrowserCdpVersion -Port 1234 -TimeoutSeconds 1 } | Should -Throw '*startup failed*did not become ready*'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        }
    }

    Describe 'browser sign-in diagnostics' {
        BeforeEach {
            $script:clock = [datetime]::UtcNow
            $script:fakeBrowser = [pscustomobject]@{ HasExited = $false }
            $script:fakeBrowser | Add-Member -MemberType ScriptMethod -Name Refresh -Value {}
            Mock Resolve-M365BrowserPath { [pscustomobject]@{ Name = 'Edge'; Path = 'edge.exe' } }
            Mock Get-M365BrowserFreeTcpPort { 1234 }
            Mock Resolve-M365BrowserProfileConfiguration {
                [pscustomobject]@{ ProfilePath = 'C:\TestProfile'; UsePrivateSession = $false; CleanupProfileOnExit = $false }
            }
            Mock Get-M365BrowserInteractiveStartUrl { 'https://admin.cloud.microsoft/' }
            Mock Get-M365BrowserLaunchArgumentList { @('example') }
            Mock Test-M365BrowserProcessOutputSuppression { $false }
            Mock Start-M365BrowserProcess { $script:fakeBrowser }
            Mock Stop-M365BrowserProcess {}
            Mock Remove-M365BrowserProcessRedirectFiles {}
            Mock Get-M365BrowserCdpVersion { [pscustomobject]@{ webSocketDebuggerUrl = 'ws://127.0.0.1/test' } }
            Mock Get-M365BrowserPreferredTargetContext { [pscustomobject]@{ WebSocketUrl = 'ws://127.0.0.1/test' } }
            Mock Start-Sleep {}
            Mock Get-Date { $script:clock = $script:clock.AddSeconds(31); $script:clock }
            Mock Invoke-M365BrowserCdpCommand { [pscustomobject]@{ cookies = @() } }
            Mock Get-M365BestBrowserEstsCookie { $null }
            Mock New-M365BrowserPortalWebSession { $null }
            Mock Test-M365BrowserAuthenticationCompletion { $false }
        }

        It 'reports a sanitized launch failure' {
            Mock Start-M365BrowserProcess { throw 'private launch details' }
            { Invoke-M365BrowserAuthentication -TimeoutSeconds 30 } | Should -Throw '*launch failed*could not be started*'
        }

        It 'reports a lost browser connection rather than a sign-in timeout' {
            Mock Invoke-M365BrowserCdpCommand { throw 'private connection details' }
            { Invoke-M365BrowserAuthentication -TimeoutSeconds 30 } | Should -Throw '*lost its browser connection*'
            Should -Invoke Invoke-M365BrowserCdpCommand -Times 3 -Exactly
        }

        It 'reports an invalid DevTools response as a startup failure' {
            Mock Get-M365BrowserCdpVersion { [pscustomobject]@{} }
            { Invoke-M365BrowserAuthentication -TimeoutSeconds 30 } | Should -Throw '*startup failed*did not become ready*'
        }

        It 'reports an ordinary sign-in timeout when a fallback polling command succeeds' {
            Mock Invoke-M365BrowserCdpCommand { throw 'unsupported browser command' } -ParameterFilter {
                $Method -eq 'Network.getAllCookies'
            }
            { Invoke-M365BrowserAuthentication -TimeoutSeconds 30 } | Should -Throw '*sign-in timed out*'
        }

        It 'returns the captured session after successful polling' {
            Mock New-M365BrowserPortalWebSession { [Microsoft.PowerShell.Commands.WebRequestSession]::new() }
            Mock Test-M365BrowserAuthenticationCompletion { $true }
            $result = Invoke-M365BrowserAuthentication -TimeoutSeconds 30
            $result.PortalWebSession | Should -Not -BeNullOrEmpty
        }
    }
}
