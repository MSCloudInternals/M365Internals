function Connect-M365PortalByCredential {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal by using username and password authentication.

    .DESCRIPTION
        This is a convenience wrapper around Connect-M365Portal for the Entra credential-based
        sign-in flow. It supports PSCredential input, explicit username/password input, and
        interactive prompting when credentials are not supplied ahead of time.

        Optional MFA handling can be guided with -MfaMethod and automatically completed for
        Authenticator app OTP challenges when -TotpSecret is provided.

    .PARAMETER Credential
        A PSCredential object containing the username and password to submit.

    .PARAMETER Username
        The username to use for sign-in when not passing -Credential.

    .PARAMETER Password
        The password to use for sign-in when not passing -Credential.

    .PARAMETER TotpSecret
        Optional Base32-encoded TOTP secret used to automatically complete Authenticator
        app OTP challenges.

    .PARAMETER MfaMethod
        Preferred MFA method. Supported values are PhoneAppOTP, PhoneAppNotification,
        and OneWaySMS.

    .PARAMETER TenantId
        Optional tenant ID to keep the final admin portal session aligned to a specific tenant.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for credential MFA to complete.

    .PARAMETER UserAgent
        User-Agent string used during the Entra bootstrap and admin portal exchange.

    .PARAMETER SkipValidation
        Skips the admin portal validation probes after the session is established.

    .EXAMPLE
        Connect-M365PortalByCredential

        Prompts for credentials and connects to the Microsoft 365 admin portal.

    .EXAMPLE
        Connect-M365PortalByCredential -Credential (Get-Credential) -TotpSecret 'JBSWY3DPEHPK3PXP'

        Connects by using the programmatic Entra credential flow with automatic TOTP handling.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding(DefaultParameterSetName = 'Credential')]
    [OutputType([pscustomobject])]
    param (
        [Parameter(ParameterSetName = 'Credential')]
        [PSCredential]$Credential,

        [Parameter(ParameterSetName = 'Explicit')]
        [string]$Username,

        [Parameter(ParameterSetName = 'Explicit')]
        [SecureString]$Password,

        [string]$TotpSecret,

        [ValidateSet('PhoneAppOTP', 'PhoneAppNotification', 'OneWaySMS')]
        [string]$MfaMethod,

        [string]$TenantId,

        [ValidateRange(30, 1800)]
        [int]$TimeoutSeconds = 300,

        [string]$UserAgent = (Get-M365DefaultUserAgent),

        [switch]$SkipValidation
    )

    process {
        $connectParams = @{
            UserAgent      = $UserAgent
            SkipValidation = $SkipValidation
        }
        if ($TenantId) {
            $connectParams.TenantId = $TenantId
        }
        if ($TotpSecret) {
            $connectParams.TotpSecret = $TotpSecret
        }
        if ($MfaMethod) {
            $connectParams.MfaMethod = $MfaMethod
        }
        if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) {
            $connectParams.TimeoutSeconds = $TimeoutSeconds
        }

        if ($Credential) {
            $connectParams.Credential = $Credential
            return Connect-M365Portal @connectParams
        }

        $resolvedUsername = $Username
        $resolvedPassword = $Password

        if (-not $resolvedUsername -and -not $resolvedPassword) {
            $capturedCredential = Get-Credential -Message 'Enter your Entra ID credentials for the Microsoft 365 admin portal'
            if (-not $capturedCredential) {
                throw 'No credentials provided.'
            }

            $connectParams.Credential = $capturedCredential
            return Connect-M365Portal @connectParams
        }

        if (-not $resolvedUsername) {
            $resolvedUsername = Read-Host 'Username'
        }
        if (-not $resolvedPassword) {
            $resolvedPassword = Read-Host -AsSecureString "Password for $resolvedUsername"
        }

        if (-not $resolvedUsername) {
            throw 'No username provided.'
        }
        if (-not $resolvedPassword) {
            throw 'No password provided.'
        }

        $connectParams.Username = $resolvedUsername
        $connectParams.Password = $resolvedPassword
        Connect-M365Portal @connectParams
    }
}
