function Connect-M365PortalByPhoneSignIn {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal by using Microsoft Authenticator phone sign-in.

    .DESCRIPTION
        This is a convenience wrapper around Connect-M365Portal for the phone sign-in flow.
        It prompts for the username when needed, waits for the Authenticator approval flow,
        and then lets the core portal connection logic complete the admin bootstrap.

    .PARAMETER Username
        The username to use for phone sign-in.

    .PARAMETER TenantId
        Optional tenant ID to keep the final admin portal session aligned to a specific tenant.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for the phone sign-in approval to complete.

    .PARAMETER UserAgent
        User-Agent string used during the Entra bootstrap and admin portal exchange.

    .PARAMETER SkipValidation
        Skips the admin portal validation probes after the session is established.

    .EXAMPLE
        Connect-M365PortalByPhoneSignIn -Username 'admin@contoso.com'

        Starts Microsoft Authenticator phone sign-in and connects to the Microsoft 365 admin portal.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Username,

        [string]$TenantId,

        [ValidateRange(30, 1800)]
        [int]$TimeoutSeconds = 300,

        [string]$UserAgent = (Get-M365DefaultUserAgent),

        [switch]$SkipValidation
    )

    process {
        $resolvedUsername = $Username
        if (-not $resolvedUsername) {
            $resolvedUsername = Read-Host 'Username'
        }

        if (-not $resolvedUsername) {
            throw 'No username provided.'
        }

        $connectParams = @{
            PhoneSignIn    = $true
            Username       = $resolvedUsername
            TimeoutSeconds = $TimeoutSeconds
            UserAgent      = $UserAgent
            SkipValidation = $SkipValidation
        }
        if ($TenantId) {
            $connectParams.TenantId = $TenantId
        }

        Connect-M365Portal @connectParams
    }
}
