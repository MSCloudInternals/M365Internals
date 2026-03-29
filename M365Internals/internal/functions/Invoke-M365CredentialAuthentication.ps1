#region Private Helper Functions

function Get-M365TotpCode {
    <#
    .SYNOPSIS
        Computes a TOTP code from a base32-encoded secret.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Secret,
        [int]$Digits = 6,
        [int]$Period = 30
    )

    # Decode base32
    $base32Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    $cleanSecret = $Secret.ToUpper().TrimEnd('=') -replace '\s', ''
    $bits = ""
    foreach ($c in $cleanSecret.ToCharArray()) {
        $idx = $base32Chars.IndexOf($c)
        if ($idx -lt 0) { throw "Invalid base32 character: $c" }
        $bits += [Convert]::ToString($idx, 2).PadLeft(5, '0')
    }
    $keyBytes = [byte[]]::new([Math]::Floor($bits.Length / 8))
    for ($i = 0; $i -lt $keyBytes.Length; $i++) {
        $keyBytes[$i] = [Convert]::ToByte($bits.Substring($i * 8, 8), 2)
    }

    # Time counter
    $epoch = [long][Math]::Floor(([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) / $Period)
    $counterBytes = [BitConverter]::GetBytes($epoch)
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($counterBytes) }

    # HMAC-SHA1
    $hmac = New-Object System.Security.Cryptography.HMACSHA1(, $keyBytes)
    try {
        $hash = $hmac.ComputeHash($counterBytes)
    } finally {
        $hmac.Dispose()
    }

    # Dynamic truncation
    $offset = $hash[$hash.Length - 1] -band 0x0F
    $code = (($hash[$offset] -band 0x7F) -shl 24) -bor
    ($hash[$offset + 1] -shl 16) -bor
    ($hash[$offset + 2] -shl 8) -bor
    $hash[$offset + 3]

    return ($code % [Math]::Pow(10, $Digits)).ToString().PadLeft($Digits, '0')
}

function Test-M365MfaAuthSucceeded {
    param($Response)

    if (-not $Response) {
        return $false
    }

    if ($Response.ResultValue -eq 'AuthenticationSucceeded') {
        return $true
    }

    if ($Response.Success -eq $true -and $Response.ResultValue -eq 'Success') {
        return $true
    }

    return $false
}

function Get-M365EstsApiHeaderSet {
    param($AuthState)

    $headers = @{}
    if (-not $AuthState) {
        return $headers
    }

    if ($AuthState.canary) {
        $headers['canary'] = [string]$AuthState.canary
    }

    if ($AuthState.correlationId) {
        $headers['client-request-id'] = [string]$AuthState.correlationId
    }

    if ($null -ne $AuthState.hpgid) {
        $headers['hpgid'] = [string]$AuthState.hpgid
    }

    if ($null -ne $AuthState.hpgact) {
        $headers['hpgact'] = [string]$AuthState.hpgact
    }

    $headers['Accept'] = 'application/json'
    $headers['X-Requested-With'] = 'XMLHttpRequest'

    return $headers
}

function Test-M365ProcessAuthRetryableError {
    param($ParsedState)

    if (-not $ParsedState) {
        return $false
    }

    if ($ParsedState.iErrorCode -notin @(90014, 9000410)) {
        return $false
    }

    $message = [string]$ParsedState.strServiceExceptionMessage
    return (
        $message -match "required field .*request.* missing" -or
        $message -match 'Malformed JSON'
    )
}

