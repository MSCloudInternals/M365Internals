function Connect-M365PortalBySoftwarePasskey {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal by using a software passkey.

    .DESCRIPTION
        This is a convenience wrapper around Connect-M365Portal for the native Entra FIDO
        sign-in flow backed by a JSON credential file.

        Local passkeys contain a privateKey value directly in the JSON file. Azure Key Vault-
        backed passkeys contain a keyVault object that references the signing key while keeping
        the private key material out of the credential file.

    .PARAMETER KeyFilePath
        Path to the software passkey JSON file.

    .PARAMETER TenantId
        Optional tenant ID to keep the final admin portal session aligned to a specific tenant.

    .PARAMETER KeyVaultTenantId
        Optional Entra tenant ID used when acquiring a Key Vault access token through the
        Az module or Azure CLI.

    .PARAMETER KeyVaultClientId
        Optional client ID of a user-assigned managed identity used when acquiring a Key Vault
        access token from IMDS.

    .PARAMETER KeyVaultApiVersion
        Azure Key Vault REST API version used for the Sign operation. Defaults to 7.4.

    .PARAMETER UserAgent
        User-Agent string used during the authentication bootstrap and admin portal exchange.

    .PARAMETER SkipValidation
        Skips the admin portal validation probes after the session is established.

    .EXAMPLE
        Connect-M365PortalBySoftwarePasskey -KeyFilePath '.\admin.passkey'

        Connects to the Microsoft 365 admin portal by using the supplied local software passkey.

    .EXAMPLE
        Connect-M365PortalBySoftwarePasskey -KeyFilePath '.\admin-kv.passkey' -KeyVaultTenantId '8612f621-73ca-4c12-973c-0da732bc44c2'

        Connects to the Microsoft 365 admin portal by using an Azure Key Vault-backed software
        passkey and scopes the Key Vault token request to the supplied tenant.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [string]$KeyFilePath,

        [string]$TenantId,

        [string]$KeyVaultTenantId,

        [string]$KeyVaultClientId,

        [string]$KeyVaultApiVersion = '7.4',

        [string]$UserAgent = (Get-M365DefaultUserAgent),

        [switch]$SkipValidation
    )

    process {
        $connectParams = @{
            KeyFilePath        = $KeyFilePath
            KeyVaultApiVersion = $KeyVaultApiVersion
            UserAgent          = $UserAgent
            SkipValidation     = $SkipValidation
        }
        if ($TenantId) {
            $connectParams.TenantId = $TenantId
        }
        if ($KeyVaultTenantId) {
            $connectParams.KeyVaultTenantId = $KeyVaultTenantId
        }
        if ($KeyVaultClientId) {
            $connectParams.KeyVaultClientId = $KeyVaultClientId
        }

        Connect-M365Portal @connectParams
    }
}
