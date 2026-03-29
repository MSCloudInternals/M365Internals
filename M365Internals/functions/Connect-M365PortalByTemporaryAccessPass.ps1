function Connect-M365PortalByTemporaryAccessPass {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal by using a Temporary Access Pass.

    .DESCRIPTION
        This is a convenience wrapper around Connect-M365Portal for the Temporary Access
        Pass sign-in flow. The cmdlet prompts for any missing interactive input and then
        lets the core portal connection path complete the admin bootstrap.

    .PARAMETER Username
        The username to use for Temporary Access Pass sign-in.

    .PARAMETER TemporaryAccessPass
        The Temporary Access Pass as a SecureString. Alias: TAP.

    .PARAMETER TenantId
        Optional tenant ID to use for tenant-scoped Temporary Access Pass sign-in.

    .PARAMETER UserAgent
        User-Agent string used during the Entra bootstrap and admin portal exchange.

    .PARAMETER SkipValidation
        Skips the admin portal validation probes after the session is established.

    .EXAMPLE
        $tap = ConvertTo-SecureString 'ABC12345' -AsPlainText -Force
        Connect-M365PortalByTemporaryAccessPass -Username 'admin@contoso.com' -TAP $tap

        Connects to the Microsoft 365 admin portal by using the supplied Temporary Access Pass.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [string]$Username,

        [Alias('TAP')]
        [SecureString]$TemporaryAccessPass,

        [string]$TenantId,

        [string]$UserAgent = (Get-M365DefaultUserAgent),

        [switch]$SkipValidation
    )

    process {
        $resolvedUsername = $Username
        $resolvedTap = $TemporaryAccessPass

        if (-not $resolvedUsername) {
            $resolvedUsername = Read-Host 'Username'
        }
        if (-not $resolvedTap) {
            $resolvedTap = Read-Host -AsSecureString "Temporary Access Pass for $resolvedUsername"
        }

        if (-not $resolvedUsername) {
            throw 'No username provided.'
        }
        if (-not $resolvedTap) {
            throw 'No Temporary Access Pass provided.'
        }

        $connectParams = @{
            Username            = $resolvedUsername
            TemporaryAccessPass = $resolvedTap
            UserAgent           = $UserAgent
            SkipValidation      = $SkipValidation
        }
        if ($TenantId) {
            $connectParams.TenantId = $TenantId
        }

        Connect-M365Portal @connectParams
    }
}