function Get-M365ProcessAuthRequestBody {
    param(
        [Parameter(Mandatory)]
        [string]$SelectedMethod,
        [Parameter(Mandatory)]
        [string]$Username,
        [Parameter(Mandatory)]
        [string]$ProcessRequest,
        [Parameter(Mandatory)]
        $BeginAuth,
        [Parameter(Mandatory)]
        $AuthState,
        [Nullable[long]]$MfaLastPollStart,
        [Nullable[long]]$MfaLastPollEnd
    )

    if ($SelectedMethod -eq 'PhoneAppNotification') {
        $body = [ordered]@{
            type               = 22
            request            = $ProcessRequest
            mfaAuthMethod      = $SelectedMethod
            login              = $Username
            flowToken          = $BeginAuth.FlowToken
            hpgrequestid       = $AuthState.correlationId
            sacxt              = ''
            hideSmsInMfaProofs = 'false'
            canary             = $AuthState.canary
        }

        if ($null -ne $MfaLastPollStart) {
            $body['mfaLastPollStart'] = [string]$MfaLastPollStart
        }

        if ($null -ne $MfaLastPollEnd) {
            $body['mfaLastPollEnd'] = [string]$MfaLastPollEnd
        }

        if ($null -ne $AuthState.i19) {
            $body['i19'] = [string]$AuthState.i19
        }

        return $body
    }

    return @{
        type      = 22
        FlowToken = $BeginAuth.FlowToken
        request   = $ProcessRequest
        ctx       = $BeginAuth.Ctx
    } | ConvertTo-Json
}

function Get-M365AuthStateFromResponse {
    param($Response)

    if ($null -eq $Response -or [string]::IsNullOrWhiteSpace($Response.Content)) {
        return $null
    }

    if ($Response.Content -match '{(.*)}') {
        try {
            return $Matches[0] | ConvertFrom-Json
        } catch {
            return $null
        }
    }

    return $null
}

function Resolve-M365AuthAbsoluteUri {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [string]$BaseUri = 'https://login.microsoftonline.com/'
    )

    if ([string]::IsNullOrWhiteSpace($Uri)) {
        return $null
    }

    return [uri]::new([uri]$BaseUri, $Uri).AbsoluteUri
}

function Get-M365BestEstsCookieValue {
    param(
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session
    )

    $allCookies = @($Session.Cookies.GetCookies('https://login.microsoftonline.com'))
    $estsCookies = @($allCookies | Where-Object Name -Like 'ESTS*')
    if (-not $estsCookies) {
        return $null
    }

    $bestCookie = @(
        $allCookies | Where-Object Name -EQ 'ESTSAUTH'
        $allCookies | Where-Object Name -EQ 'ESTSAUTHPERSISTENT'
        $allCookies | Where-Object Name -EQ 'ESTSAUTHLIGHT'
        $estsCookies
    ) | Where-Object { $_ } | Sort-Object { $_.Value.Length } -Descending | Select-Object -First 1

    return $bestCookie.Value
}

function ConvertTo-M365FormUrlEncodedBody {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Data
    )

    return (@(
            foreach ($entry in $Data.GetEnumerator()) {
                "$([uri]::EscapeDataString([string]$entry.Key))=$([uri]::EscapeDataString([string]$entry.Value))"
            }
        ) -join '&')
}

function Get-M365HtmlFormPost {
    param($Response)

    if ($null -eq $Response -or [string]::IsNullOrWhiteSpace($Response.Content)) {
        return $null
    }

    $actionMatch = [regex]::Match($Response.Content, 'action="([^"]+)"')
    if (-not $actionMatch.Success) {
        return $null
    }

    $action = $actionMatch.Groups[1].Value

    $fields = [ordered]@{}
    foreach ($match in [regex]::Matches($Response.Content, '<input[^>]+name="([^"]+)"[^>]+value="([^"]*)"')) {
        $fields[$match.Groups[1].Value] = $match.Groups[2].Value
    }

    if ($fields.Count -eq 0) {
        return $null
    }

    return [pscustomobject]@{
        Action = $action
        Fields = $fields
        Body   = ConvertTo-M365FormUrlEncodedBody -Data $fields
    }
}

function Get-M365ResponseLocation {
    param($Response)

    if ($null -eq $Response) {
        return $null
    }

    if ($Response.Headers -and $Response.Headers.Location) {
        return [string]$Response.Headers.Location
    }

    if ($Response.BaseResponse -and $Response.BaseResponse.Headers -and $Response.BaseResponse.Headers['Location']) {
        return [string]$Response.BaseResponse.Headers['Location']
    }

    return $null
}

