function Connect-M365PortalByEstsCookie {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal by using an ESTS authentication cookie.

    .DESCRIPTION
        This is a convenience wrapper around Connect-M365Portal for callers that already
        have an ESTS authentication cookie from an Entra-authenticated session. The cookie
        can be supplied as plain text or as a secure string and is exchanged through the
        Microsoft 365 admin portal sign-in bootstrap.

    .PARAMETER EstsAuthCookieValue
        The ESTS authentication cookie value as plain text.

    .PARAMETER SecureEstsAuthCookieValue
        The ESTS authentication cookie value as a secure string.

    .PARAMETER TenantId
        Optional tenant ID to keep the final admin portal session aligned to a specific tenant.

    .PARAMETER UserAgent
        User-Agent string used during the admin portal exchange.

    .PARAMETER SkipValidation
        Skips the admin portal validation probes after the session is established.

    .EXAMPLE
        Connect-M365PortalByEstsCookie -EstsAuthCookieValue $estsCookie

        Exchanges an ESTS authentication cookie through the admin portal sign-in flow.
    #>
    [CmdletBinding(DefaultParameterSetName = 'PlainText')]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'PlainText', ValueFromPipeline)]
        [string]$EstsAuthCookieValue,

        [Parameter(Mandatory, ParameterSetName = 'SecureString', ValueFromPipeline)]
        [System.Security.SecureString]$SecureEstsAuthCookieValue,

        [Parameter(ParameterSetName = 'PlainText')]
        [Parameter(ParameterSetName = 'SecureString')]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'PlainText')]
        [Parameter(ParameterSetName = 'SecureString')]
        [string]$UserAgent = (Get-M365DefaultUserAgent),

        [Parameter(ParameterSetName = 'PlainText')]
        [Parameter(ParameterSetName = 'SecureString')]
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
        if ($PSCmdlet.ParameterSetName -eq 'SecureString') {
            $connectParams.SecureEstsAuthCookieValue = $SecureEstsAuthCookieValue
        }
        else {
            $connectParams.EstsAuthCookieValue = $EstsAuthCookieValue
        }

        Connect-M365Portal @connectParams
    }
}
