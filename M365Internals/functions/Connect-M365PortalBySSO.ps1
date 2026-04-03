function Connect-M365PortalBySSO {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal by using browser-based single sign-on.

    .DESCRIPTION
        This is a convenience wrapper around Connect-M365Portal for the browser-based
        single sign-on flow. It is intended for Windows-first scenarios where the local
        browser and operating-system account state can silently establish the admin session.
        The SSO helper currently supports Windows only for now.

    .PARAMETER TenantId
        Optional tenant ID (GUID) used to scope the Entra sign-in bootstrap.

    .PARAMETER Visible
        Shows the browser window instead of using the default headless launch.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for SSO authentication to complete.

    .PARAMETER BrowserPath
        Optional browser executable path or command name.

    .PARAMETER ProfilePath
        Optional persistent browser profile path used for SSO.

    .PARAMETER ResetProfile
        Clears the dedicated SSO browser profile before launching the sign-in flow.

    .PARAMETER PrivateSession
        Uses a temporary isolated browser profile for the SSO attempt.

    .PARAMETER UserAgent
        Optional User-Agent override for the launched browser and follow-up bootstrap requests.

    .PARAMETER SkipValidation
        Skips the admin portal validation probes after the session is established.

    .EXAMPLE
        Connect-M365PortalBySSO -Visible

        Launches a visible browser window and attempts to capture a Microsoft 365 admin session through SSO on Windows for now.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [switch]$Visible,

        [ValidateRange(30, 1800)]
        [int]$TimeoutSeconds = 180,

        [string]$BrowserPath,

        [string]$ProfilePath,

        [switch]$ResetProfile,

        [switch]$PrivateSession,

        [string]$UserAgent = (Get-M365DefaultUserAgent),

        [switch]$SkipValidation
    )

    process {
        $connectParams = @{
            SSO = $true
            Visible = $Visible
            TimeoutSeconds = $TimeoutSeconds
            UserAgent = $UserAgent
            SkipValidation = $SkipValidation
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
