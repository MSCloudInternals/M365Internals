function Resolve-M365BrowserPathFromCandidateSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        if ($candidate.CommandName) {
            $command = Get-Command $candidate.CommandName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($command) {
                return [pscustomobject]@{
                    Path = $command.Source
                    Name = $candidate.Name
                }
            }
        }

        if ($candidate.FilePath -and (Test-Path -LiteralPath $candidate.FilePath)) {
            return [pscustomobject]@{
                Path = $candidate.FilePath
                Name = $candidate.Name
            }
        }
    }

    return $null
}

function Resolve-M365WindowsBrowserPath {
    [CmdletBinding()]
    param()

    $match = Resolve-M365BrowserPathFromCandidateSet -Candidates @(
        [pscustomobject]@{ Name = 'Microsoft Edge'; CommandName = 'msedge.exe' }
        [pscustomobject]@{ Name = 'Google Chrome'; CommandName = 'chrome.exe' }
        [pscustomobject]@{ Name = 'Brave Browser'; CommandName = 'brave.exe' }
        [pscustomobject]@{ Name = 'Chromium'; CommandName = 'chromium.exe' }
        [pscustomobject]@{ Name = 'Microsoft Edge'; FilePath = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' }
        [pscustomobject]@{ Name = 'Microsoft Edge'; FilePath = 'C:\Program Files\Microsoft\Edge\Application\msedge.exe' }
        [pscustomobject]@{ Name = 'Google Chrome'; FilePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe' }
        [pscustomobject]@{ Name = 'Google Chrome'; FilePath = 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe' }
        [pscustomobject]@{ Name = 'Brave Browser'; FilePath = 'C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe' }
        [pscustomobject]@{ Name = 'Brave Browser'; FilePath = 'C:\Program Files (x86)\BraveSoftware\Brave-Browser\Application\brave.exe' }
    )

    if ($match) {
        return $match
    }

    throw 'No supported Chromium-based browser was found on Windows. Install Microsoft Edge, Google Chrome, Brave, or specify -BrowserPath.'
}

function Resolve-M365MacOSBrowserPath {
    [CmdletBinding()]
    param()

    $match = Resolve-M365BrowserPathFromCandidateSet -Candidates @(
        [pscustomobject]@{ Name = 'Microsoft Edge'; CommandName = 'msedge' }
        [pscustomobject]@{ Name = 'Google Chrome'; CommandName = 'google-chrome' }
        [pscustomobject]@{ Name = 'Chromium'; CommandName = 'chromium' }
        [pscustomobject]@{ Name = 'Microsoft Edge'; FilePath = '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge' }
        [pscustomobject]@{ Name = 'Google Chrome'; FilePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' }
        [pscustomobject]@{ Name = 'Brave Browser'; FilePath = '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser' }
        [pscustomobject]@{ Name = 'Chromium'; FilePath = '/Applications/Chromium.app/Contents/MacOS/Chromium' }
    )

    if ($match) {
        return $match
    }

    throw 'No supported Chromium-based browser was found on macOS. Install Microsoft Edge, Google Chrome, Brave, Chromium, or specify -BrowserPath.'
}

function Resolve-M365LinuxBrowserPath {
    [CmdletBinding()]
    param()

    $match = Resolve-M365BrowserPathFromCandidateSet -Candidates @(
        [pscustomobject]@{ Name = 'Microsoft Edge'; CommandName = 'microsoft-edge' }
        [pscustomobject]@{ Name = 'Microsoft Edge'; CommandName = 'microsoft-edge-stable' }
        [pscustomobject]@{ Name = 'Google Chrome'; CommandName = 'google-chrome' }
        [pscustomobject]@{ Name = 'Google Chrome'; CommandName = 'google-chrome-stable' }
        [pscustomobject]@{ Name = 'Brave Browser'; CommandName = 'brave-browser' }
        [pscustomobject]@{ Name = 'Chromium'; CommandName = 'chromium' }
        [pscustomobject]@{ Name = 'Chromium'; CommandName = 'chromium-browser' }
        [pscustomobject]@{ Name = 'Microsoft Edge'; FilePath = '/usr/bin/microsoft-edge' }
        [pscustomobject]@{ Name = 'Microsoft Edge'; FilePath = '/usr/bin/microsoft-edge-stable' }
        [pscustomobject]@{ Name = 'Google Chrome'; FilePath = '/usr/bin/google-chrome' }
        [pscustomobject]@{ Name = 'Google Chrome'; FilePath = '/usr/bin/google-chrome-stable' }
        [pscustomobject]@{ Name = 'Brave Browser'; FilePath = '/usr/bin/brave-browser' }
        [pscustomobject]@{ Name = 'Chromium'; FilePath = '/usr/bin/chromium' }
        [pscustomobject]@{ Name = 'Chromium'; FilePath = '/usr/bin/chromium-browser' }
    )

    if ($match) {
        return $match
    }

    throw 'No supported Chromium-based browser was found on Linux. Install Microsoft Edge, Google Chrome, Brave, Chromium, or specify -BrowserPath.'
}

function Resolve-M365BrowserPath {
    [CmdletBinding()]
    param(
        [string]$BrowserPath
    )

    if ($BrowserPath) {
        if (Test-Path -LiteralPath $BrowserPath) {
            return [pscustomobject]@{
                Path = (Resolve-Path -LiteralPath $BrowserPath).ProviderPath
                Name = [System.IO.Path]::GetFileNameWithoutExtension($BrowserPath)
            }
        }

        $command = Get-Command $BrowserPath -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            return [pscustomobject]@{
                Path = $command.Source
                Name = $command.Name
            }
        }

        throw "Browser executable '$BrowserPath' was not found. Specify a valid path or command name."
    }

    if ($IsWindows) {
        return Resolve-M365WindowsBrowserPath
    }

    if ($IsMacOS) {
        return Resolve-M365MacOSBrowserPath
    }

    if ($IsLinux) {
        return Resolve-M365LinuxBrowserPath
    }

    throw 'Connect-M365PortalByBrowser is not supported on this operating system.'
}

function Get-M365BrowserDefaultProfilePath {
    [CmdletBinding()]
    param()

    if ($IsWindows) {
        return Join-Path $env:LOCALAPPDATA 'M365Internals\BrowserProfile'
    }

    if ($IsMacOS) {
        return Join-Path $HOME 'Library/Application Support/M365Internals/BrowserProfile'
    }

    if ($IsLinux) {
        return Join-Path $HOME '.config/M365Internals/browser-profile'
    }

    throw 'Connect-M365PortalByBrowser is not supported on this operating system.'
}

function Initialize-M365BrowserProfile {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper that prepares the dedicated browser profile.')]
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

function Resolve-M365BrowserProfileConfiguration {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper that prepares browser profile state.')]
    [CmdletBinding()]
    param(
        [string]$ProfilePath,

        [switch]$ResetProfile,

        [switch]$PrivateSession
    )

    if ($PrivateSession -and $ProfilePath) {
        throw 'Do not combine -PrivateSession with -ProfilePath. Private session uses a temporary profile automatically.'
    }

    if ($PrivateSession) {
        $temporaryProfilePath = Join-Path ([System.IO.Path]::GetTempPath()) ('m365-browser-signin-' + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $temporaryProfilePath -Force

        return [pscustomobject]@{
            ProfilePath          = $temporaryProfilePath
            UsePrivateSession    = $true
            CleanupProfileOnExit = $true
        }
    }

    $resolvedProfilePath = if ($ProfilePath) { $ProfilePath } else { Get-M365BrowserDefaultProfilePath }
    if ($ResetProfile -and (Test-Path -LiteralPath $resolvedProfilePath)) {
        Remove-Item -Path $resolvedProfilePath -Recurse -Force -ErrorAction Stop
    }

    Initialize-M365BrowserProfile -ProfilePath $resolvedProfilePath

    return [pscustomobject]@{
        ProfilePath          = $resolvedProfilePath
        UsePrivateSession    = $false
        CleanupProfileOnExit = $false
    }
}

function Get-M365BrowserInteractiveStartUrl {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [string]$Username,

        [string]$TenantId,

        [string]$UserAgent
    )

    $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    if ($UserAgent) {
        $session.UserAgent = $UserAgent
    }

    $loginUrl = (Get-M365AdminLoginState -WebSession $session -Username $Username -TenantId $TenantId -UserAgent $UserAgent).LoginUrl
    if ($loginUrl -notmatch '(?:\?|&)prompt=') {
        $separator = if ($loginUrl -match '\?') { '&' } else { '?' }
        $prompt = if ($Username) { 'login' } else { 'select_account' }
        $loginUrl = $loginUrl + $separator + "prompt=$prompt"
    }

    return $loginUrl
}

function Get-M365BrowserPrivateModeArgument {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Browser
    )

    $browserName = [string]$Browser.Name
    $browserPath = [string]$Browser.Path

    if ($browserName -like '*Edge*' -or $browserPath -match '(?i)msedge') {
        return '--inprivate'
    }

    return '--incognito'
}

function Format-M365BrowserProcessArgumentList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    return [string[]]@(
        foreach ($argument in $Arguments) {
            if ([string]::IsNullOrWhiteSpace($argument)) {
                continue
            }

            if ($argument -match '[\s"]') {
                '"' + ($argument -replace '"', '\\"') + '"'
                continue
            }

            $argument
        }
    )
}

function Get-M365BrowserLaunchArgumentList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Browser,

        [Parameter(Mandatory)]
        [bool]$UsePrivateSession,

        [Parameter(Mandatory)]
        [int]$DebugPort,

        [Parameter(Mandatory)]
        [string]$ProfileDirectory,

        [Parameter(Mandatory)]
        [string]$StartUrl,

        [string]$UserAgent
    )

    $arguments = @(
        "--remote-debugging-port=$DebugPort",
        "--user-data-dir=$ProfileDirectory",
        '--new-window',
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-default-apps'
    )

    # Investigate the brief post-auth Edge account picker flash later. The WebToBrowserSignIn disable-features experiment did not provide a reliable improvement, so it is not enabled by default.

    if ($UsePrivateSession) {
        $arguments = @((Get-M365BrowserPrivateModeArgument -Browser $Browser)) + $arguments
    }

    if ($UserAgent) {
        $arguments = @("--user-agent=$UserAgent") + $arguments
    }

    return [string[]](Format-M365BrowserProcessArgumentList -Arguments ($arguments + @($StartUrl)))
}

