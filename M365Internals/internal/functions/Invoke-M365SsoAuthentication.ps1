function Get-M365SsoDefaultProfilePath {
    [CmdletBinding()]
    param()

    if ($IsWindows) {
        return Join-Path $env:LOCALAPPDATA 'M365Internals\SsoEdgeProfile'
    }

    if ($IsMacOS) {
        return Join-Path $HOME 'Library/Application Support/M365Internals/SsoBrowserProfile'
    }

    if ($IsLinux) {
        return Join-Path $HOME '.config/M365Internals/sso-browser-profile'
    }

    throw 'Connect-M365PortalBySSO is not supported on this operating system.'
}

function Initialize-M365SsoProfile {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper that prepares the dedicated SSO browser profile.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        $null = New-Item -ItemType Directory -Path $ProfilePath -Force
    }

    if (-not $IsWindows) {
        return
    }

    $defaultProfilePath = Join-Path $ProfilePath 'Default'
    if (-not (Test-Path -LiteralPath $defaultProfilePath)) {
        $null = New-Item -ItemType Directory -Path $defaultProfilePath -Force
    }

    $preferencesPath = Join-Path $defaultProfilePath 'Preferences'
    if (Test-Path -LiteralPath $preferencesPath) {
        return
    }

    @{
        sync    = @{ requested = $false }
        signin  = @{ allowed = $true }
        browser = @{ has_seen_welcome_page = $true }
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $preferencesPath -Encoding UTF8
}

function Get-M365SsoLaunchArgumentList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfilePath,

        [Parameter(Mandatory)]
        [int]$DebugPort,

        [Parameter(Mandatory)]
        [string]$StartUrl,

        [switch]$Visible,

        [string]$UserAgent
    )

    $arguments = @(
        "--remote-debugging-port=$DebugPort",
        '--remote-allow-origins=*',
        "--user-data-dir=$ProfilePath",
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-default-apps',
        '--disable-features=msEdgeSyncConsent,EdgeSync,msEdgeWelcomePage,msEdgeSidebarV2'
    )

    if (-not $Visible) {
        $arguments = @(
            '--headless=new',
            '--log-level=3',
            '--disable-gpu',
            '--disable-extensions',
            '--disable-sync',
            '--disable-background-networking',
            '--disable-component-update'
        ) + $arguments
    }

    if ($UserAgent) {
        $arguments = @("--user-agent=$UserAgent") + $arguments
    }

    return [string[]](Format-M365BrowserProcessArgumentList -Arguments ($arguments + @($StartUrl)))
}

