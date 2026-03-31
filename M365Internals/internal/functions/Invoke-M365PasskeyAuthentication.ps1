function Invoke-M365PasskeyAuthentication {
    <#
    .SYNOPSIS
        Authenticates with a software passkey and returns an authenticated portal session.

    .DESCRIPTION
        Loads a WebAuthn passkey from a JSON credential file, starts the sign-in flow from
        the Microsoft 365 admin portal login bootstrap, completes the native Microsoft Entra
        ID FIDO sign-in sequence over HTTPS, and returns an authenticated web session for
        admin.cloud.microsoft.

        Local passkeys contain a privateKey value directly in the JSON credential file.
        Azure Key Vault-backed passkeys contain a keyVault object that references the signing
        key while keeping the private key material out of the credential file.

    .PARAMETER KeyFilePath
        Path to the passkey JSON file. The file must contain credentialId, userHandle,
        and username properties plus either privateKey or keyVault. relyingParty and url
        default to login.microsoft.com when omitted.

    .PARAMETER KeyVaultTenantId
        Optional Entra tenant ID used when acquiring a Key Vault access token through the
        Az module or Azure CLI.

    .PARAMETER KeyVaultClientId
        Optional client ID of a user-assigned managed identity used when acquiring a Key Vault
        access token from IMDS.

    .PARAMETER KeyVaultApiVersion
        Azure Key Vault REST API version used for the Sign operation. Defaults to 7.4.

    .PARAMETER UserAgent
        User-Agent string used for the authentication flow.

    .EXAMPLE
        Invoke-M365PasskeyAuthentication -KeyFilePath '.\admin.passkey'

        Authenticates with a local software passkey file and returns an authenticated
        web session for the Microsoft 365 admin portal.

    .EXAMPLE
        Invoke-M365PasskeyAuthentication -KeyFilePath '.\admin-kv.passkey' -KeyVaultTenantId '8612f621-73ca-4c12-973c-0da732bc44c2'

        Authenticates with an Azure Key Vault-backed passkey file and returns an authenticated
        web session for the Microsoft 365 admin portal.

    .OUTPUTS
        Microsoft.PowerShell.Commands.WebRequestSession
        Returns an authenticated web session for the Microsoft 365 admin portal.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$KeyFilePath,

        [string]$KeyVaultTenantId,

        [string]$KeyVaultClientId,

        [string]$KeyVaultApiVersion = '7.4',

        [string]$UserAgent = (Get-M365DefaultUserAgent)
    )

    process {
        function ConvertFrom-Base64UrlString {
            param (
                [Parameter(Mandatory)]
                [string]$Value
            )

            $normalized = $Value.Replace('-', '+').Replace('_', '/')
            $paddingLength = (4 - ($normalized.Length % 4)) % 4
            if ($paddingLength -gt 0) {
                $normalized += ('=' * $paddingLength)
            }

            [Convert]::FromBase64String($normalized)
        }

        function ConvertTo-Base64UrlString {
            param (
                [Parameter(Mandatory)]
                [byte[]]$Bytes
            )

            [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        }

        function ConvertFrom-UuidToBase64UrlString {
            param (
                [Parameter(Mandatory)]
                [string]$Value
            )

            if ($Value -notmatch '(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
                return $Value
            }

            $hexString = $Value.Replace('-', '')
            $rawBytes = [byte[]]::new($hexString.Length / 2)
            for ($index = 0; $index -lt $hexString.Length; $index += 2) {
                $rawBytes[$index / 2] = [Convert]::ToByte($hexString.Substring($index, 2), 16)
            }

            ConvertTo-Base64UrlString -Bytes $rawBytes
        }

        function ConvertTo-PemPrivateKey {
            param (
                [Parameter(Mandatory)]
                [string]$PrivateKey
            )

            if ($PrivateKey.Trim() -match '^-----BEGIN PRIVATE KEY-----') {
                return $PrivateKey
            }

            $cleanKey = $PrivateKey.Trim() -replace "`r|`n|\s", ''
            $cleanKey = $cleanKey -replace '-', '+' -replace '_', '/'
            $paddingLength = (4 - ($cleanKey.Length % 4)) % 4
            if ($paddingLength -gt 0) {
                $cleanKey += ('=' * $paddingLength)
            }

            $wrappedKey = ''
            for ($index = 0; $index -lt $cleanKey.Length; $index += 64) {
                if (($index + 64) -lt $cleanKey.Length) {
                    $wrappedKey += $cleanKey.Substring($index, 64) + "`n"
                }
                else {
                    $wrappedKey += $cleanKey.Substring($index)
                }
            }

            "-----BEGIN PRIVATE KEY-----`n$wrappedKey`n-----END PRIVATE KEY-----"
        }

        function ConvertFrom-IeeeToDerSignature {
            param (
                [Parameter(Mandatory)]
                [byte[]]$IeeeSignature
            )

            if ($IeeeSignature.Length -ne 64) {
                throw "Invalid IEEE P1363 signature length: $($IeeeSignature.Length). Expected 64 bytes for ES256."
            }

            $r = $IeeeSignature[0..31]
            $s = $IeeeSignature[32..63]
            while ($r.Length -gt 1 -and $r[0] -eq 0) {
                $r = $r[1..($r.Length - 1)]
            }
            while ($s.Length -gt 1 -and $s[0] -eq 0) {
                $s = $s[1..($s.Length - 1)]
            }
            if ($r[0] -ge 0x80) {
                $r = @(0) + $r
            }
            if ($s[0] -ge 0x80) {
                $s = @(0) + $s
            }

            [byte[]](@(0x30, ($r.Length + $s.Length + 4), 0x02, $r.Length) + $r + @(0x02, $s.Length) + $s)
        }

        function Get-Sha256Hash {
            param (
                [Parameter(Mandatory)]
                [byte[]]$Bytes
            )

            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            try {
                $sha256.ComputeHash($Bytes)
            }
            finally {
                $sha256.Dispose()
            }
        }

        function Get-HiddenFormFieldMap {
            param (
                [Parameter(Mandatory)]
                [string]$Html
            )

            $fields = @{}
            $inputMatches = [System.Text.RegularExpressions.Regex]::Matches($Html, '<input\b[^>]*>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($inputMatch in $inputMatches) {
                $tag = $inputMatch.Value
                if ($tag -notmatch 'type=["'']hidden["'']') {
                    continue
                }

                $nameMatch = [System.Text.RegularExpressions.Regex]::Match($tag, 'name=["''](?<name>[^"'']+)["'']', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if (-not $nameMatch.Success) {
                    continue
                }

                $valueMatch = [System.Text.RegularExpressions.Regex]::Match($tag, 'value=["''](?<value>[^"'']*)["'']', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                $fieldValue = if ($valueMatch.Success) {
                    [System.Net.WebUtility]::HtmlDecode($valueMatch.Groups['value'].Value)
                }
                else {
                    ''
                }

                $fields[$nameMatch.Groups['name'].Value] = $fieldValue
            }

            $fields
        }

        function Get-FormAction {
            param (
                [Parameter(Mandatory)]
                [string]$Html
            )

            $formMatch = [regex]::Match($Html, '<form\b[^>]*action=["''](?<value>[^"'']+)["'']', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if (-not $formMatch.Success) {
                return $null
            }

            [System.Net.WebUtility]::HtmlDecode($formMatch.Groups['value'].Value)
        }

        function Get-PasskeyRequestState {
            param (
                [Parameter(Mandatory)]
                [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

                [Parameter(Mandatory)]
                [string]$Agent
            )

            Get-M365AdminLoginState -WebSession $Session -UserAgent $Agent
        }

        function Invoke-GetCredentialTypeRequest {
            param (
                [Parameter(Mandatory)]
                [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

                [Parameter(Mandatory)]
                [pscustomobject]$LoginState,

                [Parameter(Mandatory)]
                [string]$Username,

                [Parameter(Mandatory)]
                [string]$Agent
            )

            $config = $LoginState.Config
            $requestBody = [ordered]@{
                username                       = $Username
                isOtherIdpSupported            = $true
                checkPhones                    = $false
                isRemoteNGCSupported           = $true
                isCookieBannerShown            = $false
                isFidoSupported                = $true
                originalRequest                = $config.sCtx
                country                        = if ($config.country) { $config.country } else { 'US' }
                forceotclogin                  = $false
                isExternalFederationDisallowed = $false
                isRemoteConnectSupported       = $false
                federationFlags                = 0
                isSignup                       = $false
                flowToken                      = $config.sFT
                isAccessPassSupported          = $true
                isQrCodePinSupported           = $true
            } | ConvertTo-Json -Compress

            $requestHeaders = @{
                Accept              = 'application/json'
                Origin              = 'https://login.microsoftonline.com'
                Referer             = $LoginState.LoginUrl
                canary              = $config.apiCanary
                'client-request-id' = ([guid]::NewGuid().Guid)
                hpgact              = [string]$config.hpgact
                hpgid               = [string]$config.hpgid
                hpgrequestid        = ([guid]::NewGuid().Guid)
            }

            $null = Invoke-RestMethod -Method Post -Uri (Resolve-M365EstsUrl -Url $config.urlGetCredentialType) -Headers $requestHeaders -ContentType 'application/json; charset=UTF-8' -Body $requestBody -WebSession $Session -UserAgent $Agent
        }

        function Get-EncodedCredentialList {
            param (
                [Parameter(Mandatory)]
                [string[]]$PasskeyIds
            )

            $encodedValues = foreach ($credentialId in $PasskeyIds) {
                [Convert]::ToBase64String((ConvertFrom-Base64UrlString -Value $credentialId))
            }

            [string]::Join(',', $encodedValues)
        }

        function Get-FidoChallengeState {
            param (
                [Parameter(Mandatory)]
                [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

                [Parameter(Mandatory)]
                [pscustomobject]$LoginState,

                [Parameter(Mandatory)]
                [string[]]$PasskeyIds,

                [Parameter(Mandatory)]
                [string]$Username,

                [Parameter(Mandatory)]
                [string]$Agent
            )

            $config = $LoginState.Config
            $resumeUrl = if ($config.PSObject.Properties['urlResume'] -and $config.urlResume) {
                Resolve-M365EstsUrl -Url $config.urlResume
            }
            else {
                'https://login.microsoftonline.com/common/resume?ctx=' + [uri]::EscapeDataString([string]$config.sCtx)
            }

            $cancelUrl = if ($config.PSObject.Properties['urlLogin'] -and $config.urlLogin) {
                Resolve-M365EstsUrl -Url $config.urlLogin
            }
            else {
                Resolve-M365EstsUrl -Url $config.urlCancel
            }

            $formFields = [ordered]@{
                allowedIdentities             = 2
                canary                        = $config.sFT
                serverChallenge               = $config.sFT
                postBackUrl                   = Resolve-M365EstsUrl -Url $config.urlPost
                postBackUrlAad                = if ($config.PSObject.Properties['urlPostAad']) { Resolve-M365EstsUrl -Url $config.urlPostAad } else { Resolve-M365EstsUrl -Url $config.urlPost }
                cancelUrl                     = $cancelUrl
                resumeUrl                     = $resumeUrl
                correlationId                 = $config.correlationId
                credentialsJson               = Get-EncodedCredentialList -PasskeyIds $PasskeyIds
                ctx                           = $config.sCtx
                username                      = $Username
                hasMsftAuthAppPasskey         = 1
                hasMsftAndroidAuthAppPasskey  = 1
                loginCanary                   = $config.canary
            }

            $fidoResponse = Invoke-WebRequest -Method Post -Uri 'https://login.microsoft.com/common/fido/get?uiflavor=Web' -Body $formFields -ContentType 'application/x-www-form-urlencoded' -WebSession $Session -UserAgent $Agent -Headers @{ Origin = 'https://login.microsoftonline.com'; Referer = 'https://login.microsoftonline.com/' }
            $fidoConfig = Get-M365LoginPageConfig -Content $fidoResponse.Content

            [pscustomobject]@{
                Config   = $fidoConfig
                Response = $fidoResponse
            }
        }

        function Get-AuthenticatorData {
            param (
                [Parameter(Mandatory)]
                [string]$RpId,

                [int]$SignatureCounter = 0
            )

            $rpIdHash = Get-Sha256Hash -Bytes ([System.Text.Encoding]::UTF8.GetBytes($RpId))
            $authenticatorData = [byte[]]::new(37)
            [System.Array]::Copy($rpIdHash, 0, $authenticatorData, 0, $rpIdHash.Length)
            $authenticatorData[32] = 0x05
            $counterBytes = [BitConverter]::GetBytes([uint32]$SignatureCounter)
            if ([BitConverter]::IsLittleEndian) {
                [Array]::Reverse($counterBytes)
            }

            [System.Array]::Copy($counterBytes, 0, $authenticatorData, 33, $counterBytes.Length)
            $authenticatorData
        }

        function ConvertTo-PlainTextString {
            param (
                [Parameter(Mandatory)]
                [System.Security.SecureString]$SecureString
            )

            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
            try {
                [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }

        function Resolve-KeyVaultKeyReference {
            param (
                [Parameter(Mandatory)]
                [pscustomobject]$KeyVault
            )

            $vaultName = if ($KeyVault.PSObject.Properties['vaultName']) { [string]$KeyVault.vaultName } else { $null }
            $keyName = if ($KeyVault.PSObject.Properties['keyName']) { [string]$KeyVault.keyName } else { $null }
            $keyVersion = if ($KeyVault.PSObject.Properties['keyVersion']) { [string]$KeyVault.keyVersion } else { $null }
            $keyId = if ($KeyVault.PSObject.Properties['keyId']) { [string]$KeyVault.keyId } else { $null }
            $keyUri = $null

            if ($keyId) {
                try {
                    $keyIdUri = [uri]$keyId
                    $keyUri = $keyIdUri.GetLeftPart([System.UriPartial]::Path).TrimEnd('/')
                    if (-not $vaultName) {
                        $vaultName = ($keyIdUri.Host -split '\.')[0]
                    }
                    $pathSegments = $keyIdUri.AbsolutePath.Trim('/') -split '/'
                    if ($pathSegments.Length -ge 2 -and $pathSegments[0] -eq 'keys') {
                        if (-not $keyName) {
                            $keyName = $pathSegments[1]
                        }
                        if (-not $keyVersion -and $pathSegments.Length -ge 3) {
                            $keyVersion = $pathSegments[2]
                        }
                    }
                }
                catch {
                    throw "The keyVault.keyId value '$keyId' is not a valid URI."
                }
            }

            if (-not $vaultName -or -not $keyName) {
                throw "The passkey file must include keyVault.vaultName and keyVault.keyName, or a parseable keyVault.keyId value."
            }

            if (-not $keyUri) {
                $keyUri = "https://$vaultName.vault.azure.net/keys/$keyName"
                if ($keyVersion) {
                    $keyUri += "/$keyVersion"
                }
            }

            [pscustomobject]@{
                vaultName  = $vaultName
                keyName    = $keyName
                keyVersion = $keyVersion
                keyId      = $keyId
                keyUri     = $keyUri
            }
        }

        function Get-KeyVaultAccessToken {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
            param (
                [string]$TenantId,

                [string]$ClientId
            )

            $resource = 'https://vault.azure.net'

            if (Get-Command Get-AzAccessToken -ErrorAction SilentlyContinue) {
                try {
                    $azParams = @{ ResourceUrl = $resource }
                    if ($TenantId) {
                        $azParams.TenantId = $TenantId
                    }

                    $azToken = Get-AzAccessToken @azParams -ErrorAction Stop
                    if ($azToken.Token -is [System.Security.SecureString]) {
                        return ConvertTo-PlainTextString -SecureString $azToken.Token
                    }

                    return [string]$azToken.Token
                }
                catch {
                    Write-Verbose "Az module token acquisition failed: $($_.Exception.Message)"
                }
            }

            if (Get-Command az -ErrorAction SilentlyContinue) {
                try {
                    $azCliArgs = @('account', 'get-access-token', '--resource', $resource, '--output', 'json')
                    if ($TenantId) {
                        $azCliArgs += @('--tenant', $TenantId)
                    }

                    $azCliOutput = & az @azCliArgs 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        return ((($azCliOutput | Out-String) | ConvertFrom-Json).accessToken)
                    }

                    Write-Verbose "Azure CLI token acquisition failed: $azCliOutput"
                }
                catch {
                    Write-Verbose "Azure CLI token acquisition failed: $($_.Exception.Message)"
                }
            }

            try {
                $imdsUri = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=' + [uri]::EscapeDataString($resource)
                if ($ClientId) {
                    $imdsUri += '&client_id=' + [uri]::EscapeDataString($ClientId)
                }

                return (Invoke-RestMethod -Uri $imdsUri -Headers @{ Metadata = 'true' } -TimeoutSec 3 -ErrorAction Stop).access_token
            }
            catch {
                Write-Verbose "IMDS token acquisition failed: $($_.Exception.Message)"
            }

            throw @"
Could not obtain an Azure Key Vault access token. Ensure one of the following:
  * Run Connect-AzAccount before calling this cmdlet
  * Sign in with Azure CLI: az login
  * Run this cmdlet from an Azure resource with a managed identity assigned
  * Provide -KeyVaultClientId for a user-assigned managed identity when using IMDS
"@
        }

        function Get-AssertionPayload {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Private helper that builds a WebAuthn assertion payload from in-memory signing material.')]
            param (
                [Parameter(Mandatory)]
                [pscustomobject]$PasskeyCredential,

                [Parameter(Mandatory)]
                [string]$Challenge,

                [int]$SignatureCounter = 0,

                [string]$PrivateKeyPem,

                [pscustomobject]$KeyVaultInfo,

                [string]$KeyVaultToken,

                [string]$KeyVaultApiVersion = '7.4'
            )

            $challengeBytes = [System.Text.Encoding]::UTF8.GetBytes($Challenge)
            $clientData = [ordered]@{
                type        = 'webauthn.get'
                challenge   = ConvertTo-Base64UrlString -Bytes $challengeBytes
                origin      = $PasskeyCredential.origin.TrimEnd('/')
                crossOrigin = $false
            } | ConvertTo-Json -Compress

            $clientDataBytes = [System.Text.Encoding]::UTF8.GetBytes($clientData)
            $clientDataHash = Get-Sha256Hash -Bytes $clientDataBytes
            $authenticatorData = Get-AuthenticatorData -RpId $PasskeyCredential.relyingParty -SignatureCounter $SignatureCounter
            $signedBytes = [byte[]]::new($authenticatorData.Length + $clientDataHash.Length)
            [System.Array]::Copy($authenticatorData, 0, $signedBytes, 0, $authenticatorData.Length)
            [System.Array]::Copy($clientDataHash, 0, $signedBytes, $authenticatorData.Length, $clientDataHash.Length)

            $signedHash = Get-Sha256Hash -Bytes $signedBytes
            if ($KeyVaultInfo -and $KeyVaultToken) {
                $signUri = "$($KeyVaultInfo.keyUri)/sign?api-version=$KeyVaultApiVersion"
                $requestHeaders = @{ Authorization = "Bearer $KeyVaultToken"; 'Content-Type' = 'application/json' }
                $requestBody = @{ alg = 'ES256'; value = (ConvertTo-Base64UrlString -Bytes $signedHash) } | ConvertTo-Json -Compress

                $signature = $null
                $retryDelayMilliseconds = 1000
                for ($attempt = 1; $attempt -le 3; $attempt++) {
                    try {
                        $signResult = Invoke-RestMethod -Uri $signUri -Method Post -Headers $requestHeaders -Body $requestBody -ErrorAction Stop
                        if (-not $signResult.value) {
                            throw 'Azure Key Vault returned an empty signature value.'
                        }

                        $signature = ConvertFrom-IeeeToDerSignature -IeeeSignature (ConvertFrom-Base64UrlString -Value $signResult.value)
                        break
                    }
                    catch {
                        if ($attempt -ge 3) {
                            throw "Azure Key Vault signing failed: $($_.Exception.Message)"
                        }

                        Start-Sleep -Milliseconds $retryDelayMilliseconds
                        $retryDelayMilliseconds *= 2
                    }
                }
            }
            else {
                $ecdsa = [System.Security.Cryptography.ECDsa]::Create()
                try {
                    $ecdsa.ImportFromPem($PrivateKeyPem)
                    try {
                        $signature = $ecdsa.SignHash($signedHash, [System.Security.Cryptography.DSASignatureFormat]::Rfc3279DerSequence)
                    }
                    catch {
                        $signature = ConvertFrom-IeeeToDerSignature -IeeeSignature ($ecdsa.SignHash($signedHash))
                    }
                }
                finally {
                    $ecdsa.Dispose()
                }
            }

            [ordered]@{
                id                = $PasskeyCredential.credentialId
                clientDataJSON    = ConvertTo-Base64UrlString -Bytes $clientDataBytes
                authenticatorData = ConvertTo-Base64UrlString -Bytes $authenticatorData
                signature         = ConvertTo-Base64UrlString -Bytes $signature
                userHandle        = if ($PasskeyCredential.userHandle) { $PasskeyCredential.userHandle } else { '' }
            } | ConvertTo-Json -Compress
        }

        function Submit-FidoAssertion {
            param (
                [Parameter(Mandatory)]
                [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

                [Parameter(Mandatory)]
                [pscustomobject]$FidoState,

                [Parameter(Mandatory)]
                [string]$Assertion,

                [Parameter(Mandatory)]
                [string]$Agent
            )

            $config = $FidoState.Config
            $submitResponse = Invoke-WebRequest -Method Post -Uri (Resolve-M365EstsUrl -Url $config.urlPost) -Body ([ordered]@{
                type         = 23
                ps           = 23
                assertion    = $Assertion
                lmcCanary    = $config.sCrossDomainCanary
                hpgrequestid = ([guid]::NewGuid().Guid)
                ctx          = $config.sCtx
                canary       = $config.canary
                flowToken    = $config.sFT
            }) -ContentType 'application/x-www-form-urlencoded' -WebSession $Session -UserAgent $Agent -Headers @{ Origin = 'https://login.microsoft.com'; Referer = 'https://login.microsoft.com/' }

            $cookieCollection = $Session.Cookies.GetCookies([uri]'https://login.microsoftonline.com/')
            $estsCookie = $cookieCollection['ESTSAUTHPERSISTENT']
            if (-not $estsCookie -or [string]::IsNullOrWhiteSpace($estsCookie.Value)) {
                throw 'The ESTS login flow completed without returning an ESTSAUTHPERSISTENT cookie.'
            }

            $submitFields = if ($submitResponse -and $submitResponse.Content) { Get-HiddenFormFieldMap -Html $submitResponse.Content } else { @{} }
            $submitAction = if ($submitResponse -and $submitResponse.Content) { Get-FormAction -Html $submitResponse.Content } else { $null }

            [pscustomobject]@{
                HiddenFields = $submitFields
                FormAction   = $submitAction
            }
        }

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            throw 'Invoke-M365PasskeyAuthentication requires PowerShell 7.0 or later.'
        }

        try {
            $resolvedKeyFilePath = (Resolve-Path -LiteralPath $KeyFilePath -ErrorAction Stop).Path
        }
        catch {
            throw "The passkey file '$KeyFilePath' could not be resolved."
        }

        try {
            $credential = Get-Content -LiteralPath $resolvedKeyFilePath -Raw | ConvertFrom-Json -Depth 8
        }
        catch {
            throw "The passkey file '$resolvedKeyFilePath' does not contain valid JSON."
        }

        $targetUser = if ($credential.PSObject.Properties.Name -contains 'username' -and $credential.username) {
            [string]$credential.username
        }
        elseif ($credential.PSObject.Properties.Name -contains 'userName' -and $credential.userName) {
            [string]$credential.userName
        }
        else {
            $null
        }
        if (-not $targetUser) {
            throw "The passkey file must include a username or userName value."
        }

        $rpId = if ($credential.PSObject.Properties.Name -contains 'relyingParty' -and $credential.relyingParty) {
            [string]$credential.relyingParty
        }
        elseif ($credential.PSObject.Properties.Name -contains 'rpId' -and $credential.rpId) {
            [string]$credential.rpId
        }
        else {
            'login.microsoft.com'
        }

        $rawUrl = if ($credential.PSObject.Properties.Name -contains 'url' -and $credential.url) {
            [string]$credential.url
        }
        else {
            "https://$rpId"
        }

        try {
            $originUri = [uri]$rawUrl
        }
        catch {
            throw "The passkey file contains an invalid url value '$rawUrl'."
        }
        $origin = $originUri.GetLeftPart([System.UriPartial]::Authority)

        $userHandle = if ($credential.PSObject.Properties.Name -contains 'userHandle' -and $credential.userHandle) {
            ([string]$credential.userHandle).TrimEnd('=') -replace '\+', '-' -replace '/', '_'
        }
        else {
            $null
        }
        if (-not $userHandle) {
            throw "The passkey file must include a userHandle value."
        }

        $credentialIdSource = if ($credential.PSObject.Properties.Name -contains 'credentialId' -and $credential.credentialId) {
            [string]$credential.credentialId
        }
        elseif ($credential.PSObject.Properties.Name -contains 'methodId' -and $credential.methodId) {
            [string]$credential.methodId
        }
        else {
            $null
        }
        if (-not $credentialIdSource) {
            throw "The passkey file must include a credentialId or methodId value."
        }

        $credentialId = ConvertFrom-UuidToBase64UrlString -Value $credentialIdSource
        $credentialId = ($credentialId.TrimEnd('=') -replace '\+', '-' -replace '/', '_')

        $useKeyVault = ($credential.PSObject.Properties.Name -contains 'keyVault') -and ($null -ne $credential.keyVault)
        $keyVaultInfo = $null
        $keyVaultToken = $null
        $privateKeyPem = $null

        if ($useKeyVault) {
            $keyVaultInfo = Resolve-KeyVaultKeyReference -KeyVault $credential.keyVault
            $keyVaultToken = Get-KeyVaultAccessToken -TenantId $KeyVaultTenantId -ClientId $KeyVaultClientId
        }
        else {
            $privateKeySource = if ($credential.PSObject.Properties.Name -contains 'privateKey' -and $credential.privateKey) {
                [string]$credential.privateKey
            }
            elseif ($credential.PSObject.Properties.Name -contains 'keyValue' -and $credential.keyValue) {
                [string]$credential.keyValue
            }
            else {
                $null
            }

            if (-not $privateKeySource) {
                throw "The passkey file must include either privateKey/keyValue or a keyVault definition."
            }

            try {
                $privateKeyPem = ConvertTo-PemPrivateKey -PrivateKey $privateKeySource
            }
            catch {
                throw "Failed to parse the local private key from the passkey file: $($_.Exception.Message)"
            }
        }

        $passkeyCredential = [pscustomobject]@{
            credentialId = $credentialId
            relyingParty = $rpId
            origin       = $origin
            userHandle   = $userHandle
            username     = $targetUser
        }

        $webSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
        $webSession.UserAgent = $UserAgent
        $loginState = Get-PasskeyRequestState -Session $webSession -Agent $UserAgent
        Invoke-GetCredentialTypeRequest -Session $webSession -LoginState $loginState -Username $passkeyCredential.username -Agent $UserAgent

        $fidoState = Get-FidoChallengeState -Session $webSession -LoginState $loginState -PasskeyIds @($passkeyCredential.credentialId) -Username $passkeyCredential.username -Agent $UserAgent
        $allowedCredentials = @($fidoState.Config.arrFidoAllowList)
        $credentialIdStandardBase64 = [Convert]::ToBase64String((ConvertFrom-Base64UrlString -Value $passkeyCredential.credentialId))
        if ($allowedCredentials.Count -gt 0 -and $allowedCredentials -notcontains $credentialIdStandardBase64) {
            throw 'The supplied software passkey is not present in the ESTS FIDO allow list for this sign-in flow.'
        }

        $signatureCounter = 0
        if ($credential.PSObject.Properties['signatureCounter']) {
            $signatureCounter = [int]$credential.signatureCounter
        }
        elseif ($credential.PSObject.Properties['signCount']) {
            $signatureCounter = [int]$credential.signCount
        }
        elseif ($credential.PSObject.Properties['counter']) {
            $signatureCounter = [int]$credential.counter
        }

        $assertionParams = @{
            PasskeyCredential = $passkeyCredential
            Challenge         = $fidoState.Config.sFidoChallenge
            SignatureCounter  = $signatureCounter
            KeyVaultApiVersion = $KeyVaultApiVersion
        }
        if ($useKeyVault) {
            $assertionParams.KeyVaultInfo = $keyVaultInfo
            $assertionParams.KeyVaultToken = $keyVaultToken
        }
        else {
            $assertionParams.PrivateKeyPem = $privateKeyPem
        }

        $assertion = Get-AssertionPayload @assertionParams
        $assertionResult = Submit-FidoAssertion -Session $webSession -FidoState $fidoState -Assertion $assertion -Agent $UserAgent
        return Complete-M365AdminPortalSignIn -WebSession $webSession -UserAgent $UserAgent -InitialHiddenFields $assertionResult.HiddenFields -InitialFormAction $assertionResult.FormAction
    }
}
