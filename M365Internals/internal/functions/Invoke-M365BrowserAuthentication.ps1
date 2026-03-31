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

function Get-M365MacOSBrowserCandidateSet {
    [OutputType([object[]])]
    [CmdletBinding()]
    param()

    $candidateSet = @(
        [pscustomobject]@{ Name = 'Microsoft Edge'; CommandName = 'msedge' }
        [pscustomobject]@{ Name = 'Google Chrome'; CommandName = 'google-chrome' }
        [pscustomobject]@{ Name = 'Brave Browser'; CommandName = 'brave-browser' }
        [pscustomobject]@{ Name = 'Brave Browser'; CommandName = 'brave' }
        [pscustomobject]@{ Name = 'Chromium'; CommandName = 'chromium' }
    )

    foreach ($applicationRoot in @('/Applications', (Join-Path $HOME 'Applications'))) {
        $candidateSet += @(
            [pscustomobject]@{ Name = 'Microsoft Edge'; FilePath = (Join-Path $applicationRoot 'Microsoft Edge.app/Contents/MacOS/Microsoft Edge') }
            [pscustomobject]@{ Name = 'Google Chrome'; FilePath = (Join-Path $applicationRoot 'Google Chrome.app/Contents/MacOS/Google Chrome') }
            [pscustomobject]@{ Name = 'Brave Browser'; FilePath = (Join-Path $applicationRoot 'Brave Browser.app/Contents/MacOS/Brave Browser') }
            [pscustomobject]@{ Name = 'Chromium'; FilePath = (Join-Path $applicationRoot 'Chromium.app/Contents/MacOS/Chromium') }
        )
    }

    return $candidateSet
}

function Resolve-M365MacOSBrowserPath {
    [CmdletBinding()]
    param()

    $match = Resolve-M365BrowserPathFromCandidateSet -Candidates (Get-M365MacOSBrowserCandidateSet)

    if ($match) {
        return $match
    }

    throw 'No supported Chromium-based browser was found on macOS. Install Microsoft Edge, Google Chrome, Brave, Chromium, or specify -BrowserPath.'
}

function Resolve-M365MacOSAppBundleExecutablePath {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BundlePath
    )

    $resolvedBundlePath = (Resolve-Path -LiteralPath $BundlePath).ProviderPath
    $bundleName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedBundlePath)
    $macOsPath = Join-Path $resolvedBundlePath 'Contents/MacOS'

    if (-not (Test-Path -LiteralPath $macOsPath -PathType Container)) {
        throw "Browser application bundle '$BundlePath' does not contain a Contents/MacOS executable directory."
    }

    $candidateExecutables = @(Get-ChildItem -LiteralPath $macOsPath -File -ErrorAction Stop)
    if (-not $candidateExecutables) {
        throw "Browser application bundle '$BundlePath' does not contain an executable in Contents/MacOS."
    }

    $preferredExecutable = @(
        $candidateExecutables | Where-Object { $_.Name -eq $bundleName }
        $candidateExecutables
    ) | Where-Object { $_ } | Select-Object -First 1

    return [pscustomobject]@{
        Path = $preferredExecutable.FullName
        Name = $preferredExecutable.Name
    }
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
        if ($IsMacOS -and $BrowserPath -like '*.app' -and (Test-Path -LiteralPath $BrowserPath -PathType Container)) {
            return Resolve-M365MacOSAppBundleExecutablePath -BundlePath $BrowserPath
        }

        if (Test-Path -LiteralPath $BrowserPath -PathType Leaf) {
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

function Get-M365BrowserProfileDirectoryName {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    return 'M365Internals'
}

function Get-M365BrowserNamedProfilePath {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserDataDirectory
    )

    return Join-Path $UserDataDirectory (Get-M365BrowserProfileDirectoryName)
}

function ConvertTo-M365BrowserJsonConfigurationObject {
    [OutputType([object], [hashtable], [object[]])]
    [CmdletBinding()]
    param(
        $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-M365BrowserJsonConfigurationObject -InputObject $InputObject[$key]
        }

        return $result
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return @(
            foreach ($item in $InputObject) {
                ConvertTo-M365BrowserJsonConfigurationObject -InputObject $item
            }
        )
    }

    if ($InputObject.PSObject -and $InputObject.PSObject.Properties.Count -gt 0 -and $InputObject -isnot [string]) {
        $result = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-M365BrowserJsonConfigurationObject -InputObject $property.Value
        }

        return $result
    }

    return $InputObject
}

function Read-M365BrowserJsonConfigurationFile {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @{}
    }

    $content = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($content)) {
        return @{}
    }

    return [hashtable](ConvertTo-M365BrowserJsonConfigurationObject -InputObject ($content | ConvertFrom-Json -Depth 100))
}