function Get-M365BrowserFreeTcpPort {
    [CmdletBinding()]
    param()

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    } finally {
        $listener.Stop()
    }
}

function Get-M365BrowserCdpVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Port,

        [int]$TimeoutSeconds = 20
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $versionUri = "http://127.0.0.1:$Port/json/version"

    do {
        try {
            return Invoke-RestMethod -Uri $versionUri -Method Get -ErrorAction Stop
        } catch {
            Start-Sleep -Milliseconds 500
        }
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for the browser DevTools endpoint on port $Port."
}

function Get-M365BrowserTargetList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Port
    )

    $targetUri = "http://127.0.0.1:$Port/json/list"
    $targets = Invoke-RestMethod -Uri $targetUri -Method Get -ErrorAction Stop
    return @($targets | Where-Object { $_ })
}

function Get-M365BrowserPreferredWebSocketUrl {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Port,

        [string]$FallbackWebSocketUrl
    )

    try {
        $targets = @(Get-M365BrowserTargetList -Port $Port)
    } catch {
        return $FallbackWebSocketUrl
    }

    $preferredTarget = @(
        $targets | Where-Object { $_.type -eq 'page' -and $_.url -like 'https://admin.cloud.microsoft/*' -and $_.webSocketDebuggerUrl }
        $targets | Where-Object { $_.type -eq 'page' -and $_.url -like 'https://login.microsoftonline.com/*' -and $_.webSocketDebuggerUrl }
        $targets | Where-Object { $_.type -eq 'page' -and $_.webSocketDebuggerUrl }
    ) | Where-Object { $_ } | Select-Object -First 1

    if ($preferredTarget) {
        return [string]$preferredTarget.webSocketDebuggerUrl
    }

    return $FallbackWebSocketUrl
}

