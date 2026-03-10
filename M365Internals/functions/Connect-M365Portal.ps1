function Connect-M365Portal {
    <#
    .SYNOPSIS
        Connects to the Microsoft 365 admin portal.

    .DESCRIPTION
        Establishes a reusable session for admin.cloud.microsoft using one of three inputs:
        browser-derived portal cookies, an existing WebRequestSession, or an
        ESTSAUTHPERSISTENT cookie that can be exchanged through the portal sign-in flow.

        After the session is prepared, the cmdlet validates it against the same-origin portal
        bootstrap endpoints used by the admin experience and stores the live session for
        later M365Internals cmdlets.

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

    .PARAMETER UserId
        The optional s.userid cookie value from admin.cloud.microsoft.

    .PARAMETER PortalRouteKey
        The optional x-portal-routekey cookie value from admin.cloud.microsoft.

    .PARAMETER WebSession
        An authenticated WebRequestSession that already contains the required admin portal cookies.

    .PARAMETER EstsAuthCookieValue
        The ESTSAUTHPERSISTENT cookie value from login.microsoftonline.com as plain text.

    .PARAMETER SecureEstsAuthCookieValue
        The ESTSAUTHPERSISTENT cookie value from login.microsoftonline.com as a secure string.

    .PARAMETER UserAgent
        The user agent string used for bootstrap requests.

    .PARAMETER SkipValidation
        Skips the admin portal validation probes after the session is prepared.

    .EXAMPLE
        Connect-M365Portal -RootAuthToken $root -SPAAuthCookie $spa -OIDCAuthCookie $oidc -AjaxSessionKey $ajax

        Connects by loading browser-derived admin.cloud.microsoft cookies into a web session.

    .EXAMPLE
        Connect-M365Portal -WebSession $session

        Connects by reusing an existing web session that already contains the required portal cookies.

    .EXAMPLE
        Connect-M365Portal -EstsAuthCookieValue $estsCookie

        Connects by exchanging an ESTSAUTHPERSISTENT cookie through the admin portal sign-in flow.

    .OUTPUTS
        M365Portal.Connection
        Returns details about the active admin portal connection.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Portal cookie parameters are consumed through local helper closures inside the cmdlet process block')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates only the in-memory session state for the current PowerShell session')]
    [CmdletBinding(DefaultParameterSetName = 'PortalCookies')]
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
        [string]$TenantId,

        [Parameter(ParameterSetName = 'PortalCookies')]
        [string]$UserId,

        [Parameter(ParameterSetName = 'PortalCookies')]
        [string]$PortalRouteKey,

        [Parameter(Mandatory, ParameterSetName = 'WebSession')]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory, ParameterSetName = 'EstsPlainText', ValueFromPipeline)]
        [string]$EstsAuthCookieValue,

        [Parameter(Mandatory, ParameterSetName = 'EstsSecureString', ValueFromPipeline)]
        [System.Security.SecureString]$SecureEstsAuthCookieValue,

        [Parameter(ParameterSetName = 'PortalCookies')]
        [Parameter(ParameterSetName = 'WebSession')]
        [Parameter(ParameterSetName = 'EstsPlainText')]
        [Parameter(ParameterSetName = 'EstsSecureString')]
        [string]$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0',

        [Parameter(ParameterSetName = 'PortalCookies')]
        [Parameter(ParameterSetName = 'WebSession')]
        [Parameter(ParameterSetName = 'EstsPlainText')]
        [Parameter(ParameterSetName = 'EstsSecureString')]
        [switch]$SkipValidation
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
            if ($UserId) {
                Add-CookieToSession -Session $session -Name 's.userid' -Value $UserId -Domain 'admin.cloud.microsoft'
            }
            if ($PortalRouteKey) {
                Add-CookieToSession -Session $session -Name 'x-portal-routekey' -Value $PortalRouteKey -Domain 'admin.cloud.microsoft'
            }

            $session
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
            Add-CookieToSession -Session $session -Name 'ESTSAUTHPERSISTENT' -Value $ResolvedEstsAuthCookieValue -Domain 'login.microsoftonline.com'

            try {
                $signInResponse = Invoke-WebRequest -MaximumRedirection 20 -ErrorAction Stop -WebSession $session -Method Get -Uri 'https://admin.cloud.microsoft/'
            }
            catch {
                throw "Failed to start the admin portal sign-in flow with the supplied ESTS cookie. $($_.Exception.Message)"
            }

            $hiddenFields = Get-HiddenFormFieldMap -Html $signInResponse.Content
            $requiredFields = 'code', 'id_token', 'state', 'session_state'
            $missingFields = @($requiredFields | Where-Object { -not $hiddenFields.ContainsKey($_) })
            if ($missingFields.Count -gt 0) {
                $portalBootstrapResponse = $null
                try {
                    $portalBootstrapResponse = Invoke-WebRequest -MaximumRedirection 0 -WebSession $session -Method Get -Uri 'https://admin.cloud.microsoft/login?ru=%2Fadminportal%3F' -UserAgent $ResolvedUserAgent -ErrorAction Stop
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

                    $authorizeResponse = Invoke-WebRequest -MaximumRedirection 20 -WebSession $session -Method Get -Uri $authorizeUrl -UserAgent $ResolvedUserAgent
                    $hiddenFields = Get-HiddenFormFieldMap -Html $authorizeResponse.Content
                    $missingFields = @($requiredFields | Where-Object { -not $hiddenFields.ContainsKey($_) })
                    if ($missingFields.Count -gt 0) {
                        $authorizeConfig = $null
                        if ($authorizeResponse.Content -match '\$Config\s*=\s*\{') {
                            try {
                                $authorizeConfig = Get-LoginPageConfig -Content $authorizeResponse.Content
                            }
                            catch {
                            }
                        }

                        $responseUri = if ($authorizeResponse.BaseResponse -and $authorizeResponse.BaseResponse.ResponseUri) {
                            [string]$authorizeResponse.BaseResponse.ResponseUri
                        }
                        elseif ($authorizeResponse.PSObject.Properties['Url']) {
                            [string]$authorizeResponse.Url
                        }
                        else {
                            $null
                        }

                        $responseTitle = if ($authorizeResponse.Content) {
                            Get-HtmlTitle -Html $authorizeResponse.Content
                        }
                        else {
                            $null
                        }

                        $diagnosticParts = @(
                            "Missing response fields: $($missingFields -join ', ')"
                        )
                        if ($responseUri) {
                            $diagnosticParts += "ResponseUri: $responseUri"
                        }
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

                        throw "Failed to exchange the ESTS cookie into an admin portal session. $($diagnosticParts -join '; ')."
                    }
                }
            }

            try {
                $null = Invoke-WebRequest -MaximumRedirection 20 -ErrorAction Stop -WebSession $session -Method Post -Uri 'https://admin.cloud.microsoft/landing' -Body $hiddenFields
            }
            catch {
                throw "Failed to complete the admin portal landing flow after ESTS sign-in. $($_.Exception.Message)"
            }

            Invoke-M365PortalPostLandingBootstrap -WebSession $session -UserAgent $ResolvedUserAgent
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

        Set-M365PortalConnectionSettings -WebSession $resolvedSession -AuthSource $authSource -UserAgent $UserAgent -SkipValidation:$SkipValidation
    }
}