function Set-M365BrowserJsonConfigurationValue {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper that mutates an in-memory browser configuration object before serialization.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Configuration,

        [Parameter(Mandatory)]
        [string[]]$Path,

        $Value
    )

    $current = $Configuration
    for ($index = 0; $index -lt ($Path.Count - 1); $index++) {
        $pathSegment = $Path[$index]

        if (-not $current.Contains($pathSegment) -or $null -eq $current[$pathSegment] -or $current[$pathSegment] -isnot [System.Collections.IDictionary]) {
            $current[$pathSegment] = @{}
        }

        $current = [System.Collections.IDictionary]$current[$pathSegment]
    }

    $current[$Path[-1]] = $Value
}

function Write-M365BrowserJsonConfigurationFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Configuration
    )

    $parentPath = Split-Path -Path $Path -Parent
    if ($parentPath -and -not (Test-Path -LiteralPath $parentPath -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $parentPath -Force
    }

    $Configuration | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
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

    $legacyDefaultProfilePath = Join-Path $ProfilePath 'Default'
    $namedProfilePath = Get-M365BrowserNamedProfilePath -UserDataDirectory $ProfilePath
    if (-not (Test-Path -LiteralPath $namedProfilePath -PathType Container)) {
        if (Test-Path -LiteralPath $legacyDefaultProfilePath -PathType Container) {
            Move-Item -LiteralPath $legacyDefaultProfilePath -Destination $namedProfilePath -Force
        }
        else {
            $null = New-Item -ItemType Directory -Path $namedProfilePath -Force
        }
    }

    $profileDirectoryName = Get-M365BrowserProfileDirectoryName
    $localStatePath = Join-Path $ProfilePath 'Local State'
    $localState = Read-M365BrowserJsonConfigurationFile -Path $localStatePath
    Set-M365BrowserJsonConfigurationValue -Configuration $localState -Path @('profile', 'last_used') -Value $profileDirectoryName
    Write-M365BrowserJsonConfigurationFile -Path $localStatePath -Configuration $localState

    $preferencesPath = Join-Path $namedProfilePath 'Preferences'
    $preferences = Read-M365BrowserJsonConfigurationFile -Path $preferencesPath
    Set-M365BrowserJsonConfigurationValue -Configuration $preferences -Path @('sync', 'requested') -Value $false
    Set-M365BrowserJsonConfigurationValue -Configuration $preferences -Path @('signin', 'allowed') -Value $true
    Set-M365BrowserJsonConfigurationValue -Configuration $preferences -Path @('browser', 'has_seen_welcome_page') -Value $true
    Set-M365BrowserJsonConfigurationValue -Configuration $preferences -Path @('profile', 'name') -Value $profileDirectoryName
    Set-M365BrowserJsonConfigurationValue -Configuration $preferences -Path @('profile', 'exit_type') -Value 'Normal'
    Set-M365BrowserJsonConfigurationValue -Configuration $preferences -Path @('session', 'restore_on_startup') -Value 5
    Set-M365BrowserJsonConfigurationValue -Configuration $preferences -Path @('session', 'startup_urls') -Value @()
    Write-M365BrowserJsonConfigurationFile -Path $preferencesPath -Configuration $preferences
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

            if ($argument -match '^(--[^=]+=)(.*)$') {
                $argumentPrefix = $Matches[1]
                $argumentValue = $Matches[2]

                if ($argumentValue -match '[\s"]') {
                    $escapedValue = $argumentValue.Replace('"', '\"')
                    $argumentPrefix + '"' + $escapedValue + '"'
                    continue
                }

                $argument
                continue
            }

            if ($argument -match '[\s"]') {
                $escapedArgument = $argument.Replace('"', '\"')
                '"' + $escapedArgument + '"'
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
        "--profile-directory=$(Get-M365BrowserProfileDirectoryName)",
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

    return [string[]]($arguments + @($StartUrl))
}

function Start-M365BrowserProcess {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper that launches the browser process for authentication.')]
    [OutputType([System.Diagnostics.Process])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BrowserPath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [switch]$SuppressBrowserOutput
    )

    $formattedArgumentList = Format-M365BrowserProcessArgumentList -Arguments $ArgumentList

    if ($SuppressBrowserOutput -and -not $IsWindows) {
        $redirectConfiguration = New-M365BrowserProcessRedirectConfiguration
        $process = Start-Process -FilePath $BrowserPath -ArgumentList $formattedArgumentList -PassThru -RedirectStandardOutput $redirectConfiguration.StandardOutputPath -RedirectStandardError $redirectConfiguration.StandardErrorPath
        $null = $process | Add-Member -NotePropertyName StandardOutputPath -NotePropertyValue $redirectConfiguration.StandardOutputPath -PassThru
        $null = $process | Add-Member -NotePropertyName StandardErrorPath -NotePropertyValue $redirectConfiguration.StandardErrorPath -PassThru
        return $process
    }

    return Start-Process -FilePath $BrowserPath -ArgumentList $formattedArgumentList -PassThru
}

function New-M365BrowserProcessRedirectConfiguration {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper that allocates temporary redirect file paths for browser process output.')]
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param()

    $temporaryPath = [System.IO.Path]::GetTempPath()

    return [pscustomobject]@{
        StandardOutputPath = [System.IO.Path]::Combine($temporaryPath, ('m365-browser-stdout-' + [guid]::NewGuid().ToString('N') + '.log'))
        StandardErrorPath  = [System.IO.Path]::Combine($temporaryPath, ('m365-browser-stderr-' + [guid]::NewGuid().ToString('N') + '.log'))
    }
}

function Remove-M365BrowserProcessRedirectFiles {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper that cleans up temporary redirect files created for browser process output.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Private helper operates on the redirect file set attached to a process object.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Process
    )

    $redirectPaths = @()

    if ($Process.PSObject.Properties['StandardOutputPath']) {
        $redirectPaths += [string]$Process.StandardOutputPath
    }

    if ($Process.PSObject.Properties['StandardErrorPath']) {
        $redirectPaths += [string]$Process.StandardErrorPath
    }

    foreach ($redirectPath in ($redirectPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        Remove-Item -LiteralPath $redirectPath -Force -ErrorAction SilentlyContinue
    }
}

function Wait-M365BrowserProcessExit {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Process,

        [int]$TimeoutMilliseconds = 5000
    )

    if ($Process.PSObject.Methods.Name -contains 'WaitForExit') {
        return [bool]$Process.WaitForExit($TimeoutMilliseconds)
    }

    $deadline = (Get-Date).AddMilliseconds($TimeoutMilliseconds)
    do {
        Start-Sleep -Milliseconds 100

        if ($Process.PSObject.Methods.Name -contains 'Refresh') {
            $Process.Refresh()
        }

        if ($Process.HasExited) {
            return $true
        }
    } while ((Get-Date) -lt $deadline)

    return $false
}

