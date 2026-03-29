function Connect-M365PortalByBrowser {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal by using an interactive browser sign-in flow.

    .DESCRIPTION
        This is a convenience wrapper around Connect-M365Portal for the interactive
        Chromium-based browser sign-in flow. It can reuse a dedicated profile, reset that
        profile before sign-in, or use a temporary private session.

    .PARAMETER Username
        Optional username to prefill or guide the browser sign-in flow.

    .PARAMETER TenantId
        Optional tenant ID used to scope the Entra sign-in bootstrap.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for the browser sign-in to complete.

    .PARAMETER BrowserPath
        Optional browser executable path or command name.

    .PARAMETER ProfilePath
        Optional dedicated browser profile path.

    .PARAMETER ResetProfile
        Clears the dedicated browser profile before launching the sign-in flow.

    .PARAMETER PrivateSession
        Uses a temporary private/incognito browser session.

    .PARAMETER UserAgent
        Optional User-Agent override for the launched browser and follow-up bootstrap requests.

    .PARAMETER SkipValidation
        Skips the admin portal validation probes after the session is established.

    .EXAMPLE
        Connect-M365PortalByBrowser -PrivateSession

        Launches a temporary private browser session and connects after interactive sign-in completes.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Username,

        [string]$TenantId,

        [ValidateRange(30, 1800)]
        [int]$TimeoutSeconds = 300,

        [string]$BrowserPath,

        [string]$ProfilePath,

        [switch]$ResetProfile,

        [switch]$PrivateSession,

        [string]$UserAgent = (Get-M365DefaultUserAgent),

        [switch]$SkipValidation
    )

    process {
        $connectParams = @{
            BrowserSignIn = $true
            TimeoutSeconds = $TimeoutSeconds
            UserAgent = $UserAgent
            SkipValidation = $SkipValidation
        }
        if ($PSBoundParameters.ContainsKey('Username')) {
            $connectParams.Username = $Username
        }
        if ($TenantId) {
            $connectParams.TenantId = $TenantId
        }
        if ($BrowserPath) {
            $connectParams.BrowserPath = $BrowserPath
        }
        if ($ProfilePath) {
            $connectParams.ProfilePath = $ProfilePath
        }
        if ($ResetProfile) {
            $connectParams.ResetProfile = $true
        }
        if ($PrivateSession) {
            $connectParams.PrivateSession = $true
        }

        Connect-M365Portal @connectParams
    }
}
