function Invoke-M365PasskeyAuthentication {
    <#
    .SYNOPSIS
        Authenticates with a local software passkey and returns an authenticated portal session.

    .DESCRIPTION
        Loads a local WebAuthn passkey from a JSON credential file, starts the sign-in flow
        from the Microsoft 365 admin portal login bootstrap, completes the native Microsoft
        Entra ID FIDO sign-in sequence over HTTPS, and returns an authenticated web session
        for admin.cloud.microsoft.

        This helper currently supports only local passkey files that contain a PEM-encoded
        privateKey value. Azure Key Vault-backed passkeys are not yet implemented.

    .PARAMETER KeyFilePath
        Path to the local passkey JSON file. The file must contain credentialId,
        privateKey, relyingParty, url, userHandle, and username properties.

    .PARAMETER UserAgent
        User-Agent string used for the authentication flow.

    .EXAMPLE
        Invoke-M365PasskeyAuthentication -KeyFilePath '.\admin.passkey'

        Authenticates with a local software passkey file and returns an authenticated
        web session for the Microsoft 365 admin portal.

    .OUTPUTS
        Microsoft.PowerShell.Commands.WebRequestSession
        Returns an authenticated web session for the Microsoft 365 admin portal.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$KeyFilePath,

        [string]$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0'
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

        function Resolve-EstsUrl {
            param (
                [Parameter(Mandatory)]
                [string]$Url
            )

            if ($Url -match '^https?://') {
                return $Url
            }

            "https://login.microsoftonline.com$Url"
        }

        function Get-AdminBootstrapLoginUrl {
            param (
                [Parameter(Mandatory)]
                [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

                [Parameter(Mandatory)]
                [string]$Agent
            )

            $bootstrapResponse = Invoke-WebRequest -Uri 'https://admin.cloud.microsoft/' -WebSession $Session -UserAgent $Agent
            $loginUrlMatch = [regex]::Match($bootstrapResponse.Content, "var loginURL = '(?<value>(?:\\.|[^'])+)'")
            if (-not $loginUrlMatch.Success) {
                throw 'Failed to determine the admin.cloud.microsoft sign-in URL.'
            }

            [System.Text.RegularExpressions.Regex]::Unescape($loginUrlMatch.Groups['value'].Value)
        }

        function Get-LoginPageConfig {
            param (
                [Parameter(Mandatory)]
                [string]$Content
            )

            $assignmentMatch = [regex]::Match($Content, '\$Config\s*=\s*\{')
            if (-not $assignmentMatch.Success) {
                throw 'Failed to parse the ESTS page configuration block.'
            }

            $startIndex = $assignmentMatch.Index + $assignmentMatch.Length - 1
            $depth = 0
            $inString = $false
            $isEscaped = $false
            $endIndex = -1

            for ($index = $startIndex; $index -lt $Content.Length; $index++) {
                $character = $Content[$index]

                if ($isEscaped) {
                    $isEscaped = $false
                    continue
                }

                if ($character -eq '\') {
                    if ($inString) {
                        $isEscaped = $true
                    }

                    continue
                }

                if ($character -eq '"') {
                    $inString = -not $inString
                    continue
                }

                if ($inString) {
                    continue
                }

                if ($character -eq '{') {
                    $depth++
                    continue
                }

                if ($character -eq '}') {
                    $depth--
                    if ($depth -eq 0) {
                        $endIndex = $index
                        break
                    }
                }
            }

            if ($endIndex -lt $startIndex) {
                throw 'Failed to parse the ESTS page configuration block.'
            }

            $Content.Substring($startIndex, ($endIndex - $startIndex) + 1) | ConvertFrom-Json -Depth 32
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

        function Get-HtmlTitle {
            param (
                [Parameter(Mandatory)]
                [string]$Html
            )

            $titleMatch = [regex]::Match($Html, '<title[^>]*>(?<value>.*?)</title>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if (-not $titleMatch.Success) {
                return $null
            }

            [System.Net.WebUtility]::HtmlDecode($titleMatch.Groups['value'].Value).Trim()
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

            $loginUrl = Get-AdminBootstrapLoginUrl -Session $Session -Agent $Agent
            $loginResponse = Invoke-WebRequest -Uri $loginUrl -WebSession $Session -MaximumRedirection 5 -UserAgent $Agent
            $loginConfig = Get-LoginPageConfig -Content $loginResponse.Content

            [pscustomobject]@{
                LoginUrl = $loginUrl
                Config   = $loginConfig
            }
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

            $null = Invoke-RestMethod -Method Post -Uri (Resolve-EstsUrl -Url $config.urlGetCredentialType) -Headers $requestHeaders -ContentType 'application/json; charset=UTF-8' -Body $requestBody -WebSession $Session -UserAgent $Agent
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
                Resolve-EstsUrl -Url $config.urlResume
            }
            else {
                'https://login.microsoftonline.com/common/resume?ctx=' + [uri]::EscapeDataString([string]$config.sCtx)
            }

            $cancelUrl = if ($config.PSObject.Properties['urlLogin'] -and $config.urlLogin) {
                Resolve-EstsUrl -Url $config.urlLogin
            }
            else {
                Resolve-EstsUrl -Url $config.urlCancel
            }

            $formFields = [ordered]@{
                allowedIdentities             = 2
                canary                        = $config.sFT
                serverChallenge               = $config.sFT
                postBackUrl                   = Resolve-EstsUrl -Url $config.urlPost
                postBackUrlAad                = if ($config.PSObject.Properties['urlPostAad']) { Resolve-EstsUrl -Url $config.urlPostAad } else { Resolve-EstsUrl -Url $config.urlPost }
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
            $fidoConfig = Get-LoginPageConfig -Content $fidoResponse.Content

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

        function Get-AssertionPayload {
            param (
                [Parameter(Mandatory)]
                [pscustomobject]$PasskeyCredential,

                [Parameter(Mandatory)]
                [string]$Challenge,

                [int]$SignatureCounter = 0
            )

            $challengeBytes = [System.Text.Encoding]::UTF8.GetBytes($Challenge)
            $clientData = [ordered]@{
                type        = 'webauthn.get'
                challenge   = ConvertTo-Base64UrlString -Bytes $challengeBytes
                origin      = $PasskeyCredential.url.TrimEnd('/')
                crossOrigin = $false
            } | ConvertTo-Json -Compress

            $clientDataBytes = [System.Text.Encoding]::UTF8.GetBytes($clientData)
            $clientDataHash = Get-Sha256Hash -Bytes $clientDataBytes
            $authenticatorData = Get-AuthenticatorData -RpId $PasskeyCredential.relyingParty -SignatureCounter $SignatureCounter
            $signedBytes = [byte[]]::new($authenticatorData.Length + $clientDataHash.Length)
            [System.Array]::Copy($authenticatorData, 0, $signedBytes, 0, $authenticatorData.Length)
            [System.Array]::Copy($clientDataHash, 0, $signedBytes, $authenticatorData.Length, $clientDataHash.Length)
            $ecdsa = [System.Security.Cryptography.ECDsa]::Create()
            try {
                $ecdsa.ImportFromPem($PasskeyCredential.privateKey)
                try {
                    $signature = $ecdsa.SignData($signedBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.DSASignatureFormat]::Rfc3279DerSequence)
                }
                catch {
                    $signature = $ecdsa.SignData($signedBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
                }
            }
            finally {
                $ecdsa.Dispose()
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
            $submitResponse = Invoke-WebRequest -Method Post -Uri (Resolve-EstsUrl -Url $config.urlPost) -Body ([ordered]@{
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

        function Complete-AdminPortalSignIn {
            param (
                [Parameter(Mandatory)]
                [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

                [Parameter(Mandatory)]
                [string]$Agent,

                [hashtable]$InitialHiddenFields,

                [string]$InitialFormAction
            )

            $requiredFields = 'code', 'id_token', 'state', 'session_state'
            $hiddenFields = if ($InitialHiddenFields) { $InitialHiddenFields } else { @{} }
            $missingFields = @($requiredFields | Where-Object { -not $hiddenFields.ContainsKey($_) })

            if ($missingFields.Count -eq 0) {
                $landingUri = if ([string]::IsNullOrWhiteSpace($InitialFormAction)) { 'https://admin.cloud.microsoft/landing' } else { $InitialFormAction }
                $null = Invoke-WebRequest -MaximumRedirection 20 -WebSession $Session -Method Post -Uri $landingUri -Body $hiddenFields -UserAgent $Agent
                return (Invoke-M365PortalPostLandingBootstrap -WebSession $Session -UserAgent $Agent)
            }

            $portalBootstrapResponse = $null
            try {
                $portalBootstrapResponse = Invoke-WebRequest -MaximumRedirection 0 -WebSession $Session -Method Get -Uri 'https://admin.cloud.microsoft/login?ru=%2Fadminportal%3F' -UserAgent $Agent -ErrorAction Stop
            }
            catch {
                if (-not $_.Exception.Response) {
                    throw
                }

                $portalBootstrapResponse = $_.Exception.Response
            }

            $portalBootstrapContent = if ($portalBootstrapResponse.PSObject.Properties['Content']) {
                [string]$portalBootstrapResponse.Content
            }
            else {
                $null
            }

            $hiddenFields = @{}
            if ($portalBootstrapContent) {
                $hiddenFields = Get-HiddenFormFieldMap -Html $portalBootstrapContent
            }

            $missingFields = @($requiredFields | Where-Object { -not $hiddenFields.ContainsKey($_) })
            if ($missingFields.Count -gt 0) {
                $locationHeader = $null
                if ($portalBootstrapResponse.Headers) {
                    $locationHeader = $portalBootstrapResponse.Headers.Location
                    if (-not $locationHeader -and $portalBootstrapResponse.Headers['Location']) {
                        $locationHeader = $portalBootstrapResponse.Headers['Location']
                    }
                }

                $authorizeUrl = if ($locationHeader -is [string]) {
                    $locationHeader
                }
                elseif ($locationHeader) {
                    [string](@($locationHeader)[0])
                }
                else {
                    $null
                }

                if (-not [string]::IsNullOrWhiteSpace($authorizeUrl) -and $authorizeUrl -notmatch '^https?://') {
                    $authorizeUrl = 'https://login.microsoftonline.com' + $authorizeUrl
                }

                if ([string]::IsNullOrWhiteSpace($authorizeUrl) -and $portalBootstrapContent) {
                    $portalConfig = Get-LoginPageConfig -Content $portalBootstrapContent
                    $tenantSegment = if ($portalConfig.sTenantId) { [string]$portalConfig.sTenantId } else { 'common' }
                    $authorizeUrl = $portalConfig.urlTenantedEndpointFormat.Replace('{0}', $tenantSegment)
                }

                if ([string]::IsNullOrWhiteSpace($authorizeUrl)) {
                    throw 'Failed to determine the admin portal authorize URL.'
                }

                $authorizeResponse = Invoke-WebRequest -MaximumRedirection 20 -WebSession $Session -Method Get -Uri $authorizeUrl -UserAgent $Agent
                $hiddenFields = Get-HiddenFormFieldMap -Html $authorizeResponse.Content
                $missingFields = @($requiredFields | Where-Object { -not $hiddenFields.ContainsKey($_) })
                if ($missingFields.Count -gt 0) {
                    $authorizeConfig = $null
                    if ($authorizeResponse.Content -match '\$Config\s*=\s*\{') {
                        try {
                            $authorizeConfig = Get-LoginPageConfig -Content $authorizeResponse.Content
                        }
                        catch {
                            Write-Verbose 'Could not parse the authorize response page config while diagnosing the passkey handoff.'
                        }
                    }

                    $responseTitle = if ($authorizeResponse.Content) { Get-HtmlTitle -Html $authorizeResponse.Content } else { $null }
                    $diagnosticParts = @("Missing response fields: $($missingFields -join ', ')")
                    if ($responseTitle) {
                        $diagnosticParts += "Title: $responseTitle"
                    }
                    if ($authorizeConfig -and $authorizeConfig.PSObject.Properties['sErrorCode'] -and $authorizeConfig.sErrorCode) {
                        $diagnosticParts += "sErrorCode: $($authorizeConfig.sErrorCode)"
                    }
                    if ($authorizeConfig -and $authorizeConfig.PSObject.Properties['arrSessions'] -and $authorizeConfig.arrSessions) {
                        $diagnosticParts += "arrSessions: $(@($authorizeConfig.arrSessions).Count)"
                    }
                    if ($authorizeConfig -and $authorizeConfig.PSObject.Properties['sTenantId'] -and $authorizeConfig.sTenantId) {
                        $diagnosticParts += "sTenantId: $($authorizeConfig.sTenantId)"
                    }

                    throw "Failed to complete the admin portal authorization handoff. $($diagnosticParts -join '; ')."
                }
            }

            $null = Invoke-WebRequest -MaximumRedirection 20 -WebSession $Session -Method Post -Uri 'https://admin.cloud.microsoft/landing' -Body $hiddenFields -UserAgent $Agent
            Invoke-M365PortalPostLandingBootstrap -WebSession $Session -UserAgent $Agent
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

        $credential = Get-Content -LiteralPath $resolvedKeyFilePath -Raw | ConvertFrom-Json -Depth 5
        if ($credential.PSObject.Properties.Name -contains 'keyVault') {
            throw 'Azure Key Vault-backed passkeys are not yet supported by Invoke-M365PasskeyAuthentication. Use a local passkey file that contains a privateKey value.'
        }

        $requiredProperties = @('credentialId', 'privateKey', 'relyingParty', 'url', 'userHandle', 'username')
        $missingProperties = foreach ($propertyName in $requiredProperties) {
            if (-not $credential.PSObject.Properties[$propertyName] -or [string]::IsNullOrWhiteSpace([string]$credential.$propertyName)) {
                $propertyName
            }
        }
        if ($missingProperties) {
            throw "The passkey file is missing required properties: $($missingProperties -join ', ')."
        }

        $webSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
        $webSession.UserAgent = $UserAgent
        $loginState = Get-PasskeyRequestState -Session $webSession -Agent $UserAgent
        Invoke-GetCredentialTypeRequest -Session $webSession -LoginState $loginState -Username $credential.username -Agent $UserAgent

        $fidoState = Get-FidoChallengeState -Session $webSession -LoginState $loginState -PasskeyIds @([string]$credential.credentialId) -Username $credential.username -Agent $UserAgent
        $allowedCredentials = @($fidoState.Config.arrFidoAllowList)
        $credentialIdStandardBase64 = [Convert]::ToBase64String((ConvertFrom-Base64UrlString -Value $credential.credentialId))
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

        $assertion = Get-AssertionPayload -PasskeyCredential $credential -Challenge $fidoState.Config.sFidoChallenge -SignatureCounter $signatureCounter
        $assertionResult = Submit-FidoAssertion -Session $webSession -FidoState $fidoState -Assertion $assertion -Agent $UserAgent
        Complete-AdminPortalSignIn -Session $webSession -Agent $UserAgent -InitialHiddenFields $assertionResult.HiddenFields -InitialFormAction $assertionResult.FormAction
    }
}
