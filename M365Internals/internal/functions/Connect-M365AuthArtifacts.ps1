function Connect-M365AuthArtifactSet {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal from captured authentication artifacts.
    #>
    [CmdletBinding()]
    param(
        [string]$EstsAuthCookieValue,

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

    $hasEsts = -not [string]::IsNullOrWhiteSpace($EstsAuthCookieValue)
    $hasPortalSession = $null -ne $PortalWebSession

    if (-not $hasEsts -and -not $hasPortalSession) {
        throw "$FailureLabel failed - no supported authentication artifacts were returned."
    }

    $estsConnectParams = $null
    if ($hasEsts) {
        $estsConnectParams = @{
            EstsAuthCookieValue = $EstsAuthCookieValue
            UserAgent           = $UserAgent
            SkipValidation      = $SkipValidation
        }
        if ($TenantId) {
            $estsConnectParams.TenantId = $TenantId
        }
    }

    $portalConnectParams = $null
    if ($hasPortalSession) {
        $portalConnectParams = @{
            WebSession     = $PortalWebSession
            UserAgent      = $UserAgent
            SkipValidation = $SkipValidation
        }
    }

    $primaryAttempt = $ConnectionPreference
    $attemptErrors = New-Object System.Collections.Generic.List[string]

    if ($primaryAttempt -eq 'PreferPortal' -and $portalConnectParams) {
        try {
            $connection = Connect-M365Portal @portalConnectParams
            if (-not [string]::IsNullOrWhiteSpace($AuthFlow)) {
                $connection.AuthFlow = $AuthFlow
            }

            return $connection
        }
        catch {
            $attemptErrors.Add("Portal session: $($_.Exception.Message)")
            if (-not $estsConnectParams) {
                throw
            }

            Write-Verbose 'Captured admin portal cookies were not sufficient on the first attempt. Falling back to the captured ESTS cookie.'
            $connection = Connect-M365Portal @estsConnectParams
            if (-not [string]::IsNullOrWhiteSpace($AuthFlow)) {
                $connection.AuthFlow = $AuthFlow
            }

            return $connection
        }
    }

    if ($estsConnectParams) {
        try {
            $connection = Connect-M365Portal @estsConnectParams
            if (-not [string]::IsNullOrWhiteSpace($AuthFlow)) {
                $connection.AuthFlow = $AuthFlow
            }

            return $connection
        }
        catch {
            $attemptErrors.Add("ESTS bootstrap: $($_.Exception.Message)")
            if (-not $FallbackToPortalOnEstsBootstrapFailure -or -not $portalConnectParams) {
                throw
            }

            Write-Verbose 'ESTS bootstrap failed. Falling back to the captured admin portal cookie set.'
            $connection = Connect-M365Portal @portalConnectParams
            if (-not [string]::IsNullOrWhiteSpace($AuthFlow)) {
                $connection.AuthFlow = $AuthFlow
            }

            return $connection
        }
    }

    if ($portalConnectParams) {
        try {
            $connection = Connect-M365Portal @portalConnectParams
            if (-not [string]::IsNullOrWhiteSpace($AuthFlow)) {
                $connection.AuthFlow = $AuthFlow
            }

            return $connection
        }
        catch {
            $attemptErrors.Add("Portal session: $($_.Exception.Message)")
            throw
        }
    }

    if ($attemptErrors.Count -gt 0) {
        throw "$FailureLabel failed. $($attemptErrors -join ' | ')"
    }

    throw "$FailureLabel failed - no supported authentication artifacts were returned."
}
