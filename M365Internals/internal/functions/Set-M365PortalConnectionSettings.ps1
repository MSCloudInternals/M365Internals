function Set-M365PortalConnectionSettings {
    <#
    .SYNOPSIS
        Creates M365 admin portal connection settings from a web session.

    .DESCRIPTION
        Validates that a web session contains the cookie set required by admin.cloud.microsoft,
        composes the default request headers used by the portal, optionally validates the session
        against the portal bootstrap endpoints, and stores the session for later requests.

    .PARAMETER WebSession
        The authenticated web session to register for portal requests.

    .PARAMETER AuthSource
        A short label describing how the session was obtained.

    .PARAMETER AuthFlow
        A short label describing the higher-level authentication flow that established the session.

    .PARAMETER UserAgent
        The user agent to set on the session when provided.

    .PARAMETER SkipValidation
        Skips the bootstrap endpoint validation probes.

    .EXAMPLE
        Set-M365PortalConnectionSettings -WebSession $session -AuthSource 'PortalCookies'

        Registers an authenticated admin portal session created from browser cookies.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'ConnectionSettings is singular by design')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates session state only for the current PowerShell session')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [string]$AuthSource = 'PortalCookies',

        [string]$AuthFlow,

        [string]$UserAgent,

        [switch]$SkipValidation
    )

    function Get-PortalCookieValue {
        param (
            [Parameter(Mandatory)]
            [string]$Name
        )

        foreach ($cookieUri in @('https://admin.cloud.microsoft/', 'https://admin.cloud.microsoft/adminportal')) {
            $portalCookies = $WebSession.Cookies.GetCookies($cookieUri)
            $cookie = $portalCookies | Where-Object Name -eq $Name | Select-Object -First 1
            if ($cookie) {
                return $cookie.Value
            }
        }
    }

    function Sync-PortalCookieValues {
        foreach ($cookieName in @('RootAuthToken', 'SPAAuthCookie', 'OIDCAuthCookie', 's.AjaxSessionKey', 's.SessID', 's.UserTenantId', 's.userid', 'x-portal-routekey', 'UserLoginRef')) {
            $cookieValues[$cookieName] = Get-PortalCookieValue -Name $cookieName
        }
    }

    function Update-PortalHeaderState {
        if ([string]::IsNullOrWhiteSpace($cookieValues['s.AjaxSessionKey'])) {
            $null = $script:m365PortalHeaders.Remove('AjaxSessionKey')
        }
        else {
            $script:m365PortalHeaders['AjaxSessionKey'] = $cookieValues['s.AjaxSessionKey']
        }

        if ([string]::IsNullOrWhiteSpace($cookieValues['x-portal-routekey'])) {
            $null = $script:m365PortalHeaders.Remove('x-portal-routekey')
        }
        else {
            $script:m365PortalHeaders['x-portal-routekey'] = $cookieValues['x-portal-routekey']
        }
    }

    function Resolve-TenantIdFromContent {
        param (
            [string]$Content
        )

        if ([string]::IsNullOrWhiteSpace($Content)) {
            return $null
        }

        foreach ($pattern in @(
            'O365\.TID=\\"(?<value>[0-9a-fA-F-]{36})\\"',
            'O365\.TID="(?<value>[0-9a-fA-F-]{36})"',
            '\\"TID\\":\\"(?<value>[0-9a-fA-F-]{36})\\"',
            '"TID":"(?<value>[0-9a-fA-F-]{36})"'
        )) {
            $match = [regex]::Match($Content, $pattern)
            if ($match.Success) {
                return $match.Groups['value'].Value
            }
        }

        return $null
    }

    function Resolve-UsernameFromCookieValue {
        param (
            [string]$Value
        )

        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $null
        }

        try {
            return [uri]::UnescapeDataString(($Value -replace '\+', ' '))
        }
        catch {
            return $Value
        }
    }

    function Test-IsGuidValue {
        param (
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$Value
        )

        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $false
        }

        return ($Value -match '^[0-9a-fA-F-]{36}$')
    }

    function Test-IsUnexpectedHtmlBootstrapShell {
        param (
            [string]$Content
        )

        if ([string]::IsNullOrWhiteSpace($Content)) {
            return $false
        }

        $trimmedContent = $Content.TrimStart()
        if (-not $trimmedContent.StartsWith('<')) {
            return $false
        }

        if ($Content -match 'O365\.TID=' -or
            $Content -match '\$Config\s*=\s*\{' -or
            $Content -match '"TID"\s*:\s*"?[0-9a-fA-F-]{36}') {
            return $false
        }

        return $true
    }

    function Get-BootstrapFailureDetails {
        $bootstrapState = $script:m365PortalLastBootstrapState
        if (-not $bootstrapState) {
            return ''
        }

        if ($bootstrapState.PSObject.Properties['LogClientAttempted'] -and $bootstrapState.LogClientAttempted -and
            $bootstrapState.PSObject.Properties['LogClientSucceeded'] -and -not $bootstrapState.LogClientSucceeded -and
            -not [string]::IsNullOrWhiteSpace([string]$bootstrapState.LogClientError)) {
            return " The preceding logclient bootstrap request also failed: $($bootstrapState.LogClientError)"
        }

        if ($bootstrapState.PSObject.Properties['AjaxSessionKeyPresent'] -and -not $bootstrapState.AjaxSessionKeyPresent) {
            return ' The bootstrap retry did not have an s.AjaxSessionKey cookie to replay the expected follow-up requests.'
        }

        return ''
    }

    function Invoke-ValidatedBootstrapProbe {
        param (
            [Parameter(Mandatory)]
            [string]$ProbeName,

            [Parameter(Mandatory)]
            [string]$Path,

            [hashtable]$Headers,

            [switch]$RetryOnHtmlShell
        )

        $attempt = 0

        while ($true) {
            $attempt++
            $response = Invoke-M365PortalRequest -Path $Path -Headers $Headers -RawResponse

            if (-not (Test-IsUnexpectedHtmlBootstrapShell -Content $response.Content)) {
                return $response
            }

            if ($RetryOnHtmlShell -and $attempt -lt 2) {
                Write-Verbose "The $ProbeName validation probe returned the admin portal HTML shell. Replaying the post-landing bootstrap and retrying once."

                try {
                    $null = Invoke-M365PortalPostLandingBootstrap -WebSession $WebSession -UserAgent $UserAgent
                }
                catch {
                    Write-Verbose "The retry bootstrap attempt after the $ProbeName HTML shell did not complete successfully: $($_.Exception.Message)"
                }

                Sync-PortalCookieValues
                if (-not [string]::IsNullOrWhiteSpace($cookieValues['x-portal-routekey'])) {
                    $script:m365PortalHeaders['x-portal-routekey'] = $cookieValues['x-portal-routekey']
                }

                continue
            }

            throw ("Connected to admin.cloud.microsoft, but the {0} validation probe returned the admin portal HTML error shell instead of bootstrap data.{1}" -f $ProbeName, (Get-BootstrapFailureDetails))
        }
    }

    if ($UserAgent) {
        $WebSession.UserAgent = $UserAgent
    }

    $requiredCookieNames = 'RootAuthToken', 'SPAAuthCookie', 'OIDCAuthCookie'
    $cookieValues = @{}
    Sync-PortalCookieValues

    $missingCookies = @($requiredCookieNames | Where-Object { [string]::IsNullOrWhiteSpace($cookieValues[$_]) })
    if ($missingCookies.Count -gt 0) {
        throw "The web session is missing required admin.cloud.microsoft cookies: $($missingCookies -join ', ')."
    }

    $previousSession = $script:m365PortalSession
    $previousHeaders = $script:m365PortalHeaders
    $previousConnection = $script:m365PortalConnection
    $previousBootstrapState = $script:m365PortalLastBootstrapState
    $script:m365PortalLastBootstrapState = $null

    $script:m365PortalSession = $WebSession
    $script:m365PortalHeaders = @{
        Accept         = 'application/json, text/plain, */*'
    }
    Update-PortalHeaderState

    if ([string]::IsNullOrWhiteSpace($cookieValues['s.AjaxSessionKey']) -or
        $cookieValues['UserLoginRef'] -ne '%2Fhomepage' -or
        [string]::IsNullOrWhiteSpace($cookieValues['s.UserTenantId']) -or
        [string]::IsNullOrWhiteSpace($cookieValues['x-portal-routekey'])) {
        try {
            $null = Invoke-M365PortalPostLandingBootstrap -WebSession $WebSession -UserAgent $UserAgent
        }
        catch {
            Write-Verbose "The first optional post-landing bootstrap attempt did not complete successfully: $($_.Exception.Message)"
        }

        Sync-PortalCookieValues
        Update-PortalHeaderState
    }

    if ([string]::IsNullOrWhiteSpace($cookieValues['s.AjaxSessionKey']) -or
        [string]::IsNullOrWhiteSpace($cookieValues['s.UserTenantId'])) {
        try {
            $null = Invoke-M365PortalPostLandingBootstrap -WebSession $WebSession -UserAgent $UserAgent
        }
        catch {
            Write-Verbose "The second optional post-landing bootstrap attempt did not complete successfully: $($_.Exception.Message)"
        }

        Sync-PortalCookieValues
        Update-PortalHeaderState

        try {
            if ([string]::IsNullOrWhiteSpace($cookieValues['s.UserTenantId'])) {
                $null = Invoke-WebRequest -MaximumRedirection 20 -ErrorAction Stop -WebSession $WebSession -Method Get -Uri 'https://admin.cloud.microsoft/admin/api/tenant/datalocationandcommitments' -Headers (Get-M365PortalContextHeaders -Context DataLocation -AjaxSessionKey $script:m365PortalHeaders['AjaxSessionKey']) -UserAgent $UserAgent
            }
        }
        catch {
            Write-Verbose "The optional data-location bootstrap validation request did not complete successfully: $($_.Exception.Message)"
        }

        if ([string]::IsNullOrWhiteSpace((Get-PortalCookieValue -Name 's.UserTenantId'))) {
            try {
                $null = Invoke-WebRequest -MaximumRedirection 20 -ErrorAction Stop -WebSession $WebSession -Method Get -Uri 'https://admin.cloud.microsoft/adminportal/home/ClassicModernAdminDataStream?ref=/homepage' -Headers (Get-M365PortalContextHeaders -Context Homepage -AjaxSessionKey $script:m365PortalHeaders['AjaxSessionKey']) -UserAgent $UserAgent
            }
            catch {
                Write-Verbose "The optional ClassicModernAdminDataStream validation request did not complete successfully: $($_.Exception.Message)"
            }
        }

        Sync-PortalCookieValues
        Update-PortalHeaderState
    }

    $validationResults = New-Object System.Collections.Generic.List[object]
    $resolvedTenantId = if (Test-IsGuidValue -Value $cookieValues['s.UserTenantId']) {
        $cookieValues['s.UserTenantId']
    }
    elseif ($previousConnection -and (Test-IsGuidValue -Value $previousConnection.TenantId)) {
        $previousConnection.TenantId
    }
    else {
        $null
    }
    try {
        if (-not $SkipValidation) {
            $classicModernResponse = Invoke-ValidatedBootstrapProbe -ProbeName 'ClassicModernAdminDataStream' -Path '/adminportal/home/ClassicModernAdminDataStream?ref=/homepage' -Headers (Get-M365PortalContextHeaders -Context Homepage) -RetryOnHtmlShell
            if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) {
                $resolvedTenantId = Resolve-TenantIdFromContent -Content $classicModernResponse.Content
            }

            Sync-PortalCookieValues
            if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) {
                $resolvedTenantId = $cookieValues['s.UserTenantId']
            }

            Update-PortalHeaderState

            $validationResults.Add([pscustomobject]@{
                Name       = 'ClassicModernAdminDataStream'
                Path       = '/adminportal/home/ClassicModernAdminDataStream?ref=/homepage'
                StatusCode = [int]$classicModernResponse.StatusCode
            })

            try {
                $shellInfoResponse = Invoke-ValidatedBootstrapProbe -ProbeName 'ShellInfo' -Path '/admin/api/coordinatedbootstrap/shellinfo' -Headers (Get-M365PortalContextHeaders -Context Homepage) -RetryOnHtmlShell
                if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) {
                    $resolvedTenantId = Resolve-TenantIdFromContent -Content $shellInfoResponse.Content
                }
                $validationResults.Add([pscustomobject]@{
                    Name       = 'ShellInfo'
                    Path       = '/admin/api/coordinatedbootstrap/shellinfo'
                    StatusCode = [int]$shellInfoResponse.StatusCode
                })

                if (-not [string]::IsNullOrWhiteSpace($shellInfoResponse.Content)) {
                    $cacheTenantId = if (-not [string]::IsNullOrWhiteSpace($resolvedTenantId)) { $resolvedTenantId } elseif (Test-IsGuidValue -Value $cookieValues['s.UserTenantId']) { $cookieValues['s.UserTenantId'] } else { $null }
                    $null = Set-M365Cache -CacheKey 'ShellInfo' -Value $shellInfoResponse.Content -TTLMinutes 15 -TenantId $cacheTenantId
                }
            }
            catch {
                $validationResults.Add([pscustomobject]@{
                    Name       = 'ShellInfo'
                    Path       = '/admin/api/coordinatedbootstrap/shellinfo'
                    StatusCode = $null
                    Error      = $_.Exception.Message
                })
            }

            foreach ($validationProbe in @(
                @{ Name = 'Navigation'; Path = '/admin/api/navigation' },
                @{ Name = 'FeatureAll'; Path = '/admin/api/features/all' }
            )) {
                try {
                    $probeResponse = Invoke-M365PortalRequest -Path $validationProbe.Path -RawResponse
                    $validationResults.Add([pscustomobject]@{
                        Name       = $validationProbe.Name
                        Path       = $validationProbe.Path
                        StatusCode = [int]$probeResponse.StatusCode
                    })
                }
                catch {
                    $validationResults.Add([pscustomobject]@{
                        Name       = $validationProbe.Name
                        Path       = $validationProbe.Path
                        StatusCode = $null
                        Error      = $_.Exception.Message
                    })
                }
            }

            if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) {
                throw 'Connected to admin.cloud.microsoft, but failed to resolve the active tenant ID from the validated portal bootstrap responses.'
            }
        }

        Sync-PortalCookieValues
        Update-PortalHeaderState
        if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) {
            if (Test-IsGuidValue -Value $cookieValues['s.UserTenantId']) {
                $resolvedTenantId = $cookieValues['s.UserTenantId']
            }
            elseif ($previousConnection -and (Test-IsGuidValue -Value $previousConnection.TenantId)) {
                $resolvedTenantId = $previousConnection.TenantId
            }
        }

        $resolvedAuthFlow = if (-not [string]::IsNullOrWhiteSpace($AuthFlow)) {
            $AuthFlow
        }
        elseif ($previousConnection -and $previousConnection.PSObject.Properties['AuthFlow'] -and -not [string]::IsNullOrWhiteSpace([string]$previousConnection.AuthFlow)) {
            [string]$previousConnection.AuthFlow
        }
        else {
            $AuthSource
        }

        $resolvedUsername = Resolve-UsernameFromCookieValue -Value $cookieValues['s.userid']

        $connection = [System.Management.Automation.PSObject]::new()
        $connection | Add-Member -NotePropertyName PortalHost -NotePropertyValue 'admin.cloud.microsoft'
        $connection | Add-Member -NotePropertyName TenantId -NotePropertyValue $resolvedTenantId
        # Keep both property names: Username is canonical, while UserId preserves the
        # historical field used by existing callers and the default connection view.
        $connection | Add-Member -NotePropertyName Username -NotePropertyValue $resolvedUsername
        $connection | Add-Member -NotePropertyName UserId -NotePropertyValue $resolvedUsername
        $connection | Add-Member -NotePropertyName SessionId -NotePropertyValue $cookieValues['s.SessID']
        $connection | Add-Member -NotePropertyName RouteKeyPresent -NotePropertyValue (-not [string]::IsNullOrWhiteSpace($cookieValues['x-portal-routekey']))
        $connection | Add-Member -NotePropertyName Source -NotePropertyValue $AuthSource
        $connection | Add-Member -NotePropertyName AuthFlow -NotePropertyValue $resolvedAuthFlow
        $connection | Add-Member -NotePropertyName ConnectedAt -NotePropertyValue (Get-Date)
        $connection | Add-Member -NotePropertyName Validated -NotePropertyValue (-not $SkipValidation)
        $connection | Add-Member -NotePropertyName Validation -NotePropertyValue ([object[]]$validationResults.ToArray())
        $connection.PSObject.TypeNames.Insert(0, 'M365Portal.Connection')

        $script:m365PortalConnection = $connection
        $connection
    }
    catch {
        $script:m365PortalSession = $previousSession
        $script:m365PortalHeaders = $previousHeaders
        $script:m365PortalConnection = $previousConnection
        $script:m365PortalLastBootstrapState = $previousBootstrapState
        throw
    }
}