function Invoke-M365RedirectCapturingWebRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [string]$Method,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        $Body,
        $Headers,
        [string]$ContentType
    )

    $requestParams = @{
        Uri                = $Uri
        Method             = $Method
        UseBasicParsing    = $true
        SkipHttpErrorCheck = $true
        MaximumRedirection = 0
        Verbose            = $false
        ErrorAction        = 'SilentlyContinue'
    }

    if ($PSBoundParameters.ContainsKey('Session')) {
        $requestParams['WebSession'] = $Session
    }

    if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
        $requestParams['Body'] = $Body
    }

    if ($PSBoundParameters.ContainsKey('Headers') -and $null -ne $Headers) {
        $requestParams['Headers'] = $Headers
    }

    if ($PSBoundParameters.ContainsKey('ContentType') -and -not [string]::IsNullOrWhiteSpace($ContentType)) {
        $requestParams['ContentType'] = $ContentType
    }

    $redirectErrors = @()
    $response = Invoke-WebRequest @requestParams -ErrorVariable +redirectErrors
    if ($null -ne $response) {
        return $response
    }

    foreach ($errorRecord in $redirectErrors) {
        $redirectResponse = if ($errorRecord.Exception) { $errorRecord.Exception.Response } else { $null }
        if ($null -ne $redirectResponse -and (Get-M365ResponseLocation -Response $redirectResponse)) {
            return $redirectResponse
        }

        if ($errorRecord.Exception -and $errorRecord.Exception.Message -match 'maximum redirection count has been exceeded') {
            Write-Verbose "Captured redirect response from $Method $Uri after PowerShell reported the redirection limit."
            continue
        }

        throw $errorRecord
    }

    throw "Web request to '$Uri' did not return a usable response."
}

function Test-M365SecurityPortalFormPostResponse {
    param($Response)

    if ($null -eq $Response -or $null -eq $Response.InputFields) {
        return $false
    }

    $requiredFields = @('code', 'id_token', 'state', 'session_state', 'correlation_id')
    $inputNames = @($Response.InputFields | Where-Object { $_.name } | Select-Object -ExpandProperty name)

    foreach ($field in $requiredFields) {
        if ($inputNames -notcontains $field) {
            return $false
        }
    }

    return $true
}

function Complete-M365SecurityPortalFormPost {
    param(
        $Response,
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session
    )

    $requiredFields = @('code', 'id_token', 'state', 'session_state', 'correlation_id')
    $body = @{}
    foreach ($field in $requiredFields) {
        $body[$field] = $Response.InputFields | Where-Object name -EQ $field | Select-Object -ExpandProperty value
    }

    $postUri = if ($Response.BaseResponse -and $Response.BaseResponse.ResponseUri) {
        $Response.BaseResponse.ResponseUri.GetLeftPart([System.UriPartial]::Path)
    } else {
        'https://admin.cloud.microsoft/'
    }

    Write-Verbose "Completing portal form POST at $postUri"
    return Invoke-WebRequest -UseBasicParsing -Method Post -Uri $postUri -Body $body -WebSession $Session -MaximumRedirection 10 -SkipHttpErrorCheck -Verbose:$false
}

function Resolve-M365AuthenticationResponse {
    param(
        $Response,
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session
    )

    $currentResponse = $Response

    for ($redirectCount = 0; $redirectCount -lt 5 -and $null -ne $currentResponse; $redirectCount++) {
        $authState = Get-M365AuthStateFromResponse -Response $currentResponse
        if ($authState) {
            return [pscustomobject]@{
                AuthState = $authState
                Response  = $currentResponse
            }
        }

        if (Test-M365SecurityPortalFormPostResponse -Response $currentResponse) {
            $currentResponse = Complete-M365SecurityPortalFormPost -Response $currentResponse -Session $Session
            continue
        }

        $location = Get-M365ResponseLocation -Response $currentResponse
        if (-not $location) {
            break
        }

        $baseUri = if ($currentResponse.BaseResponse -and $currentResponse.BaseResponse.ResponseUri) {
            $currentResponse.BaseResponse.ResponseUri
        } else {
            [uri]'https://login.microsoftonline.com/'
        }

        $nextUri = [uri]::new($baseUri, $location)
        if ($nextUri.Scheme -notin @('http', 'https')) {
            Write-Verbose "Authentication redirect reached native callback URI $nextUri; stopping redirect resolution."
            break
        }

        Write-Verbose "Following authentication redirect to $nextUri"
        $currentResponse = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $nextUri -WebSession $Session -MaximumRedirection 10 -SkipHttpErrorCheck -Verbose:$false
    }

    return [pscustomobject]@{
        AuthState = (Get-M365AuthStateFromResponse -Response $currentResponse)
        Response  = $currentResponse
    }
}