function Stop-M365BrowserProcess {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper that closes the dedicated browser process launched for authentication.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Process,

        [string]$BrowserWebSocketUrl,

        [int]$CloseTimeoutMilliseconds = 5000
    )

    if ($Process.PSObject.Methods.Name -contains 'Refresh') {
        $Process.Refresh()
    }

    if ($Process.HasExited) {
        return
    }

    if ($BrowserWebSocketUrl) {
        try {
            $null = Invoke-M365BrowserCdpCommand -WebSocketUrl $BrowserWebSocketUrl -Method 'Browser.close'
        }
        catch {
            Write-Verbose "Graceful browser shutdown failed: $($_.Exception.Message)"
        }

        if (Wait-M365BrowserProcessExit -Process $Process -TimeoutMilliseconds $CloseTimeoutMilliseconds) {
            return
        }
    }

    if ($Process.PSObject.Methods.Name -contains 'Refresh') {
        $Process.Refresh()
    }

    if ($Process.HasExited) {
        return
    }

    Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    $null = Wait-M365BrowserProcessExit -Process $Process -TimeoutMilliseconds 1000
}

function Test-M365BrowserProcessOutputSuppression {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    return (-not $IsWindows) -and ($VerbosePreference -ne [System.Management.Automation.ActionPreference]::Continue)
}

function Test-M365BrowserAuthenticationCompletion {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Microsoft.PowerShell.Commands.WebRequestSession]$PortalWebSession,

        [object]$EstsCookie,

        [Nullable[datetime]]$FirstEstsCookieObservedAt,

        [datetime]$Deadline,

        [int]$PortalCookieGracePeriodSeconds = 10
    )

    if ($PortalWebSession) {
        return $true
    }

    if (-not $EstsCookie -or -not $FirstEstsCookieObservedAt) {
        return $false
    }

    $portalCookieGraceDeadline = ([datetime]$FirstEstsCookieObservedAt).AddSeconds($PortalCookieGracePeriodSeconds)
    if ($portalCookieGraceDeadline -gt $Deadline) {
        $portalCookieGraceDeadline = $Deadline
    }

    return (Get-Date) -ge $portalCookieGraceDeadline
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

