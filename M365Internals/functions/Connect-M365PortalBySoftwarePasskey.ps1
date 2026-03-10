function Connect-M365PortalBySoftwarePasskey {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal using a local software passkey.

    .DESCRIPTION
        Authenticates against Microsoft Entra ID by loading a local WebAuthn passkey JSON
        file and completing the native ESTS FIDO sign-in flow over HTTPS. The resulting
        Entra-authenticated session is then handed to Connect-M365Portal to establish the
        reusable admin.cloud.microsoft session used by other M365Internals cmdlets.

        This cmdlet currently supports only local passkey files that include a privateKey
        field. Azure Key Vault-backed passkeys are not yet supported.

    .PARAMETER KeyFilePath
        Path to the local software passkey JSON file.

    .PARAMETER UserAgent
        User-Agent string used during the authentication bootstrap and admin portal exchange.

    .PARAMETER SkipValidation
        Skips the admin portal validation probes after the session has been established.

    .EXAMPLE
        Connect-M365PortalBySoftwarePasskey -KeyFilePath '.github\secadmin.passkey'

        Authenticates with the local software passkey file and establishes the admin portal
        session.

    .OUTPUTS
        M365Portal.Connection
        Returns details about the active admin portal connection.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [string]$KeyFilePath,

        [string]$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0',

        [switch]$SkipValidation
    )

    process {
        $portalSession = Invoke-M365PasskeyAuthentication -KeyFilePath $KeyFilePath -UserAgent $UserAgent
        Connect-M365Portal -WebSession $portalSession -UserAgent $UserAgent -SkipValidation:$SkipValidation
    }
}