function Get-M365SupportedMfaOption {
    param($AuthState)

    $descriptions = @{
        PhoneAppOTP          = 'Authenticator app code'
        PhoneAppNotification = 'Authenticator app approval'
        OneWaySMS            = 'Text message code'
    }

    $supportedMethods = [ordered]@{}
    foreach ($proof in @($AuthState.arrUserProofs)) {
        if (-not $proof.authMethodId -or -not $descriptions.ContainsKey($proof.authMethodId)) {
            continue
        }

        if ($supportedMethods.Contains($proof.authMethodId)) {
            continue
        }

        $supportedMethods[$proof.authMethodId] = [pscustomobject]@{
            AuthMethodId = $proof.authMethodId
            Description  = $descriptions[$proof.authMethodId]
            IsDefault    = [bool]$proof.isDefault
        }
    }

    return @(
        $supportedMethods.Values | Sort-Object -Property @(
            @{ Expression = { if ($_.IsDefault) { 0 } else { 1 } } },
            @{ Expression = { $_.AuthMethodId } }
        )
    )
}

function Select-M365MfaMethod {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    param(
        [Parameter(Mandatory)]
        [object[]]$SupportedMethods,
        [string]$PreferredMethod,
        [string]$TotpSecret
    )

    $supportedMethodIds = @($SupportedMethods | ForEach-Object AuthMethodId)

    if ($PreferredMethod) {
        if ($supportedMethodIds -contains $PreferredMethod) {
            return $PreferredMethod
        }

        throw "Requested MFA method '$PreferredMethod' is not offered for this sign-in. Supported methods: $($supportedMethodIds -join ', ')."
    }

    if ($TotpSecret -and $supportedMethodIds -contains 'PhoneAppOTP') {
        return 'PhoneAppOTP'
    }

    if ($SupportedMethods.Count -eq 1) {
        return $SupportedMethods[0].AuthMethodId
    }

    Write-Host 'Available MFA methods:'
    for ($i = 0; $i -lt $SupportedMethods.Count; $i++) {
        $method = $SupportedMethods[$i]
        $defaultSuffix = if ($method.IsDefault) { ' [default]' } else { '' }
        Write-Host "  [$($i + 1)] $($method.Description) ($($method.AuthMethodId))$defaultSuffix"
    }

    while ($true) {
        $selection = Read-Host "Select MFA method [1-$($SupportedMethods.Count)]"
        $index = 0
        if ([int]::TryParse($selection, [ref]$index) -and $index -ge 1 -and $index -le $SupportedMethods.Count) {
            return $SupportedMethods[$index - 1].AuthMethodId
        }

        Write-Host 'Invalid selection. Try again.'
    }
}

#endregion