function Get-M365BrowserPreferredTargetContext {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Port,

        [string]$FallbackWebSocketUrl
    )

    try {
        $targets = @(Get-M365BrowserTargetList -Port $Port)
    }
    catch {
        return [pscustomobject]@{
            Url          = $null
            Title        = $null
            Type         = $null
            WebSocketUrl = $FallbackWebSocketUrl
        }
    }

    $preferredTarget = @(
        $targets | Where-Object { $_.type -eq 'page' -and $_.url -like 'https://admin.cloud.microsoft/*' -and $_.webSocketDebuggerUrl }
        $targets | Where-Object { $_.type -eq 'page' -and $_.url -like 'https://login.microsoftonline.com/*' -and $_.webSocketDebuggerUrl }
        $targets | Where-Object { $_.type -eq 'page' -and $_.webSocketDebuggerUrl }
    ) | Where-Object { $_ } | Select-Object -First 1

    if (-not $preferredTarget) {
        return [pscustomobject]@{
            Url          = $null
            Title        = $null
            Type         = $null
            WebSocketUrl = $FallbackWebSocketUrl
        }
    }

    return [pscustomobject]@{
        Url          = [string]$preferredTarget.url
        Title        = [string]$preferredTarget.title
        Type         = [string]$preferredTarget.type
        WebSocketUrl = [string]$preferredTarget.webSocketDebuggerUrl
    }
}

function Format-M365BrowserTargetDescription {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [string]$Url,

        [string]$Title
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($Title)) {
        return $Url
    }

    return "$Title [$Url]"
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
    $browserWebSocketUrl = $null

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

        $browserProcess = Start-M365BrowserProcess -BrowserPath $browser.Path -ArgumentList $arguments -SuppressBrowserOutput:(Test-M365BrowserProcessOutputSuppression)
        $versionInfo = Get-M365BrowserCdpVersion -Port $debugPort -TimeoutSeconds 20
        $browserWebSocketUrl = $versionInfo.webSocketDebuggerUrl

        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $selectedEstsCookie = $null
        $selectedPortalWebSession = $null
        $firstEstsCookieObservedAt = $null
        $lastObservedTargetDescription = $null

        do {
            Start-Sleep -Seconds 2

            if ($browserProcess) {
                $browserProcess.Refresh()
                if ($browserProcess.HasExited) {
                    if ($selectedPortalWebSession -or $selectedEstsCookie) {
                        break
                    }

                    $message = 'The browser window was closed before the browser sign-in completed.'
                    if ($lastObservedTargetDescription) {
                        $message += " Last observed browser page: $lastObservedTargetDescription"
                    }

                    throw $message
                }
            }

            try {
                $targetContext = Get-M365BrowserPreferredTargetContext -Port $debugPort -FallbackWebSocketUrl $browserWebSocketUrl
                $browserWebSocketUrl = $targetContext.WebSocketUrl
                $currentTargetDescription = Format-M365BrowserTargetDescription -Url $targetContext.Url -Title $targetContext.Title
                if ($currentTargetDescription -and $currentTargetDescription -ne $lastObservedTargetDescription) {
                    $lastObservedTargetDescription = $currentTargetDescription
                    Write-Verbose "Observed browser page: $currentTargetDescription"
                }

                $cookies = @(Get-M365BrowserCookieJar -WebSocketUrl $browserWebSocketUrl)
            } catch {
                Write-Verbose "Cookie polling failed: $($_.Exception.Message)"
                continue
            }

            $currentEstsCookie = Get-M365BestBrowserEstsCookie -Cookies $cookies
            if ($currentEstsCookie) {
                $selectedEstsCookie = $currentEstsCookie
                if (-not $firstEstsCookieObservedAt) {
                    $firstEstsCookieObservedAt = Get-Date
                    Write-Verbose 'Captured ESTS authentication cookie. Waiting briefly for the admin portal cookie set to appear before falling back to ESTS bootstrap.'
                }
            }

            $selectedPortalWebSession = New-M365BrowserPortalWebSession -Cookies $cookies -UserAgent $UserAgent

            if (Test-M365BrowserAuthenticationCompletion -PortalWebSession $selectedPortalWebSession -EstsCookie $selectedEstsCookie -FirstEstsCookieObservedAt $firstEstsCookieObservedAt -Deadline $deadline) {
                break
            }
        } while ((Get-Date) -lt $deadline)

        if (-not $selectedPortalWebSession -and -not $selectedEstsCookie) {
            $message = 'Browser sign-in did not produce admin portal or ESTS authentication cookies before the timeout expired.'
            if ($lastObservedTargetDescription) {
                $message += " Last observed browser page: $lastObservedTargetDescription"
            }

            throw $message
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
            Stop-M365BrowserProcess -Process $browserProcess -BrowserWebSocketUrl $browserWebSocketUrl
            Remove-M365BrowserProcessRedirectFiles -Process $browserProcess
        }

        if ($profileConfiguration.CleanupProfileOnExit) {
            Start-Sleep -Milliseconds 500
            Remove-Item -LiteralPath $profileDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