function Invoke-M365BrowserCdpCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WebSocketUrl,

        [Parameter(Mandatory)]
        [string]$Method,

        [hashtable]$Params
    )

    $webSocket = [System.Net.WebSockets.ClientWebSocket]::new()
    $cancellation = [System.Threading.CancellationTokenSource]::new()

    try {
        $webSocket.ConnectAsync($WebSocketUrl, $cancellation.Token).GetAwaiter().GetResult()

        $requestId = [System.Math]::Abs([guid]::NewGuid().GetHashCode())
        $payload = @{ id = $requestId; method = $Method }
        if ($Params) {
            $payload.params = $Params
        }

        $message = $payload | ConvertTo-Json -Compress -Depth 10
        $sendBuffer = [System.Text.Encoding]::UTF8.GetBytes($message)
        $webSocket.SendAsync(
            [System.ArraySegment[byte]]::new($sendBuffer),
            [System.Net.WebSockets.WebSocketMessageType]::Text,
            $true,
            $cancellation.Token
        ).GetAwaiter().GetResult()

        $receiveBuffer = [byte[]]::new(65536)

        while ($true) {
            $builder = [System.Text.StringBuilder]::new()
            do {
                $result = $webSocket.ReceiveAsync(
                    [System.ArraySegment[byte]]::new($receiveBuffer),
                    $cancellation.Token
                ).GetAwaiter().GetResult()

                if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                    throw 'The browser DevTools endpoint closed the WebSocket connection unexpectedly.'
                }

                $null = $builder.Append([System.Text.Encoding]::UTF8.GetString($receiveBuffer, 0, $result.Count))
            } while (-not $result.EndOfMessage)

            $response = $builder.ToString() | ConvertFrom-Json -Depth 20
            if ($response.id -ne $requestId) {
                continue
            }

            if ($null -ne $response.error) {
                throw "Browser DevTools command '$Method' failed: $($response.error.message)"
            }

            return $response.result
        }
    } finally {
        $webSocket.Dispose()
        $cancellation.Dispose()
    }
}

