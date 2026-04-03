function Connect-M365AuthArtifactSet {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal from captured authentication artifacts.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Parameters are consumed by nested helper closures or retained for compatibility across auth flows.')]
    [CmdletBinding()]
    param(
        [string]$EstsAuthCookieValue,

        [Microsoft.PowerShell.Commands.WebRequestSession]$EstsWebSession,

        [Microsoft.PowerShell.Commands.WebRequestSession]$PortalWebSession,

        [string]$TenantId,

        [string]$UserAgent = (Get-M365DefaultUserAgent),

        [ValidateSet('PreferEsts', 'PreferPortal')]
        [string]$ConnectionPreference = 'PreferEsts',

        [string]$AuthFlow,

        [switch]$FallbackToPortalOnEstsBootstrapFailure,

        [switch]$SkipValidation,

        [string]$FailureLabel = 'Authentication'
    )

    function Set-ResolvedAuthFlow {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper that updates only the in-memory connection object.')]
        param(
            [Parameter(Mandatory)]
            $Connection
        )

        if ($Connection -and -not [string]::IsNullOrWhiteSpace($AuthFlow)) {
            $Connection.AuthFlow = $AuthFlow
        }

        return $Connection
    }

    function Connect-FromPortalWebSession {
        param(
            [Parameter(Mandatory)]
            [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
        )

        $connection = Set-M365PortalConnectionSettings -WebSession $WebSession -AuthSource 'WebSession' -AuthFlow 'WebSession' -UserAgent $UserAgent -SkipValidation:$SkipValidation
        Set-ResolvedAuthFlow -Connection $connection
    }

    function Connect-FromEstsWebSession {
        param(
            [Parameter(Mandatory)]
            [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
        )

        if ($UserAgent) {
            $WebSession.UserAgent = $UserAgent
        }

        $portalSession = Complete-M365AdminPortalSignIn -WebSession $WebSession -UserAgent $UserAgent
        $connection = Set-M365PortalConnectionSettings -WebSession $portalSession -AuthSource 'ESTSAUTHPERSISTENT' -AuthFlow 'EstsCookie' -UserAgent $UserAgent -SkipValidation:$SkipValidation
        Set-ResolvedAuthFlow -Connection $connection
    }

    function Connect-FromEstsCookieValue {
        param(
            [Parameter(Mandatory)]
            [string]$CookieValue
        )

        $webSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
        if ($UserAgent) {
            $webSession.UserAgent = $UserAgent
        }

        $null = Invoke-WebRequest -MaximumRedirection 10 -ErrorAction SilentlyContinue -WebSession $webSession -Method Get -Uri 'https://login.microsoftonline.com/error'
        foreach ($cookieName in @('ESTSAUTH', 'ESTSAUTHPERSISTENT')) {
            $cookie = [System.Net.Cookie]::new($cookieName, $CookieValue, '/', 'login.microsoftonline.com')
            $webSession.Cookies.Add($cookie)
        }

        Connect-FromEstsWebSession -WebSession $webSession
    }

    if ([string]::IsNullOrWhiteSpace($EstsAuthCookieValue) -and $EstsWebSession) {
        $EstsAuthCookieValue = Get-M365BestEstsCookieValue -Session $EstsWebSession
    }

    $hasEsts = (-not [string]::IsNullOrWhiteSpace($EstsAuthCookieValue)) -or ($null -ne $EstsWebSession)
    $hasPortalSession = $null -ne $PortalWebSession

    if (-not $hasEsts -and -not $hasPortalSession) {
        throw "$FailureLabel failed - no supported authentication artifacts were returned."
    }

    $primaryAttempt = $ConnectionPreference
    $attemptErrors = New-Object System.Collections.Generic.List[string]

    if ($primaryAttempt -eq 'PreferPortal' -and $hasPortalSession) {
        try {
            return Connect-FromPortalWebSession -WebSession $PortalWebSession
        }
        catch {
            $attemptErrors.Add("Portal session: $($_.Exception.Message)")
            if (-not $hasEsts) {
                throw
            }
        }
    }

    if ($EstsWebSession) {
        try {
            return Connect-FromEstsWebSession -WebSession $EstsWebSession
        }
        catch {
            $attemptErrors.Add("ESTS session bootstrap: $($_.Exception.Message)")
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($EstsAuthCookieValue)) {
        try {
            if ($EstsWebSession) {
                Write-Verbose 'The session-based ESTS bootstrap did not complete successfully. Falling back to a new session built from the captured ESTS cookie value.'
            }

            return Connect-FromEstsCookieValue -CookieValue $EstsAuthCookieValue
        }
        catch {
            $attemptErrors.Add("ESTS bootstrap: $($_.Exception.Message)")
        }
    }

    if ($FallbackToPortalOnEstsBootstrapFailure -and $hasPortalSession) {
        try {
            Write-Verbose 'ESTS bootstrap failed. Falling back to the captured admin portal cookie set.'
            return Connect-FromPortalWebSession -WebSession $PortalWebSession
        }
        catch {
            $attemptErrors.Add("Portal session: $($_.Exception.Message)")
            throw
        }
    }

    if ($primaryAttempt -eq 'PreferPortal' -and $hasPortalSession) {
        throw "$FailureLabel failed. $($attemptErrors -join ' | ')"
    }

    if ($attemptErrors.Count -gt 0) {
        throw "$FailureLabel failed. $($attemptErrors -join ' | ')"
    }

    throw "$FailureLabel failed - no supported authentication artifacts were returned."
}
