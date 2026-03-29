function Connect-M365Portal {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal.

    .DESCRIPTION
        Establishes a reusable session for admin.cloud.microsoft by accepting either
        already-captured portal artifacts or by running one of the built-in Entra sign-in
        flows used by the Microsoft 365 admin center.

        Browser sign-in is the preferred/default connection path for interactive use.
        Supported connection paths include:
          - browser-derived admin portal cookies
          - an existing WebRequestSession
          - an ESTS authentication cookie
          - username/password with optional MFA
          - Temporary Access Pass
          - Microsoft Authenticator phone sign-in
          - interactive browser sign-in
          - browser-based SSO
          - local software passkey sign-in

        After the session is prepared, the cmdlet validates it against the same-origin
        portal bootstrap endpoints used by the admin experience and stores the live session
        for later M365Internals cmdlets.

    .PARAMETER RootAuthToken
        The RootAuthToken cookie value from admin.cloud.microsoft.

    .PARAMETER SPAAuthCookie
        The SPAAuthCookie cookie value from admin.cloud.microsoft.

    .PARAMETER OIDCAuthCookie
        The OIDCAuthCookie cookie value from admin.cloud.microsoft.

    .PARAMETER AjaxSessionKey
        The s.AjaxSessionKey cookie value from admin.cloud.microsoft.

    .PARAMETER SessionId
        The optional s.SessID cookie value from admin.cloud.microsoft.

    .PARAMETER TenantId
        The optional s.UserTenantId cookie value from admin.cloud.microsoft.

    .PARAMETER PortalRouteKey
        The optional x-portal-routekey cookie value from admin.cloud.microsoft.

    .PARAMETER WebSession
        An authenticated WebRequestSession that already contains the required admin portal cookies.

    .PARAMETER EstsAuthCookieValue
        The ESTSAUTHPERSISTENT cookie value from login.microsoftonline.com as plain text.

    .PARAMETER SecureEstsAuthCookieValue
        The ESTSAUTHPERSISTENT cookie value from login.microsoftonline.com as a secure string.

    .PARAMETER Credential
        A PSCredential object containing the username and password to submit through the
        Entra web sign-in flow.

    .PARAMETER Password
        The password to use with the explicit credential parameter set. Pair this with
        -Username or allow the cmdlet to prompt for the username interactively.

    .PARAMETER Username
        The username used by the credential, Temporary Access Pass, phone sign-in, or
        browser sign-in flows. When connecting from a captured portal cookie set, this
        also maps to the optional s.userid cookie value. UserId is retained as an alias
        for that cookie-based input.

    .PARAMETER TotpSecret
        Optional Base32-encoded TOTP secret used to automatically complete Authenticator
        app OTP challenges during credential-based sign-in.

    .PARAMETER MfaMethod
        Preferred MFA method for credential-based sign-in. Supported values are
        PhoneAppOTP, PhoneAppNotification, and OneWaySMS.

    .PARAMETER TemporaryAccessPass
        The Temporary Access Pass to use for Entra sign-in. Alias: TAP.

    .PARAMETER PhoneSignIn
        Uses the Microsoft Authenticator phone sign-in flow to obtain an ESTS-authenticated session.

    .PARAMETER BrowserSignIn
        Uses an interactive Chromium-based browser sign-in flow and captures admin portal
        or ESTS cookies from the completed session. Alias: Browser.

    .PARAMETER SSO
        Uses browser-based single sign-on to capture an authenticated admin portal session.
        This flow currently supports Windows only for now.

    .PARAMETER KeyFilePath
        Path to a local software passkey JSON file used for native Entra FIDO sign-in.

    .PARAMETER UserAgent
        The user agent string used for bootstrap requests.

    .PARAMETER SkipValidation
        Skips the admin portal validation probes after the session is prepared.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for phone sign-in, browser sign-in, or SSO authentication to complete.

    .PARAMETER BrowserPath
        Optional Chromium-based browser executable path or command name used by the browser
        and SSO authentication flows.

    .PARAMETER ProfilePath
        Optional browser profile path used by the browser or SSO authentication flows.

    .PARAMETER ResetProfile
        Clears the dedicated browser profile before launching browser sign-in.

    .PARAMETER PrivateSession
        Uses a temporary private/incognito browser session for interactive browser sign-in.

    .PARAMETER Visible
        Shows the browser window during SSO authentication instead of using the default headless launch.

    .EXAMPLE
        Connect-M365Portal

        Launches the preferred interactive browser sign-in flow and connects to the Microsoft 365 admin portal.

    .EXAMPLE
        Connect-M365Portal -RootAuthToken $root -SPAAuthCookie $spa -OIDCAuthCookie $oidc -AjaxSessionKey $ajax

        Connects by loading browser-derived admin.cloud.microsoft cookies into a web session.

    .EXAMPLE
        Connect-M365Portal -WebSession $session

        Connects by reusing an existing web session that already contains the required portal cookies.

    .EXAMPLE
        Connect-M365Portal -EstsAuthCookieValue $estsCookie

        Connects by exchanging an ESTSAUTHPERSISTENT cookie through the admin portal sign-in flow.

    .EXAMPLE
        Connect-M365Portal -Credential (Get-Credential) -TotpSecret 'JBSWY3DPEHPK3PXP'

        Connects by using the programmatic Entra credential flow with automatic Authenticator OTP handling.

    .EXAMPLE
        Connect-M365Portal -Username 'admin@contoso.com' -TAP $tap

        Connects by using a Temporary Access Pass and then bootstraps the Microsoft 365 admin session.

    .EXAMPLE
        Connect-M365Portal -BrowserSignIn -PrivateSession

        Launches a private browser session, waits for interactive sign-in, and captures the
        resulting admin portal authentication artifacts.

    .EXAMPLE
        Connect-M365Portal -SSO -Visible

        Launches a visible browser window and attempts to capture a Microsoft 365 admin session
        through browser-based single sign-on on Windows for now.

    .OUTPUTS
        M365Portal.Connection
        Returns details about the active admin portal connection. Username is the canonical
        sign-in name. UserId carries the same value for compatibility with existing callers
        and the default connection view.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Portal cookie parameters are consumed through local helper closures inside the cmdlet process block')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates only the in-memory session state for the current PowerShell session')]
    [CmdletBinding(DefaultParameterSetName = 'BrowserSignIn')]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'PortalCookies')]
        [string]$RootAuthToken,

        [Parameter(Mandatory, ParameterSetName = 'PortalCookies')]
        [string]$SPAAuthCookie,

        [Parameter(Mandatory, ParameterSetName = 'PortalCookies')]
        [string]$OIDCAuthCookie,

        [Parameter(Mandatory, ParameterSetName = 'PortalCookies')]
        [string]$AjaxSessionKey,

        [Parameter(ParameterSetName = 'PortalCookies')]
        [string]$SessionId,

        [Parameter(ParameterSetName = 'PortalCookies')]
        [Parameter(ParameterSetName = 'EstsPlainText')]
        [Parameter(ParameterSetName = 'EstsSecureString')]
        [Parameter(ParameterSetName = 'Credential')]
        [Parameter(ParameterSetName = 'CredentialExplicit')]
        [Parameter(ParameterSetName = 'TemporaryAccessPass')]
        [Parameter(ParameterSetName = 'PhoneSignIn')]
        [Parameter(ParameterSetName = 'BrowserSignIn')]
        [Parameter(ParameterSetName = 'SSO')]
        [Parameter(ParameterSetName = 'SoftwarePasskey')]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'PortalCookies')]
        [string]$PortalRouteKey,

        [Parameter(Mandatory, ParameterSetName = 'WebSession')]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory, ParameterSetName = 'EstsPlainText', ValueFromPipeline)]
        [string]$EstsAuthCookieValue,

        [Parameter(Mandatory, ParameterSetName = 'EstsSecureString', ValueFromPipeline)]
        [System.Security.SecureString]$SecureEstsAuthCookieValue,

        [Parameter(Mandatory, ParameterSetName = 'Credential')]
        [PSCredential]$Credential,

        [Parameter(Mandatory, ParameterSetName = 'CredentialExplicit')]
        [SecureString]$Password,

        [Parameter(ParameterSetName = 'PortalCookies')]
        [Parameter(ParameterSetName = 'CredentialExplicit')]
        [Parameter(ParameterSetName = 'TemporaryAccessPass')]
        [Parameter(ParameterSetName = 'PhoneSignIn')]
        [Parameter(ParameterSetName = 'BrowserSignIn')]
        [Alias('UserId')]
        [string]$Username,

        [Parameter(ParameterSetName = 'Credential')]
        [Parameter(ParameterSetName = 'CredentialExplicit')]
        [string]$TotpSecret,

        [Parameter(ParameterSetName = 'Credential')]
        [Parameter(ParameterSetName = 'CredentialExplicit')]
        [ValidateSet('PhoneAppOTP', 'PhoneAppNotification', 'OneWaySMS')]
        [string]$MfaMethod,

        [Parameter(Mandatory, ParameterSetName = 'TemporaryAccessPass')]
        [Alias('TAP')]
        [SecureString]$TemporaryAccessPass,

        [Parameter(Mandatory, ParameterSetName = 'PhoneSignIn')]
        [switch]$PhoneSignIn,

        [Parameter(ParameterSetName = 'BrowserSignIn')]
        [Alias('Browser')]
        [switch]$BrowserSignIn,

        [Parameter(Mandatory, ParameterSetName = 'SSO')]
        [switch]$SSO,

        [Parameter(Mandatory, ParameterSetName = 'SoftwarePasskey')]
        [string]$KeyFilePath,

        [Parameter(ParameterSetName = 'PortalCookies')]
        [Parameter(ParameterSetName = 'WebSession')]
        [Parameter(ParameterSetName = 'EstsPlainText')]
        [Parameter(ParameterSetName = 'EstsSecureString')]
        [Parameter(ParameterSetName = 'Credential')]
        [Parameter(ParameterSetName = 'CredentialExplicit')]
        [Parameter(ParameterSetName = 'TemporaryAccessPass')]
        [Parameter(ParameterSetName = 'PhoneSignIn')]
        [Parameter(ParameterSetName = 'BrowserSignIn')]
        [Parameter(ParameterSetName = 'SSO')]
        [Parameter(ParameterSetName = 'SoftwarePasskey')]
        [string]$UserAgent = (Get-M365DefaultUserAgent),

        [Parameter(ParameterSetName = 'PortalCookies')]
        [Parameter(ParameterSetName = 'WebSession')]
        [Parameter(ParameterSetName = 'EstsPlainText')]
        [Parameter(ParameterSetName = 'EstsSecureString')]
        [Parameter(ParameterSetName = 'Credential')]
        [Parameter(ParameterSetName = 'CredentialExplicit')]
        [Parameter(ParameterSetName = 'TemporaryAccessPass')]
        [Parameter(ParameterSetName = 'PhoneSignIn')]
        [Parameter(ParameterSetName = 'BrowserSignIn')]
        [Parameter(ParameterSetName = 'SSO')]
        [Parameter(ParameterSetName = 'SoftwarePasskey')]
        [switch]$SkipValidation,

        [Parameter(ParameterSetName = 'PhoneSignIn')]
        [Parameter(ParameterSetName = 'BrowserSignIn')]
        [Parameter(ParameterSetName = 'SSO')]
        [ValidateRange(30, 1800)]
        [int]$TimeoutSeconds = 300,

        [Parameter(ParameterSetName = 'BrowserSignIn')]
        [Parameter(ParameterSetName = 'SSO')]
        [string]$BrowserPath,

        [Parameter(ParameterSetName = 'BrowserSignIn')]
        [Parameter(ParameterSetName = 'SSO')]
        [string]$ProfilePath,

        [Parameter(ParameterSetName = 'BrowserSignIn')]
        [switch]$ResetProfile,

        [Parameter(ParameterSetName = 'BrowserSignIn')]
        [switch]$PrivateSession,

        [Parameter(ParameterSetName = 'SSO')]
        [switch]$Visible
    )

    begin {
        Clear-M365Cache -All
    }

    process {
        function ConvertTo-PlainText {
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

        function Add-CookieToSession {
            param (
                [Parameter(Mandatory)]
                [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

                [Parameter(Mandatory)]
                [string]$Name,

                [Parameter(Mandatory)]
                [string]$Value,

                [Parameter(Mandatory)]
                [string]$Domain
            )

            $cookie = [System.Net.Cookie]::new($Name, $Value, '/', $Domain)
            $Session.Cookies.Add($cookie)
        }

        function New-PortalCookieSession {
            param (
                [Parameter(Mandatory)]
                [string]$ResolvedUserAgent
            )

            $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            $session.UserAgent = $ResolvedUserAgent

            Add-CookieToSession -Session $session -Name 'RootAuthToken' -Value $RootAuthToken -Domain 'admin.cloud.microsoft'
            Add-CookieToSession -Session $session -Name 'SPAAuthCookie' -Value $SPAAuthCookie -Domain 'admin.cloud.microsoft'
            Add-CookieToSession -Session $session -Name 'OIDCAuthCookie' -Value $OIDCAuthCookie -Domain 'admin.cloud.microsoft'
            Add-CookieToSession -Session $session -Name 's.AjaxSessionKey' -Value $AjaxSessionKey -Domain 'admin.cloud.microsoft'

            if ($SessionId) {
                Add-CookieToSession -Session $session -Name 's.SessID' -Value $SessionId -Domain 'admin.cloud.microsoft'
            }
            if ($TenantId) {
                Add-CookieToSession -Session $session -Name 's.UserTenantId' -Value $TenantId -Domain 'admin.cloud.microsoft'
            }
            if ($Username) {
                Add-CookieToSession -Session $session -Name 's.userid' -Value $Username -Domain 'admin.cloud.microsoft'
            }
            if ($PortalRouteKey) {
                Add-CookieToSession -Session $session -Name 'x-portal-routekey' -Value $PortalRouteKey -Domain 'admin.cloud.microsoft'
            }

            $session
        }

        function New-PortalSessionFromEstsCookie {
            param (
                [Parameter(Mandatory)]
                [string]$ResolvedEstsAuthCookieValue,

                [Parameter(Mandatory)]
                [string]$ResolvedUserAgent
            )

            $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            $session.UserAgent = $ResolvedUserAgent

            $null = Invoke-WebRequest -MaximumRedirection 10 -ErrorAction SilentlyContinue -WebSession $session -Method Get -Uri 'https://login.microsoftonline.com/error'
            foreach ($cookieName in @('ESTSAUTH', 'ESTSAUTHPERSISTENT')) {
                Add-CookieToSession -Session $session -Name $cookieName -Value $ResolvedEstsAuthCookieValue -Domain 'login.microsoftonline.com'
            }
            Complete-M365AdminPortalSignIn -WebSession $session -UserAgent $ResolvedUserAgent
        }

        switch ($PSCmdlet.ParameterSetName) {
            'Credential' {
                $credentialAuthParams = @{
                    Username  = $Credential.UserName
                    Password  = $Credential.Password
                    UserAgent = $UserAgent
                }
                if (-not [string]::IsNullOrWhiteSpace($TotpSecret)) {
                    $credentialAuthParams.TotpSecret = $TotpSecret
                }
                if (-not [string]::IsNullOrWhiteSpace($MfaMethod)) {
                    $credentialAuthParams.MfaMethod = $MfaMethod
                }

                $estsAuth = Invoke-M365CredentialAuthentication @credentialAuthParams
                return Connect-M365AuthArtifactSet -EstsAuthCookieValue $estsAuth -TenantId $TenantId -UserAgent $UserAgent -SkipValidation:$SkipValidation -AuthFlow 'Credential' -FailureLabel 'Credential authentication'
            }
            'CredentialExplicit' {
                $resolvedUsername = $Username
                if (-not $resolvedUsername) {
                    $resolvedUsername = Read-Host 'Username'
                }

                if (-not $resolvedUsername) {
                    throw 'No username provided.'
                }

                $credentialAuthParams = @{
                    Username  = $resolvedUsername
                    Password  = $Password
                    UserAgent = $UserAgent
                }
                if (-not [string]::IsNullOrWhiteSpace($TotpSecret)) {
                    $credentialAuthParams.TotpSecret = $TotpSecret
                }
                if (-not [string]::IsNullOrWhiteSpace($MfaMethod)) {
                    $credentialAuthParams.MfaMethod = $MfaMethod
                }

                $estsAuth = Invoke-M365CredentialAuthentication @credentialAuthParams
                return Connect-M365AuthArtifactSet -EstsAuthCookieValue $estsAuth -TenantId $TenantId -UserAgent $UserAgent -SkipValidation:$SkipValidation -AuthFlow 'Credential' -FailureLabel 'Credential authentication'
            }
            'TemporaryAccessPass' {
                $resolvedUsername = $Username
                if (-not $resolvedUsername) {
                    $resolvedUsername = Read-Host 'Username'
                }

                if (-not $resolvedUsername) {
                    throw 'No username provided.'
                }

                $resolvedTenantId = if ($TenantId) { $TenantId } else { Resolve-M365TenantIdFromUsername -Username $resolvedUsername -UserAgent $UserAgent }
                $estsAuth = Invoke-M365TemporaryAccessPassAuthentication -Username $resolvedUsername -TemporaryAccessPass $TemporaryAccessPass -TenantId $resolvedTenantId -UserAgent $UserAgent
                return Connect-M365AuthArtifactSet -EstsAuthCookieValue $estsAuth -TenantId $resolvedTenantId -UserAgent $UserAgent -SkipValidation:$SkipValidation -AuthFlow 'TemporaryAccessPass' -FailureLabel 'Temporary Access Pass authentication'
            }
            'PhoneSignIn' {
                $resolvedUsername = $Username
                if (-not $resolvedUsername) {
                    $resolvedUsername = Read-Host 'Username'
                }

                if (-not $resolvedUsername) {
                    throw 'No username provided.'
                }

                $phoneParams = @{
                    Username  = $resolvedUsername
                    UserAgent = $UserAgent
                }
                if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) {
                    $phoneParams.TimeoutSeconds = $TimeoutSeconds
                }

                $estsAuth = Invoke-M365PhoneSignInAuthentication @phoneParams
                return Connect-M365AuthArtifactSet -EstsAuthCookieValue $estsAuth -TenantId $TenantId -UserAgent $UserAgent -SkipValidation:$SkipValidation -AuthFlow 'PhoneSignIn' -FailureLabel 'Phone sign-in'
            }
            'BrowserSignIn' {
                $browserParams = @{
                    UserAgent = $UserAgent
                }
                if ($PSBoundParameters.ContainsKey('Username')) {
                    $browserParams.Username = $Username
                }
                if ($TenantId) {
                    $browserParams.TenantId = $TenantId
                }
                if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) {
                    $browserParams.TimeoutSeconds = $TimeoutSeconds
                }
                if ($BrowserPath) {
                    $browserParams.BrowserPath = $BrowserPath
                }
                if ($ProfilePath) {
                    $browserParams.ProfilePath = $ProfilePath
                }
                if ($ResetProfile) {
                    $browserParams.ResetProfile = $true
                }
                if ($PrivateSession) {
                    $browserParams.PrivateSession = $true
                }

                $browserAuth = Invoke-M365BrowserAuthentication @browserParams
                return Connect-M365AuthArtifactSet -EstsAuthCookieValue $browserAuth.EstsAuthCookieValue -PortalWebSession $browserAuth.PortalWebSession -TenantId $TenantId -UserAgent $UserAgent -SkipValidation:$SkipValidation -AuthFlow 'BrowserSignIn' -ConnectionPreference PreferPortal -FailureLabel 'Browser sign-in'
            }
            'SSO' {
                $ssoParams = @{
                    UserAgent = $UserAgent
                    Visible   = $Visible
                }
                if ($TenantId) {
                    $ssoParams.TenantId = $TenantId
                }
                if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) {
                    $ssoParams.TimeoutSeconds = $TimeoutSeconds
                }
                if ($BrowserPath) {
                    $ssoParams.BrowserPath = $BrowserPath
                }
                if ($ProfilePath) {
                    $ssoParams.ProfilePath = $ProfilePath
                }

                $ssoAuth = Invoke-M365SsoAuthentication @ssoParams
                return Connect-M365AuthArtifactSet -EstsAuthCookieValue $ssoAuth.EstsAuthCookieValue -PortalWebSession $ssoAuth.PortalWebSession -TenantId $TenantId -UserAgent $UserAgent -SkipValidation:$SkipValidation -AuthFlow 'SSO' -ConnectionPreference PreferPortal -FailureLabel 'SSO authentication'
            }
            'SoftwarePasskey' {
                $portalSession = Invoke-M365PasskeyAuthentication -KeyFilePath $KeyFilePath -UserAgent $UserAgent
                return Connect-M365AuthArtifactSet -PortalWebSession $portalSession -TenantId $TenantId -UserAgent $UserAgent -SkipValidation:$SkipValidation -AuthFlow 'SoftwarePasskey' -ConnectionPreference PreferPortal -FailureLabel 'Software passkey authentication'
            }
        }

        $resolvedSession = switch ($PSCmdlet.ParameterSetName) {
            'PortalCookies' {
                New-PortalCookieSession -ResolvedUserAgent $UserAgent
                break
            }
            'WebSession' {
                if ($UserAgent) {
                    $WebSession.UserAgent = $UserAgent
                }
                $WebSession
                break
            }
            'EstsPlainText' {
                New-PortalSessionFromEstsCookie -ResolvedEstsAuthCookieValue $EstsAuthCookieValue -ResolvedUserAgent $UserAgent
                break
            }
            'EstsSecureString' {
                $resolvedEstsCookie = ConvertTo-PlainText -SecureString $SecureEstsAuthCookieValue
                New-PortalSessionFromEstsCookie -ResolvedEstsAuthCookieValue $resolvedEstsCookie -ResolvedUserAgent $UserAgent
                break
            }
        }

        $authSource = switch ($PSCmdlet.ParameterSetName) {
            'PortalCookies' { 'PortalCookies' }
            'WebSession' { 'WebSession' }
            default { 'ESTSAUTHPERSISTENT' }
        }

        $authFlow = switch ($PSCmdlet.ParameterSetName) {
            'PortalCookies' { 'PortalCookies' }
            'WebSession' { 'WebSession' }
            default { 'EstsCookie' }
        }

        Set-M365PortalConnectionSettings -WebSession $resolvedSession -AuthSource $authSource -AuthFlow $authFlow -UserAgent $UserAgent -SkipValidation:$SkipValidation
    }
}