function Invoke-M365SsoAuthentication {
    <#
    .SYNOPSIS
        Performs browser-based SSO authentication and returns Microsoft 365 admin portal authentication artifacts.

    .DESCRIPTION
        Starts a dedicated browser profile, lets the operating system and browser perform silent
        sign-in when possible, and extracts admin portal cookies through the browser DevTools
        protocol. This is intended for Windows-first SSO scenarios and may support additional
        operating systems later.

    .PARAMETER TenantId
        Optional tenant ID (GUID) used to select the final tenant after sign-in.

    .PARAMETER Visible
        Shows the browser window instead of using a headless launch.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for browser sign-in and cookie capture.

    .PARAMETER BrowserPath
        Optional browser executable path or command name.

    .PARAMETER ProfilePath
        Optional persistent browser profile path used for SSO.

    .PARAMETER UserAgent
        Optional User-Agent override for the launched browser.

    .OUTPUTS
        PSCustomObject containing browser authentication artifacts.

    .EXAMPLE
        Invoke-M365SsoAuthentication

        Attempts silent browser SSO using the default dedicated profile and returns the captured
        admin portal authentication artifacts.

    .EXAMPLE
        Invoke-M365SsoAuthentication -Visible

        Shows the browser window while the SSO flow completes.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding()]
    param(
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [switch]$Visible,

        [ValidateRange(30, 1800)]
        [int]$TimeoutSeconds = 180,

        [string]$BrowserPath,

        [string]$ProfilePath,

        [string]$UserAgent
    )

    if (-not $IsWindows) {
        throw 'Connect-M365PortalBySSO currently supports Windows only for now.'
    }

    $browser = Resolve-M365BrowserPath -BrowserPath $BrowserPath
    $resolvedProfilePath = if ($ProfilePath) { $ProfilePath } else { Get-M365SsoDefaultProfilePath }
    Initialize-M365SsoProfile -ProfilePath $resolvedProfilePath

    $debugPort = Get-M365BrowserFreeTcpPort
    $startUrl = if ($TenantId) {
        $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
        if ($UserAgent) {
            $session.UserAgent = $UserAgent
        }
        (Get-M365AdminLoginState -WebSession $session -TenantId $TenantId -UserAgent $UserAgent).LoginUrl
    } else {
        'https://admin.cloud.microsoft/'
    }
    $arguments = Get-M365SsoLaunchArgumentList -ProfilePath $resolvedProfilePath -DebugPort $debugPort -StartUrl $startUrl -Visible:$Visible -UserAgent $UserAgent
    $browserProcess = $null

    try {
        Write-Host "Launching $($browser.Name) for SSO sign-in..."
        if ($Visible) {
            Write-Host 'A browser window will open. Silent sign-in should occur automatically if the browser profile and device state allow it.'
        } else {
            Write-Host 'Attempting silent browser SSO in headless mode...'
        }

        if ($Visible) {
            $browserProcess = Start-Process -FilePath $browser.Path -ArgumentList $arguments -PassThru
        } else {
            $browserProcess = Start-Process -FilePath $browser.Path -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardError 'NUL'
        }

        $versionInfo = Get-M365BrowserCdpVersion -Port $debugPort -TimeoutSeconds 20
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $estsAuthCookieValue = $null
        $portalWebSession = $null
        $portalCookieGraceDeadline = $null

        do {
            Start-Sleep -Seconds 2

            if ($browserProcess) {
                $browserProcess.Refresh()
                if ($browserProcess.HasExited) {
                    if ($portalWebSession -or $estsAuthCookieValue) {
                        break
                    }

                    if ($Visible) {
                        throw 'The browser window closed before SSO authentication completed.'
                    }

                    throw 'The browser exited before SSO authentication completed. Retry with -Visible to observe the flow on this device.'
                }
            }

            try {
                $cookieWebSocketUrl = Get-M365BrowserPreferredWebSocketUrl -Port $debugPort -FallbackWebSocketUrl $versionInfo.webSocketDebuggerUrl
                $cookies = @(Get-M365BrowserCookieJar -WebSocketUrl $cookieWebSocketUrl)
            } catch {
                Write-Verbose "Cookie polling failed: $($_.Exception.Message)"
                continue
            }

            $currentEstsCookie = Get-M365BestBrowserEstsCookie -Cookies $cookies
            if ($currentEstsCookie) {
                $estsAuthCookieValue = $currentEstsCookie.value
                if (-not $portalCookieGraceDeadline) {
                    $portalCookieGraceDeadline = (Get-Date).AddSeconds(10)
                    Write-Verbose 'Captured ESTS authentication cookie. Waiting briefly for the admin portal cookie set to appear before falling back to ESTS bootstrap.'
                }
            }

            $portalWebSession = New-M365BrowserPortalWebSession -Cookies $cookies -UserAgent $UserAgent

            if ($portalWebSession) {
                break
            }

            if ($estsAuthCookieValue -and $portalCookieGraceDeadline -and (Get-Date) -ge $portalCookieGraceDeadline) {
                break
            }
        } while ((Get-Date) -lt $deadline)

        if (-not $portalWebSession -and -not $estsAuthCookieValue) {
            throw 'SSO authentication did not produce admin portal or ESTS cookies before the timeout expired.'
        }

        return [pscustomobject]@{
            EstsAuthCookieValue = $estsAuthCookieValue
            PortalWebSession    = $portalWebSession
            TenantId            = $TenantId
            ProfilePath         = $resolvedProfilePath
        }
    } finally {
        if ($browserProcess) {
            $browserProcess.Refresh()
            if (-not $browserProcess.HasExited) {
                Stop-Process -Id $browserProcess.Id -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