function Get-M365BrowserCookieJar {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WebSocketUrl
    )

    $cookieResult = $null

    foreach ($method in @('Network.getAllCookies', 'Network.getCookies', 'Storage.getCookies')) {
        try {
            $result = Invoke-M365BrowserCdpCommand -WebSocketUrl $WebSocketUrl -Method $method
        } catch {
            continue
        }

        $cookieResult = @(
            @($result) | Where-Object {
                $_ -and $_.PSObject.Properties['cookies']
            }
        ) | Select-Object -Last 1

        if ($cookieResult) {
            break
        }
    }

    if ($null -eq $cookieResult -or $null -eq $cookieResult.cookies) {
        return @()
    }

    return @($cookieResult.cookies)
}

function Get-M365BestBrowserEstsCookie {
    [CmdletBinding()]
    param(
        [object[]]$Cookies
    )

    if ($null -eq $Cookies -or $Cookies.Count -eq 0) {
        return $null
    }

    $estsCookies = @($Cookies | Where-Object { $_.name -like 'ESTS*' -and $_.value })
    if (-not $estsCookies) {
        return $null
    }

    $preferenceRank = @{
        ESTSAUTH           = 0
        ESTSAUTHPERSISTENT = 1
        ESTSAUTHLIGHT      = 2
    }

    return $estsCookies |
        Sort-Object -Property @(
            @{ Expression = { if ($preferenceRank.ContainsKey([string]$_.name)) { $preferenceRank[[string]$_.name] } else { 99 } } },
            @{ Expression = { $_.value.Length }; Descending = $true }
        ) |
        Select-Object -First 1
}

