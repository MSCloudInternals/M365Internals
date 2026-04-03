function Invoke-M365TemporaryAccessPassAuthentication {
    <#
    .SYNOPSIS
        Performs Temporary Access Pass authentication against Entra ID and returns the
        resulting ESTS authentication artifacts.

    .DESCRIPTION
        Implements the Entra ID TAP web sign-in flow used by the Microsoft 365 admin bootstrap,
        then extracts the resulting ESTS authentication artifacts so they can be passed to Connect-M365Portal.

        TAP sign-in is tenant-scoped. The same TenantId is used for the Entra authorize request and is
        typically passed on to Connect-M365Portal so the admin portal opens the intended tenant.

        This is an internal function used by Connect-M365PortalByTemporaryAccessPass.

    .PARAMETER Username
        The user principal name (e.g., admin@contoso.com).

    .PARAMETER TemporaryAccessPass
        The Temporary Access Pass as a SecureString.

    .PARAMETER TenantId
        The Entra tenant ID used for the TAP authorize request.

    .PARAMETER UserAgent
        User-Agent string for HTTP requests.

    .OUTPUTS
        PSCustomObject - contains the ESTS authentication cookie value and the authenticated web session.

    .EXAMPLE
        $tap = ConvertTo-SecureString 'ABC12345' -AsPlainText -Force
        Invoke-M365TemporaryAccessPassAuthentication -Username 'admin@contoso.com' -TemporaryAccessPass $tap -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2'

        Performs the internal TAP sign-in flow and returns the ESTS authentication artifacts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [SecureString]$TemporaryAccessPass,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [string]$UserAgent = (Get-M365DefaultUserAgent)
    )

    $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    $session.UserAgent = $UserAgent

    Write-Verbose "Initiating TAP authentication flow for $Username in tenant $TenantId"
    $loginState = Get-M365AdminLoginState -WebSession $session -Username $Username -TenantId $TenantId -UserAgent $UserAgent
    $config = $loginState.Config

    if (-not $config) {
        throw 'Unexpected response from the M365 admin portal TAP authentication bootstrap.'
    }

    $tapHandle = [IntPtr]::Zero
    $plainTap = $null

    try {
        $tapHandle = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TemporaryAccessPass)
        $plainTap = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($tapHandle)

        $loginBody = [ordered]@{
            login             = $Username
            loginfmt          = $Username
            accesspass        = $plainTap
            ps                = '56'
            psRNGCDefaultType = '1'
            psRNGCEntropy     = ''
            psRNGCSLK         = [string]$config.sFT
            canary            = [string]$config.canary
            ctx               = [string]$config.sCtx
            hpgrequestid      = [string]$(if ($config.sessionId) { $config.sessionId } else { $config.correlationId })
            flowToken         = [string]$config.sFT
            PPSX              = ''
            NewUser           = '1'
            FoundMSAs         = ''
            fspost            = '0'
            i21               = '0'
            CookieDisclosure  = '0'
            IsFidoSupported   = '1'
            isSignupPost      = '0'
            DfpArtifact       = ''
            i19               = '10000'
        }
        $encodedLoginBody = ConvertTo-M365FormUrlEncodedBody -Data $loginBody
    } finally {
        $plainTap = $null
        if ($tapHandle -ne [IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tapHandle)
        }
    }

    $currentUrl = Resolve-M365AuthAbsoluteUri -Uri $(if ($config.urlPost) { $config.urlPost } else { 'https://login.microsoftonline.com/common/login' }) -BaseUri 'https://login.microsoftonline.com/'
    $currentMethod = 'POST'
    $currentBody = $encodedLoginBody

    for ($step = 0; $step -lt 15; $step++) {
        try {
            $requestParams = @{
                Uri                = $currentUrl
                Method             = $currentMethod
                WebSession         = $session
                UseBasicParsing    = $true
                MaximumRedirection = 0
                Verbose            = $false
            }
            if ($currentMethod -eq 'POST' -and $null -ne $currentBody) {
                $requestParams['Body'] = $currentBody
                $requestParams['ContentType'] = 'application/x-www-form-urlencoded'
            }

            $response = Invoke-WebRequest @requestParams -ErrorAction Stop
            $parsedState = Get-M365AuthStateFromResponse -Response $response

            $formPost = Get-M365HtmlFormPost -Response $response
            if ($response.StatusCode -eq 200 -and $formPost) {
                $currentUrl = Resolve-M365AuthAbsoluteUri -Uri $formPost.Action -BaseUri $currentUrl
                $currentMethod = 'POST'
                $currentBody = $formPost.Body
                continue
            }

            if ($parsedState -and $parsedState.sErrorCode) {
                throw "TAP authentication failed ($($parsedState.sErrorCode)): $($parsedState.sErrTxt)"
            }

            break
        } catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            $response = $_.Exception.Response
            $statusCode = [int]$response.StatusCode

            if ($statusCode -lt 300 -or $statusCode -ge 400) {
                throw
            }

            $location = Get-M365ResponseLocation -Response $response
            if (-not $location) {
                throw 'TAP authentication redirected without a Location header.'
            }

            $resolvedLocation = Resolve-M365AuthAbsoluteUri -Uri $location -BaseUri $currentUrl
            if ($resolvedLocation -match '[#?&]code=') {
                break
            }

            if ($resolvedLocation -match 'error=') {
                throw "TAP authentication failed: $resolvedLocation"
            }

            $currentUrl = $resolvedLocation
            $currentMethod = 'GET'
            $currentBody = $null
            continue
        }
    }

    $bestCookie = Get-M365BestEstsCookieValue -Session $session
    if (-not $bestCookie) {
        throw 'No ESTS authentication cookie was found after TAP authentication.'
    }

    Write-Verbose "Obtained ESTS cookie (length: $($bestCookie.Length))"
    return New-M365EstsAuthenticationResult -WebSession $session -EstsAuthCookieValue $bestCookie
}

