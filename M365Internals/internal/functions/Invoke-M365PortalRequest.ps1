function Invoke-M365PortalRequest {
    <#
    .SYNOPSIS
        Sends a request to the Microsoft 365 admin portal.

    .DESCRIPTION
        Wraps Invoke-WebRequest for same-origin requests against admin.cloud.microsoft using the
        current M365Internals portal session and default headers. JSON responses are converted to
        objects automatically unless the raw web response is requested.

    .PARAMETER Path
        A portal-relative path such as '/admin/api/coordinatedbootstrap/shellinfo'.

    .PARAMETER Uri
        A fully qualified request URI.

    .PARAMETER Method
        The HTTP method to use.

    .PARAMETER Headers
        Additional headers to merge with the current portal connection headers.

    .PARAMETER Body
        An optional request body.

    .PARAMETER ContentType
        The request content type to use when a body is provided.

    .PARAMETER WebSession
        The web session to use. When omitted, the current portal connection session is used.

    .PARAMETER SkipConnectionRefresh
        Skips the normal refresh of the stored portal connection before the request is sent.
        This is used by internal validation probes to avoid recursive refresh loops.

    .PARAMETER SkipAutoHeal
        Skips the retry path that replays the portal bootstrap after authentication drift or
        unexpected HTML shell responses. This is used by internal validation probes.

    .PARAMETER RawResponse
        Returns the full web response object instead of parsed content.

    .EXAMPLE
        Invoke-M365PortalRequest -Path '/admin/api/coordinatedbootstrap/shellinfo'

        Calls the shell info endpoint using the current portal session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Uri')]
        [string]$Uri,

        [ValidateSet('Get', 'Post', 'Put', 'Patch', 'Delete')]
        [string]$Method = 'Get',

        [hashtable]$Headers,

        $Body,

        [string]$ContentType,

        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [switch]$SkipConnectionRefresh,

        [switch]$SkipAutoHeal,

        [switch]$RawResponse
    )

    $resolvedSession = if ($WebSession) { $WebSession } else { $script:m365PortalSession }
    if (-not $resolvedSession) {
        throw 'No Microsoft 365 admin portal session is available. Run Connect-M365Portal first or provide -WebSession.'
    }

    $usingStoredSession = ($resolvedSession -eq $script:m365PortalSession)

    function Get-ResolvedPortalHeaders {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Private helper returns a merged header map for the current request.')]
        param()

        $currentHeaders = @{}
        if ($script:m365PortalHeaders) {
            foreach ($headerEntry in @($script:m365PortalHeaders.GetEnumerator())) {
                $currentHeaders[$headerEntry.Key] = $headerEntry.Value
            }
        }
        if ($Headers) {
            foreach ($headerEntry in @($Headers.GetEnumerator())) {
                $currentHeaders[$headerEntry.Key] = $headerEntry.Value
            }
        }

        return $currentHeaders
    }

    function Get-PortalRequestStatusCode {
        param(
            $ErrorRecord
        )

        if ($null -eq $ErrorRecord -or -not $ErrorRecord.Exception -or -not $ErrorRecord.Exception.Response) {
            return $null
        }

        try {
            return [int]$ErrorRecord.Exception.Response.StatusCode
        }
        catch {
            return $null
        }
    }

    function Test-IsRetryablePortalRequestError {
        param(
            $ErrorRecord
        )

        $statusCode = Get-PortalRequestStatusCode -ErrorRecord $ErrorRecord
        if ($statusCode -in @(401, 403)) {
            return $true
        }

        $exceptionMessage = if ($ErrorRecord -and $ErrorRecord.Exception) {
            [string]$ErrorRecord.Exception.Message
        }
        else {
            ''
        }

        return ($exceptionMessage -match 'AjaxSessionKey|Unauthorized|Forbidden|authentication|authorization')
    }

    function Invoke-PortalRequestSelfHeal {
        if (-not $usingStoredSession -or $SkipAutoHeal) {
            return $false
        }

        $bootstrapReplaySucceeded = $false
        try {
            $null = Invoke-M365PortalPostLandingBootstrap -WebSession $resolvedSession -UserAgent $resolvedSession.UserAgent
            $bootstrapReplaySucceeded = $true
        }
        catch {
            Write-Verbose "The portal self-heal bootstrap replay did not complete successfully: $($_.Exception.Message)"
        }

        try {
            $null = Update-M365PortalConnectionSettings
            return $bootstrapReplaySucceeded
        }
        catch {
            Write-Verbose "Refreshing the stored portal connection after the self-heal attempt failed: $($_.Exception.Message)"
            return $false
        }
    }

    if ($usingStoredSession -and -not $SkipConnectionRefresh) {
        $null = Update-M365PortalConnectionSettings

        if (-not $SkipAutoHeal -and (Test-M365PortalConnectionNeedsRefresh -Connection $script:m365PortalConnection -Headers $script:m365PortalHeaders)) {
            $lastRefreshAttemptAt = if ($resolvedSession.PSObject.Properties['M365LastTokenRefreshAttemptAt']) {
                $resolvedSession.M365LastTokenRefreshAttemptAt
            }
            else {
                $null
            }
            $currentTokenFreshUntilUtc = if ($script:m365PortalConnection -and $script:m365PortalConnection.PSObject.Properties['TokenFreshUntilUtc']) {
                $script:m365PortalConnection.TokenFreshUntilUtc
            }
            else {
                $null
            }

            if (-not $lastRefreshAttemptAt -or $lastRefreshAttemptAt -lt (Get-Date).AddMinutes(-5)) {
                $resolvedSession | Add-Member -NotePropertyName M365LastTokenRefreshAttemptAt -NotePropertyValue (Get-Date) -Force
                Write-Verbose 'The observed portal freshness metadata indicates the session may be stale. Replaying the portal bootstrap before issuing the request.'
                if (Invoke-PortalRequestSelfHeal) {
                    if ($currentTokenFreshUntilUtc) {
                        $resolvedSession | Add-Member -NotePropertyName M365TokenRefreshSatisfiedUntilUtc -NotePropertyValue $currentTokenFreshUntilUtc -Force
                        if ($script:m365PortalConnection) {
                            $script:m365PortalConnection | Add-Member -NotePropertyName TokenRefreshSatisfiedUntilUtc -NotePropertyValue $currentTokenFreshUntilUtc -Force
                            $null = Set-M365PortalConnectionFreshness -Connection $script:m365PortalConnection
                        }
                    }
                }
            }
        }
    }

    $requestUri = if ($PSCmdlet.ParameterSetName -eq 'Uri') {
        $Uri
    }
    elseif ($Path.StartsWith('/')) {
        'https://admin.cloud.microsoft{0}' -f $Path
    }
    else {
        'https://admin.cloud.microsoft/{0}' -f $Path
    }

    $maxAttempts = if ($usingStoredSession -and -not $SkipAutoHeal) { 2 } else { 1 }
    $response = $null
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $invokeParams = @{
            Uri         = $requestUri
            Method      = $Method
            WebSession  = $resolvedSession
            Headers     = (Get-ResolvedPortalHeaders)
            ErrorAction = 'Stop'
        }

        if ($PSBoundParameters.ContainsKey('Body')) {
            if ($PSBoundParameters.ContainsKey('ContentType')) {
                $invokeParams.ContentType = $ContentType
                $invokeParams.Body = $Body
            }
            elseif ($Body -is [string]) {
                $invokeParams.ContentType = 'application/json'
                $invokeParams.Body = $Body
            }
            else {
                $invokeParams.ContentType = 'application/json'
                $invokeParams.Body = $Body | ConvertTo-Json -Depth 10
            }
        }

        try {
            $response = Invoke-WebRequest @invokeParams
        }
        catch {
            if ($attempt -lt $maxAttempts -and (Test-IsRetryablePortalRequestError -ErrorRecord $_) -and (Invoke-PortalRequestSelfHeal)) {
                Write-Verbose "The portal request returned an authentication-related failure. Retrying once after refreshing the portal session state."
                continue
            }

            throw "Portal request failed for $Method $requestUri. $($_.Exception.Message)"
        }

        if ($attempt -lt $maxAttempts -and (Test-M365PortalUnexpectedHtmlShell -Content $response.Content) -and (Invoke-PortalRequestSelfHeal)) {
            Write-Verbose 'The portal request returned the admin HTML shell instead of the expected payload. Retrying once after refreshing the portal session state.'
            continue
        }

        break
    }

    if ($RawResponse) {
        return $response
    }

    $responseContentType = $response.Headers['Content-Type']
    if ($responseContentType -match 'json' -and -not [string]::IsNullOrWhiteSpace($response.Content)) {
        try {
            return $response.Content | ConvertFrom-Json -Depth 20
        }
        catch {
            return $response.Content
        }
    }

    $response.Content
}