function Get-M365BrowserCookieValue {
    [CmdletBinding()]
    param(
        [object[]]$Cookies,

        [Parameter(Mandatory)]
        [string]$Name,

        [string]$DomainLike
    )

    if ($null -eq $Cookies -or $Cookies.Count -eq 0) {
        return $null
    }

    $cookieMatches = @(
        $Cookies | Where-Object {
            $_.name -eq $Name -and
            $_.value -and
            (-not $DomainLike -or [string]$_.domain -like $DomainLike)
        }
    )

    if (-not $cookieMatches) {
        return $null
    }

    return ($cookieMatches | Select-Object -First 1).value
}

function New-M365BrowserPortalWebSession {
    [OutputType([Microsoft.PowerShell.Commands.WebRequestSession])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper that creates an in-memory WebRequestSession only.')]
    [CmdletBinding()]
    param(
        [object[]]$Cookies,

        [string]$UserAgent
    )

    $requiredCookieNames = 'RootAuthToken', 'SPAAuthCookie', 'OIDCAuthCookie', 's.AjaxSessionKey'
    $requiredCookieValues = @{}
    foreach ($cookieName in $requiredCookieNames) {
        $requiredCookieValues[$cookieName] = Get-M365BrowserCookieValue -Cookies $Cookies -Name $cookieName -DomainLike 'admin.cloud.microsoft'
    }

    $missingCookies = @($requiredCookieNames | Where-Object { [string]::IsNullOrWhiteSpace($requiredCookieValues[$_]) })
    if ($missingCookies.Count -gt 0) {
        return $null
    }

    $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    if ($UserAgent) {
        $session.UserAgent = $UserAgent
    }

    foreach ($cookieName in @('RootAuthToken', 'SPAAuthCookie', 'OIDCAuthCookie', 's.AjaxSessionKey', 's.SessID', 's.UserTenantId', 's.userid', 'x-portal-routekey', 'UserLoginRef')) {
        $cookieValue = Get-M365BrowserCookieValue -Cookies $Cookies -Name $cookieName -DomainLike 'admin.cloud.microsoft'
        if ([string]::IsNullOrWhiteSpace($cookieValue)) {
            continue
        }

        $session.Cookies.Add([System.Net.Cookie]::new($cookieName, $cookieValue, '/', 'admin.cloud.microsoft'))
    }

    return $session
}

function Invoke-M365BrowserAuthentication {
    <#
    .SYNOPSIS
        Launches a browser-driven sign-in flow and returns captured authentication artifacts.

    .DESCRIPTION
        This helper launches a dedicated Chromium-based browser profile, waits for the user to
        complete the sign-in, and reads the resulting cookies through the local DevTools protocol.

        When the Microsoft 365 admin portal session cookies are already present, those are
        returned so the caller can connect directly through the normal portal bootstrap path.
        ESTS authentication cookies are also captured when available as a fallback path.

        This is an internal function used by Connect-M365PortalByBrowser.

    .PARAMETER Username
        Optional username to display to the user while they complete the sign-in.

    .PARAMETER TenantId
        Optional tenant identifier to scope the Entra authorize prompt.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for the browser sign-in to complete.

    .PARAMETER BrowserPath
        Optional browser executable path or command name.

    .PARAMETER ProfilePath
        Optional dedicated browser profile path.

    .PARAMETER ResetProfile
        Clears the dedicated browser profile before launching the sign-in flow.

    .PARAMETER PrivateSession
        Uses a temporary private/incognito browser session instead of the default dedicated profile.

    .PARAMETER UserAgent
        Optional User-Agent override for the launched browser.

    .OUTPUTS
        PSCustomObject containing browser authentication artifacts.

    .EXAMPLE
        $cookie = Invoke-M365BrowserAuthentication -Username 'admin@contoso.com'

        Launches a supported browser, waits for sign-in to complete, and returns the captured browser authentication artifacts.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding()]
    param(
        [string]$Username,

        [string]$TenantId,

        [ValidateRange(30, 1800)]
        [int]$TimeoutSeconds = 300,

        [string]$BrowserPath,

        [string]$ProfilePath,

        [switch]$ResetProfile,

        [switch]$PrivateSession,

        [string]$UserAgent
    )

    $browser = Resolve-M365BrowserPath -BrowserPath $BrowserPath
    $debugPort = Get-M365BrowserFreeTcpPort
    $profileConfiguration = Resolve-M365BrowserProfileConfiguration -ProfilePath $ProfilePath -ResetProfile:$ResetProfile -PrivateSession:$PrivateSession
    $profileDirectory = $profileConfiguration.ProfilePath

    $browserProcess = $null

    try {
        $startUrl = Get-M365BrowserInteractiveStartUrl -Username $Username -TenantId $TenantId -UserAgent $UserAgent
        $arguments = Get-M365BrowserLaunchArgumentList -Browser $browser -UsePrivateSession:$profileConfiguration.UsePrivateSession -DebugPort $debugPort -ProfileDirectory $profileDirectory -StartUrl $startUrl -UserAgent $UserAgent

        Write-Host "Launching $($browser.Name) for browser sign-in..."
        if ($profileConfiguration.UsePrivateSession) {
            Write-Host 'Using a temporary private browser session.'
        } else {
            Write-Host "Using dedicated browser profile: $profileDirectory"
        }
        if ($Username) {
            Write-Host "Complete the sign-in in the browser with account: $Username"
        } else {
            Write-Host 'Complete the sign-in in the browser with the target account.'
        }

        $browserProcess = Start-Process -FilePath $browser.Path -ArgumentList $arguments -PassThru
        $versionInfo = Get-M365BrowserCdpVersion -Port $debugPort -TimeoutSeconds 20

        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $selectedEstsCookie = $null
        $selectedPortalWebSession = $null
        $portalCookieGraceDeadline = $null

        do {
            Start-Sleep -Seconds 2

            if ($browserProcess) {
                $browserProcess.Refresh()
                if ($browserProcess.HasExited) {
                    if ($selectedPortalWebSession -or $selectedEstsCookie) {
                        break
                    }

                    throw 'The browser window was closed before the browser sign-in completed.'
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
                $selectedEstsCookie = $currentEstsCookie
                if (-not $portalCookieGraceDeadline) {
                    $portalCookieGraceDeadline = (Get-Date).AddSeconds(10)
                    Write-Verbose 'Captured ESTS authentication cookie. Waiting briefly for the admin portal cookie set to appear before falling back to ESTS bootstrap.'
                }
            }

            $selectedPortalWebSession = New-M365BrowserPortalWebSession -Cookies $cookies -UserAgent $UserAgent

            if ($selectedPortalWebSession) {
                break
            }

            if ($selectedEstsCookie -and $portalCookieGraceDeadline -and (Get-Date) -ge $portalCookieGraceDeadline) {
                break
            }
        } while ((Get-Date) -lt $deadline)

        if (-not $selectedPortalWebSession -and -not $selectedEstsCookie) {
            throw 'Browser sign-in did not produce admin portal or ESTS authentication cookies before the timeout expired.'
        }

        if ($selectedPortalWebSession) {
            Write-Verbose 'Captured admin portal session cookies from the signed-in browser session.'
        } elseif ($selectedEstsCookie) {
            Write-Verbose 'Captured ESTS authentication cookie before the admin portal cookie set appeared. Continuing with ESTS cookie bootstrap.'
        }

        return [pscustomobject]@{
            EstsAuthCookieValue = if ($selectedEstsCookie) { $selectedEstsCookie.value } else { $null }
            PortalWebSession    = $selectedPortalWebSession
        }
    } finally {
        if ($browserProcess) {
            $browserProcess.Refresh()
            if (-not $browserProcess.HasExited) {
                Stop-Process -Id $browserProcess.Id -Force -ErrorAction SilentlyContinue
            }
        }

        if ($profileConfiguration.CleanupProfileOnExit) {
            Start-Sleep -Milliseconds 500
            Remove-Item -Path $profileDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