function Invoke-M365CredentialAuthentication {
    <#
    .SYNOPSIS
        Performs username/password plus optional MFA authentication against Entra ID and
        returns the resulting ESTS authentication cookie value.

    .DESCRIPTION
        Implements the full Entra ID web login flow programmatically: submits credentials to the
        /authorize endpoint, handles MFA challenges via the SAS (Server Authentication State) endpoints,
        and processes interrupt pages (KMSI, CMSI, ConvergedSignIn).

        This is an internal function used by Connect-M365PortalByCredential.

        Supported MFA methods:
          - PhoneAppOTP: Authenticator app TOTP code (computed automatically from -TotpSecret)
          - PhoneAppNotification: Push notification (polls for user approval, displays number match)
          - OneWaySMS: SMS code (prompts user to enter code from phone)

    .PARAMETER Username
        The user principal name (e.g., admin@contoso.com).

    .PARAMETER Password
        The password as a SecureString. The plain-text value is materialized only
        immediately before it is submitted to the Entra ID sign-in form.

    .PARAMETER TotpSecret
        Base32-encoded TOTP secret for automatic MFA code generation.
        This is the secret from the QR code when setting up Microsoft Authenticator
        (otpauth://totp/...?secret=JBSWY3DPEHPK3PXP).
        If not provided and MFA is required, the function will attempt push notification
        or prompt for a code.

    .PARAMETER MfaMethod
        Preferred MFA method. Valid values: PhoneAppOTP, PhoneAppNotification, OneWaySMS.
        If not specified, PhoneAppOTP is auto-selected only when -TotpSecret is provided and
        that method is actually offered. Otherwise, the function chooses the only supported inline
        method or prompts you when multiple supported inline methods are available.

    .PARAMETER UserAgent
        User-Agent string for HTTP requests.

    .EXAMPLE
        $password = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
        Invoke-M365CredentialAuthentication -Username "admin@contoso.com" -Password $password -TotpSecret "JBSWY3DPEHPK3PXP"

        Authenticates with a SecureString password and returns the ESTS authentication cookie value.

    .OUTPUTS
        String - the ESTS authentication cookie value suitable for passing to Connect-M365Portal.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [SecureString]$Password,

        [string]$TotpSecret,

        [ValidateSet('PhoneAppOTP', 'PhoneAppNotification', 'OneWaySMS')]
        [string]$MfaMethod,

        [string]$UserAgent = (Get-M365DefaultUserAgent)
    )

    #region Establish session and initiate authentication flow
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $session.UserAgent = $UserAgent

    Write-Verbose "Initiating authentication flow for $Username..."
    $loginState = Get-M365AdminLoginState -WebSession $session -Username $Username -UserAgent $UserAgent
    $sessionInfo = $loginState.Config
    if (-not $sessionInfo) {
        throw 'Unexpected response from the M365 admin portal Entra sign-in bootstrap.'
    }

    if (-not $sessionInfo.urlPost) {
        if ($sessionInfo.sErrorCode) {
            throw "Authentication failed with error $($sessionInfo.sErrorCode): $($sessionInfo.sErrTxt)"
        }
        throw "Unexpected response: no urlPost in login page configuration."
    }
    Write-Verbose "Login page loaded (pgid: $($sessionInfo.pgid))"
    #endregion

    #region Submit credentials (type=11 = password)
    Write-Host "Submitting credentials for $Username..."
    $passwordHandle = [IntPtr]::Zero
    $plainPassword = $null

    try {
        $passwordHandle = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordHandle)

        $credBody = @{
            login        = $Username
            loginfmt     = $Username
            passwd       = $plainPassword
            type         = 11
            ps           = 2
            LoginOptions = 3
            flowToken    = $sessionInfo.sFT
            ctx          = $sessionInfo.sCtx
            canary       = $sessionInfo.canary
            hpgrequestid = $sessionInfo.correlationId
        }

        $credResponse = Invoke-WebRequest -UseBasicParsing -Method Post `
            -Uri (Resolve-M365AuthAbsoluteUri -Uri $sessionInfo.urlPost) `
            -Body $credBody `
            -WebSession $session -MaximumRedirection 0 -SkipHttpErrorCheck -Verbose:$false
    } finally {
        $plainPassword = $null
        if ($passwordHandle -ne [IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordHandle)
        }
    }

    $credOutcome = Resolve-M365AuthenticationResponse -Response $credResponse -Session $session
    $authState = $credOutcome.AuthState
    if (-not $authState) {
        throw "Unexpected response after credential submission."
    }

    # Check for credential errors
    if ($authState.sErrorCode) {
        $errorMessages = @{
            '50126' = "Invalid username or password."
            '50053' = "Account is locked. Too many failed sign-in attempts."
            '50057' = "Account is disabled."
            '50055' = "Password has expired."
            '50056' = "Invalid or null password."
            '53003' = "Blocked by Conditional Access policy."
            '50034' = "User account not found."
        }
        $msg = $errorMessages[$authState.sErrorCode]
        if (-not $msg) { $msg = $authState.sErrTxt }
        throw "Authentication failed ($($authState.sErrorCode)): $msg"
    }

    Write-Verbose "Credential submission succeeded (pgid: $($authState.pgid))"
    #endregion

    #region Handle MFA challenge (ConvergedTFA)
    if ($authState.pgid -eq 'ConvergedTFA') {
        Write-Host "MFA required."
        $sasHeaders = Get-M365EstsApiHeaderSet -AuthState $authState

        # Determine MFA method
        $supportedMethods = Get-M365SupportedMfaOption -AuthState $authState
        if (-not $supportedMethods) {
            $offeredMethods = @($authState.arrUserProofs | ForEach-Object authMethodId | Sort-Object -Unique)
            $offeredMethodsText = if ($offeredMethods) { $offeredMethods -join ', ' } else { 'none returned by service' }
            throw "No supported inline MFA methods were offered for this sign-in. Offered methods: $offeredMethodsText. Use Connect-M365BySoftwarePasskey for passkey-based methods."
        }

        $selectedMethod = Select-M365MfaMethod -SupportedMethods $supportedMethods -PreferredMethod $MfaMethod -TotpSecret $TotpSecret

        Write-Host "Using MFA method: $selectedMethod"
        Write-Verbose "Available methods: $(($supportedMethods | ForEach-Object { $_.AuthMethodId }) -join ', ')"

        $beginAuth = Invoke-M365SasBeginAuth -SelectedMethod $selectedMethod -AuthState $authState -Session $session -Headers $sasHeaders -BeginAuthUri 'https://login.microsoftonline.com/common/SAS/BeginAuth' -FailureLabel 'MFA'

        # Get the verification code based on method
        $verificationCode = $null
        $processAuthPollStart = $null
        $processAuthPollEnd = $null

        switch ($selectedMethod) {
            'PhoneAppOTP' {
                if ($TotpSecret) {
                    $verificationCode = Get-M365TotpCode -Secret $TotpSecret
                    Write-Verbose "Computed TOTP code: $verificationCode"
                } else {
                    Write-Host "Enter the code from your authenticator app:"
                    $verificationCode = Read-Host "Code"
                }
            }
            'OneWaySMS' {
                Write-Host "An SMS has been sent to your phone."
                Write-Host "Enter the verification code:"
                $verificationCode = Read-Host "Code"
            }
            'PhoneAppNotification' {
                # Push notification - poll for approval
                $entropy = $beginAuth.Entropy
                if ($entropy -and $entropy -gt 0) {
                    Write-Host "Approve the sign-in request in your Authenticator app."
                    Write-Host "Number to match: $entropy" -ForegroundColor Yellow
                } else {
                    Write-Host "Approve the sign-in request in your Authenticator app."
                }

                $pollOutcome = Invoke-M365SasPushNotificationPolling -SelectedMethod $selectedMethod -BeginAuth $beginAuth -AuthState $authState -Session $session -Headers $sasHeaders -EndAuthUri 'https://login.microsoftonline.com/common/SAS/EndAuth' -Deadline (Get-Date).AddSeconds(180) -FailureLabel 'Push notification' -TimeoutMessage 'Push notification timed out after {0} seconds.'
                $beginAuth = $pollOutcome.BeginAuth
                $processAuthPollStart = $pollOutcome.ProcessAuthPollStart
                $processAuthPollEnd = $pollOutcome.ProcessAuthPollEnd

                Write-Host "Push notification approved."
            }
        }

        # EndAuth - submit verification code (for OTP and SMS methods)
        if ($selectedMethod -ne 'PhoneAppNotification') {
            if (-not $verificationCode) {
                throw "No verification code provided for MFA method $selectedMethod."
            }

            $endBody = @{
                AuthMethodId       = $selectedMethod
                Method             = "EndAuth"
                SessionId          = $beginAuth.SessionId
                FlowToken          = $beginAuth.FlowToken
                Ctx                = $beginAuth.Ctx
                AdditionalAuthData = $verificationCode
                PollCount          = 1
            } | ConvertTo-Json

            Write-Verbose "Calling SAS/EndAuth with verification code..."
            $endAuth = Invoke-RestMethod -Method Post `
                -Uri "https://login.microsoftonline.com/common/SAS/EndAuth" `
                -Body $endBody -ContentType "application/json" `
                -Headers $sasHeaders `
                -WebSession $session -Verbose:$false

            if (-not (Test-M365MfaAuthSucceeded -Response $endAuth)) {
                $errDetail = if ($endAuth.Message) { $endAuth.Message } else { $endAuth.ResultValue }
                throw "MFA verification failed: $errDetail"
            }

            Write-Host "MFA verification succeeded."
            $beginAuth = $endAuth  # Carry forward FlowToken for ProcessAuth
        }

        $processOutcome = Invoke-M365SasProcessAuth -SelectedMethod $selectedMethod -Username $Username -BeginAuth $beginAuth -AuthState $authState -Session $session -Headers $sasHeaders -ProcessAuthUri 'https://login.microsoftonline.com/common/SAS/ProcessAuth' -MfaLastPollStart $processAuthPollStart -MfaLastPollEnd $processAuthPollEnd
        $processOutcome = $processOutcome.Outcome
        $authState = $processOutcome.AuthState

        if ($authState) {
            Write-Verbose "ProcessAuth completed (pgid: $($authState.pgid))"
        } else {
            Write-Verbose 'ProcessAuth completed with a non-JSON terminal response.'
        }
    }

    # Handle ConvergedProofUpRedirect (MFA registration prompt - skip it)
    if ($authState -and $authState.pgid -eq 'ConvergedProofUpRedirect') {
        Write-Verbose "MFA registration prompt detected, attempting to skip..."
        if ($authState.iRemainingDaysToSkipMfaRegistration -and $authState.iRemainingDaysToSkipMfaRegistration -gt 0) {
            $skipBody = @{
                type      = 22
                FlowToken = $authState.sFT
                request   = $authState.sProofUpAuthState
                ctx       = $authState.sProofUpAuthState
            } | ConvertTo-Json
            $skipResponse = Invoke-M365RedirectCapturingWebRequest `
                -Method Post `
                -Uri "https://login.microsoftonline.com/common/SAS/ProcessAuth" `
                -Body $skipBody `
                -ContentType "application/json" `
                -Headers (Get-M365EstsApiHeaderSet -AuthState $authState) `
                -Session $session

            $skipResponseState = Get-M365AuthStateFromResponse -Response $skipResponse

            if (Test-M365ProcessAuthRetryableError -ParsedState $skipResponseState) {
                $formSkipBody = @{
                    type         = 22
                    request      = $authState.sProofUpAuthState
                    flowToken    = $authState.sFT
                    ctx          = $authState.sProofUpAuthState
                    canary       = $authState.canary
                    hpgrequestid = $authState.correlationId
                }

                Write-Verbose 'Proof-up skip ProcessAuth returned a retryable request parsing error. Retrying with login-form style field names.'
                $skipResponse = Invoke-M365RedirectCapturingWebRequest `
                    -Method Post `
                    -Uri "https://login.microsoftonline.com/common/SAS/ProcessAuth" `
                    -Body $formSkipBody `
                    -Session $session

                $skipBody = $formSkipBody | ConvertTo-Json
                $skipResponseState = Get-M365AuthStateFromResponse -Response $skipResponse
            }

            $skipOutcome = Resolve-M365AuthenticationResponse -Response $skipResponse -Session $session
            $authState = $skipOutcome.AuthState
        } else {
            throw "MFA registration is required for this account and cannot be skipped."
        }
    }
    #endregion

    #region Handle interrupt pages (CmsiInterrupt, KmsiInterrupt, ConvergedSignIn)
    # This section is identical to the passkey flow interrupt handling
    $debug = $authState

    $interruptHandlers = @{
        "CmsiInterrupt"   = @{
            Uri    = "https://login.microsoftonline.com/appverify"
            Method = "Post"
            Body   = { @{
                    ContinueAuth    = "true"
                    i19             = Get-Random -Minimum 1000 -Maximum 9999
                    canary          = $debug.canary
                    iscsrfspeedbump = "false"
                    flowToken       = $debug.sFT
                    hpgrequestid    = $debug.correlationId
                    ctx             = $debug.sCtx
                } }
        }
        "KmsiInterrupt"   = @{
            Uri    = "https://login.microsoftonline.com/kmsi"
            Method = "Post"
            Body   = { @{
                    LoginOptions = 1
                    type         = 28
                    ctx          = $debug.sCtx
                    hpgrequestid = $debug.correlationId
                    flowToken    = $debug.sFT
                    canary       = $debug.canary
                    i19          = 4130
                } }
        }
        "ConvergedSignIn" = @{
            Uri    = {
                $sessionId = if ($null -ne $debug.arrSessions -and $null -ne $debug.arrSessions[0].id) { $debug.arrSessions[0].id } else { $debug.sessionId }
                Resolve-M365AuthAbsoluteUri -Uri "$($debug.urlLogin)&sessionid=$sessionId"
            }
            Method = "Get"
        }
    }

    $loopCount = 0
    $lastPageId = $null
    $authFailed = $false

    while ($debug -and $debug.pgid -in $interruptHandlers.Keys) {
        $currentPageId = $debug.pgid
        if ($currentPageId -eq $lastPageId -or ++$loopCount -gt 10) {
            $authFailed = $true
            Write-Verbose "Stuck in interrupt loop (lastPageId: $lastPageId, currentPageId: $currentPageId, loopCount: $loopCount)"
            break
        }
        $lastPageId = $currentPageId
        $handler = $interruptHandlers[$currentPageId]
        Write-Verbose "Handling interrupt: $currentPageId"

        $reqParams = @{
            Uri                = if ($handler.Uri -is [scriptblock]) { & $handler.Uri } else { $handler.Uri }
            Method             = $handler.Method
            WebSession         = $session
            UseBasicParsing    = $true
            SkipHttpErrorCheck = $true
            MaximumRedirection = 10
            Verbose            = $false
        }
        if ($handler.Body) { $reqParams.Body = & $handler.Body }

        $respFinalize = Invoke-WebRequest @reqParams
        Start-Sleep -Milliseconds 300

        $interruptOutcome = Resolve-M365AuthenticationResponse -Response $respFinalize -Session $session
        $debug = $interruptOutcome.AuthState
        if (-not $debug -or -not $debug.pgid) {
            break
        }
    }

    if ($authFailed) {
        throw "Authentication failed: stuck in interrupt page loop. Verify credentials and MFA configuration."
    }
    #endregion

    #region Verify and return ESTSAUTH cookie
    $allCookies = $session.Cookies.GetCookies("https://login.microsoftonline.com")
    Write-Verbose "Cookies present: $($allCookies.Name -join ', ')"

    $estsCookies = $allCookies | Where-Object Name -Like "ESTS*"
    if (-not $estsCookies) {
        throw "Authentication flow completed but no ESTS authentication cookie was obtained. Verify username, password, and MFA configuration."
    }

    # Pick the longest cookie (ESTSAUTHPERSISTENT is preferred when available)
    $bestCookie = @(
        $allCookies | Where-Object Name -EQ "ESTSAUTH"
        $allCookies | Where-Object Name -EQ "ESTSAUTHPERSISTENT"
        $allCookies | Where-Object Name -EQ "ESTSAUTHLIGHT"
    ) | Where-Object { $_ } | Sort-Object { $_.Value.Length } -Descending | Select-Object -First 1

    Write-Verbose "Obtained $($bestCookie.Name) cookie (length: $($bestCookie.Value.Length))"
    return $bestCookie.Value
    #endregion
}

