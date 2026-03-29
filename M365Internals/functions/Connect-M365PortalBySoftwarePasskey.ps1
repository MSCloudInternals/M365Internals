function Connect-M365PortalBySoftwarePasskey {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal by using a local software passkey.

    .DESCRIPTION
        This is a convenience wrapper around Connect-M365Portal for the native Entra FIDO
        sign-in flow backed by a local passkey JSON file.

        Azure Key Vault-backed passkeys are not yet supported.

    .PARAMETER KeyFilePath
        Path to the local software passkey JSON file.

    .PARAMETER TenantId
        Optional tenant ID to keep the final admin portal session aligned to a specific tenant.

    .PARAMETER UserAgent
        User-Agent string used during the authentication bootstrap and admin portal exchange.

    .PARAMETER SkipValidation
        Skips the admin portal validation probes after the session is established.

    .EXAMPLE
        Connect-M365PortalBySoftwarePasskey -KeyFilePath '.\admin.passkey'

        Connects to the Microsoft 365 admin portal by using the supplied local software passkey.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [string]$KeyFilePath,

        [string]$TenantId,

        [string]$UserAgent = (Get-M365DefaultUserAgent),

        [switch]$SkipValidation
    )

    process {
        $connectParams = @{
            KeyFilePath    = $KeyFilePath
            UserAgent      = $UserAgent
            SkipValidation = $SkipValidation
        }
        if ($TenantId) {
            $connectParams.TenantId = $TenantId
        }

        Connect-M365Portal @connectParams
    }
}
