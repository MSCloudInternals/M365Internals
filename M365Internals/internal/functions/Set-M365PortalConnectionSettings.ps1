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

    if ($UserAgent) {
        $WebSession.UserAgent = $UserAgent
    }

    $requiredCookieNames = 'RootAuthToken', 'SPAAuthCookie', 'OIDCAuthCookie', 's.AjaxSessionKey'
    $cookieValues = @{}
    Sync-PortalCookieValues

    $missingCookies = @($requiredCookieNames | Where-Object { [string]::IsNullOrWhiteSpace($cookieValues[$_]) })
    if ($missingCookies.Count -gt 0) {
        throw "The web session is missing required admin.cloud.microsoft cookies: $($missingCookies -join ', ')."
    }

    $previousSession = $script:m365PortalSession
    $previousHeaders = $script:m365PortalHeaders
    $previousConnection = $script:m365PortalConnection

    $script:m365PortalSession = $WebSession
    $script:m365PortalHeaders = @{
        AjaxSessionKey = $cookieValues['s.AjaxSessionKey']
        Accept         = 'application/json, text/plain, */*'
    }
    if (-not [string]::IsNullOrWhiteSpace($cookieValues['x-portal-routekey'])) {
        $script:m365PortalHeaders['x-portal-routekey'] = $cookieValues['x-portal-routekey']
    }

    if ($cookieValues['UserLoginRef'] -ne '%2Fhomepage') {
        try {
            $null = Invoke-WebRequest -MaximumRedirection 20 -ErrorAction Stop -WebSession $WebSession -Method Get -Uri 'https://admin.cloud.microsoft/login?ru=%2Fadminportal%3Fref%3D%2Fhomepage' -Headers @{
                Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
            } -UserAgent $UserAgent
        }
        catch {
        }

        Sync-PortalCookieValues
    }

    if ([string]::IsNullOrWhiteSpace($cookieValues['s.UserTenantId'])) {
        try {
            $null = Invoke-M365PortalPostLandingBootstrap -WebSession $WebSession -UserAgent $UserAgent
        }
        catch {
        }

        Sync-PortalCookieValues

        try {
            if ([string]::IsNullOrWhiteSpace($cookieValues['s.UserTenantId'])) {
                $null = Invoke-WebRequest -MaximumRedirection 20 -ErrorAction Stop -WebSession $WebSession -Method Get -Uri 'https://admin.cloud.microsoft/admin/api/tenant/datalocationandcommitments' -Headers (Get-M365PortalContextHeaders -Context DataLocation -AjaxSessionKey $script:m365PortalHeaders['AjaxSessionKey']) -UserAgent $UserAgent
            }
        }
        catch {
        }

        if ([string]::IsNullOrWhiteSpace((Get-PortalCookieValue -Name 's.UserTenantId'))) {
            try {
                $null = Invoke-WebRequest -MaximumRedirection 20 -ErrorAction Stop -WebSession $WebSession -Method Get -Uri 'https://admin.cloud.microsoft/adminportal/home/ClassicModernAdminDataStream?ref=/homepage' -Headers (Get-M365PortalContextHeaders -Context Homepage -AjaxSessionKey $script:m365PortalHeaders['AjaxSessionKey']) -UserAgent $UserAgent
            }
            catch {
            }
        }

        Sync-PortalCookieValues

        if (-not [string]::IsNullOrWhiteSpace($cookieValues['x-portal-routekey'])) {
            $script:m365PortalHeaders['x-portal-routekey'] = $cookieValues['x-portal-routekey']
        }
    }

    $validationResults = New-Object System.Collections.Generic.List[object]
    $resolvedTenantId = $cookieValues['s.UserTenantId']
    try {
        if (-not $SkipValidation) {
            $classicModernResponse = Invoke-M365PortalRequest -Path '/adminportal/home/ClassicModernAdminDataStream?ref=/homepage' -Headers (Get-M365PortalContextHeaders -Context Homepage) -RawResponse
            if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) {
                $resolvedTenantId = Resolve-TenantIdFromContent -Content $classicModernResponse.Content
            }

            Sync-PortalCookieValues
            if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) {
                $resolvedTenantId = $cookieValues['s.UserTenantId']
            }

            if (-not [string]::IsNullOrWhiteSpace($cookieValues['x-portal-routekey'])) {
                $script:m365PortalHeaders['x-portal-routekey'] = $cookieValues['x-portal-routekey']
            }

            $validationResults.Add([pscustomobject]@{
                Name       = 'ClassicModernAdminDataStream'
                Path       = '/adminportal/home/ClassicModernAdminDataStream?ref=/homepage'
                StatusCode = [int]$classicModernResponse.StatusCode
            })

            try {
                $shellInfoResponse = Invoke-M365PortalRequest -Path '/admin/api/coordinatedbootstrap/shellinfo' -Headers (Get-M365PortalContextHeaders -Context Homepage) -RawResponse
                if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) {
                    $resolvedTenantId = Resolve-TenantIdFromContent -Content $shellInfoResponse.Content
                }
                $validationResults.Add([pscustomobject]@{
                    Name       = 'ShellInfo'
                    Path       = '/admin/api/coordinatedbootstrap/shellinfo'
                    StatusCode = [int]$shellInfoResponse.StatusCode
                })

                if (-not [string]::IsNullOrWhiteSpace($shellInfoResponse.Content)) {
                    $null = Set-M365Cache -CacheKey 'ShellInfo' -Value $shellInfoResponse.Content -TTLMinutes 15 -TenantId $cookieValues['s.UserTenantId']
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
        }

        Sync-PortalCookieValues
        if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) {
            $resolvedTenantId = $cookieValues['s.UserTenantId']
        }

        $connection = [System.Management.Automation.PSObject]::new()
        $connection | Add-Member -NotePropertyName PortalHost -NotePropertyValue 'admin.cloud.microsoft'
        $connection | Add-Member -NotePropertyName TenantId -NotePropertyValue $resolvedTenantId
        $connection | Add-Member -NotePropertyName UserId -NotePropertyValue $cookieValues['s.userid']
        $connection | Add-Member -NotePropertyName SessionId -NotePropertyValue $cookieValues['s.SessID']
        $connection | Add-Member -NotePropertyName RouteKeyPresent -NotePropertyValue (-not [string]::IsNullOrWhiteSpace($cookieValues['x-portal-routekey']))
        $connection | Add-Member -NotePropertyName Source -NotePropertyValue $AuthSource
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
        throw
    }
}