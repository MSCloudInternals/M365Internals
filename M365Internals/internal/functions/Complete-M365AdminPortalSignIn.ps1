function Complete-M365AdminPortalSignIn {
    <#
    .SYNOPSIS
        Completes the admin.cloud.microsoft landing/bootstrap flow for an authenticated session.

    .DESCRIPTION
        Finishes the Microsoft 365 admin portal handoff after an Entra-authenticated session
        has been established. When the caller already has the hidden form fields returned by
        Entra, those are posted directly to the admin landing endpoint. Otherwise the helper
        re-enters the admin bootstrap, resolves the authorize URL, and extracts the required
        response fields before completing the landing flow.

        The returned web session is ready for the normal post-landing bootstrap used by the
        rest of M365Internals.

    .PARAMETER WebSession
        The authenticated WebRequestSession to complete through the admin portal landing flow.

    .PARAMETER UserAgent
        User-Agent string used for the landing and bootstrap requests.

    .PARAMETER InitialHiddenFields
        Optional hidden form fields already captured from the Entra response.

    .PARAMETER InitialFormAction
        Optional form action URL associated with the captured Entra response fields.

    .EXAMPLE
        Complete-M365AdminPortalSignIn -WebSession $session -UserAgent (Get-M365DefaultUserAgent)

        Completes the Microsoft 365 admin portal landing flow for the authenticated session.
    #>
    [OutputType([Microsoft.PowerShell.Commands.WebRequestSession])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [string]$UserAgent = (Get-M365DefaultUserAgent),

        [hashtable]$InitialHiddenFields,

        [string]$InitialFormAction
    )

    function Get-HiddenFormFieldMap {
        param(
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

        return $fields
    }

    function Get-FormAction {
        param(
            [Parameter(Mandatory)]
            [string]$Html
        )

        $formMatch = [regex]::Match($Html, '<form\b[^>]*action=["''](?<value>[^"'']+)["'']', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $formMatch.Success) {
            return $null
        }

        return [System.Net.WebUtility]::HtmlDecode($formMatch.Groups['value'].Value)
    }

    function Get-HtmlTitle {
        param(
            [Parameter(Mandatory)]
            [string]$Html
        )

        $titleMatch = [regex]::Match($Html, '<title[^>]*>(?<value>.*?)</title>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $titleMatch.Success) {
            return $null
        }

        return [System.Net.WebUtility]::HtmlDecode($titleMatch.Groups['value'].Value).Trim()
    }

    function Get-MissingRequiredFieldName {
        param(
            [Parameter(Mandatory)]
            [hashtable]$Fields
        )

        return @(
            $requiredFields | Where-Object {
                -not $Fields.ContainsKey($_) -or [string]::IsNullOrWhiteSpace([string]$Fields[$_])
            }
        )
    }

    function Get-ResponseLocation {
        param(
            $Response
        )

        if ($null -eq $Response) {
            return $null
        }

        if ($Response.Headers) {
            if ($Response.Headers.Location) {
                return [string]$Response.Headers.Location
            }

            if ($Response.Headers['Location']) {
                return [string](@($Response.Headers['Location'])[0])
            }
        }

        if ($Response.BaseResponse -and $Response.BaseResponse.Headers -and $Response.BaseResponse.Headers['Location']) {
            return [string]$Response.BaseResponse.Headers['Location']
        }

        return $null
    }

    function Get-AuthorizeInterruptState {
        param(
            $Response
        )

        if ($null -eq $Response -or -not $Response.PSObject.Properties['Content']) {
            return $null
        }

        $responseContent = [string]$Response.Content
        if ([string]::IsNullOrWhiteSpace($responseContent) -or $responseContent -notmatch '\$Config\s*=\s*\{') {
            return $null
        }

        try {
            return Get-M365LoginPageConfig -Content $responseContent
        }
        catch {
            Write-Verbose 'Could not parse the ESTS page config while resolving the admin portal authorize handoff.'
            return $null
        }
    }

    function Resolve-AuthorizeInterruptResult {
        param(
            [Parameter(Mandatory)]
            $Response
        )

        $currentResponse = $Response
        $lastPageId = $null
        $loopCount = 0

        while ($null -ne $currentResponse -and $loopCount -lt 10) {
            $currentContent = if ($currentResponse.PSObject.Properties['Content']) {
                [string]$currentResponse.Content
            }
            else {
                $null
            }

            $currentHiddenFields = if ([string]::IsNullOrWhiteSpace($currentContent)) {
                @{}
            }
            else {
                Get-HiddenFormFieldMap -Html $currentContent
            }

            $currentMissingFields = @(Get-MissingRequiredFieldName -Fields $currentHiddenFields)
            $currentFormAction = if ([string]::IsNullOrWhiteSpace($currentContent)) {
                $null
            }
            else {
                Get-FormAction -Html $currentContent
            }

            $currentAuthState = Get-AuthorizeInterruptState -Response $currentResponse
            if ($currentMissingFields.Count -eq 0 -or -not $currentAuthState -or [string]::IsNullOrWhiteSpace([string]$currentAuthState.pgid)) {
                return [pscustomobject]@{
                    Response      = $currentResponse
                    HiddenFields  = $currentHiddenFields
                    MissingFields = $currentMissingFields
                    FormAction    = $currentFormAction
                    AuthState     = $currentAuthState
                }
            }

            $currentPageId = [string]$currentAuthState.pgid
            if ($currentPageId -notin @('CmsiInterrupt', 'KmsiInterrupt', 'ConvergedSignIn')) {
                return [pscustomobject]@{
                    Response      = $currentResponse
                    HiddenFields  = $currentHiddenFields
                    MissingFields = $currentMissingFields
                    FormAction    = $currentFormAction
                    AuthState     = $currentAuthState
                }
            }

            if ($currentPageId -eq $lastPageId) {
                Write-Verbose "Stopped the admin portal authorize handoff after repeating interrupt page '$currentPageId'."
                break
            }

            $lastPageId = $currentPageId
            $loopCount++
            Write-Verbose "Handling admin portal authorize interrupt '$currentPageId'."

            $interruptMethod = 'GET'
            $interruptUri = $null
            $interruptBody = $null

            switch ($currentPageId) {
                'CmsiInterrupt' {
                    $interruptMethod = 'POST'
                    $interruptUri = 'https://login.microsoftonline.com/appverify'
                    $interruptBody = @{
                        ContinueAuth    = 'true'
                        i19             = Get-Random -Minimum 1000 -Maximum 9999
                        canary          = $currentAuthState.canary
                        iscsrfspeedbump = 'false'
                        flowToken       = $currentAuthState.sFT
                        hpgrequestid    = $currentAuthState.correlationId
                        ctx             = $currentAuthState.sCtx
                    }
                }
                'KmsiInterrupt' {
                    $interruptMethod = 'POST'
                    $interruptUri = 'https://login.microsoftonline.com/kmsi'
                    $interruptBody = @{
                        LoginOptions = 1
                        type         = 28
                        ctx          = $currentAuthState.sCtx
                        hpgrequestid = $currentAuthState.correlationId
                        flowToken    = $currentAuthState.sFT
                        canary       = $currentAuthState.canary
                        i19          = 4130
                    }
                }
                'ConvergedSignIn' {
                    $sessionId = if ($null -ne $currentAuthState.arrSessions -and $null -ne $currentAuthState.arrSessions[0].id) {
                        $currentAuthState.arrSessions[0].id
                    }
                    else {
                        $currentAuthState.sessionId
                    }

                    if ([string]::IsNullOrWhiteSpace([string]$sessionId) -or [string]::IsNullOrWhiteSpace([string]$currentAuthState.urlLogin)) {
                        break
                    }

                    $interruptUri = Resolve-M365EstsUrl -Url "$($currentAuthState.urlLogin)&sessionid=$sessionId"
                }
            }

            if ([string]::IsNullOrWhiteSpace([string]$interruptUri)) {
                break
            }

            $requestParams = @{
                Uri                = $interruptUri
                Method             = $interruptMethod
                WebSession         = $WebSession
                MaximumRedirection = 10
                UserAgent          = $UserAgent
                ErrorAction        = 'Stop'
            }

            if ($interruptMethod -eq 'POST' -and $null -ne $interruptBody) {
                $requestParams.Body = $interruptBody
            }

            $currentResponse = Invoke-WebRequest @requestParams
        }

        $finalContent = if ($currentResponse -and $currentResponse.PSObject.Properties['Content']) {
            [string]$currentResponse.Content
        }
        else {
            $null
        }

        $finalHiddenFields = if ([string]::IsNullOrWhiteSpace($finalContent)) {
            @{}
        }
        else {
            Get-HiddenFormFieldMap -Html $finalContent
        }

        return [pscustomobject]@{
            Response      = $currentResponse
            HiddenFields  = $finalHiddenFields
            MissingFields = @(Get-MissingRequiredFieldName -Fields $finalHiddenFields)
            FormAction    = if ([string]::IsNullOrWhiteSpace($finalContent)) { $null } else { Get-FormAction -Html $finalContent }
            AuthState     = Get-AuthorizeInterruptState -Response $currentResponse
        }
    }

    if ($UserAgent) {
        $WebSession.UserAgent = $UserAgent
    }

    $requiredFields = 'code', 'id_token', 'state', 'session_state'
    $hiddenFields = if ($InitialHiddenFields) { $InitialHiddenFields } else { @{} }
    $missingFields = @(Get-MissingRequiredFieldName -Fields $hiddenFields)

    if ($missingFields.Count -gt 0) {
        $portalBootstrapResponse = $null
        try {
            $portalBootstrapResponse = Invoke-WebRequest -MaximumRedirection 0 -WebSession $WebSession -Method Get -Uri 'https://admin.cloud.microsoft/login?ru=%2Fadminportal%3F' -UserAgent $UserAgent -ErrorAction Stop
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
            $authorizeUrl = Get-ResponseLocation -Response $portalBootstrapResponse

            if (-not [string]::IsNullOrWhiteSpace($authorizeUrl) -and $authorizeUrl -notmatch '^https?://') {
                $authorizeUrl = 'https://login.microsoftonline.com' + $authorizeUrl
            }

            if ([string]::IsNullOrWhiteSpace($authorizeUrl) -and $portalBootstrapContent) {
                $portalConfig = Get-M365LoginPageConfig -Content $portalBootstrapContent
                $tenantSegment = if ($portalConfig.sTenantId) { [string]$portalConfig.sTenantId } else { 'common' }
                $authorizeUrl = Resolve-M365EstsUrl -Url ($portalConfig.urlTenantedEndpointFormat.Replace('{0}', $tenantSegment))
            }

            if ([string]::IsNullOrWhiteSpace($authorizeUrl)) {
                throw 'Failed to determine the admin portal authorize URL.'
            }

            $authorizeResponse = Invoke-WebRequest -MaximumRedirection 20 -WebSession $WebSession -Method Get -Uri $authorizeUrl -UserAgent $UserAgent
            $authorizeResult = Resolve-AuthorizeInterruptResult -Response $authorizeResponse
            $hiddenFields = $authorizeResult.HiddenFields
            $missingFields = $authorizeResult.MissingFields
            if ($missingFields.Count -gt 0) {
                $authorizeConfig = $authorizeResult.AuthState

                $finalAuthorizeResponse = $authorizeResult.Response
                $responseUri = if ($finalAuthorizeResponse.BaseResponse -and $finalAuthorizeResponse.BaseResponse.ResponseUri) {
                    [string]$finalAuthorizeResponse.BaseResponse.ResponseUri
                }
                elseif ($finalAuthorizeResponse.PSObject.Properties['Url']) {
                    [string]$finalAuthorizeResponse.Url
                }
                else {
                    $null
                }

                $responseTitle = if ($finalAuthorizeResponse.Content) {
                    Get-HtmlTitle -Html $finalAuthorizeResponse.Content
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
                if ($authorizeConfig -and $authorizeConfig.PSObject.Properties['pgid'] -and $authorizeConfig.pgid) {
                    $diagnosticParts += "pgid: $($authorizeConfig.pgid)"
                }

                throw "Failed to exchange the ESTS session into an admin portal session. $($diagnosticParts -join '; ')."
            }

            $InitialFormAction = if ($InitialFormAction) { $InitialFormAction } else { $authorizeResult.FormAction }
        }
    }

    $landingUri = if ([string]::IsNullOrWhiteSpace($InitialFormAction)) { 'https://admin.cloud.microsoft/landing' } else { $InitialFormAction }
    $tokenMetadata = Get-M365JwtTokenMetadata -Token $hiddenFields['id_token'] -Source 'AdminPortalIdToken'

    try {
        $null = Invoke-WebRequest -MaximumRedirection 20 -WebSession $WebSession -Method Post -Uri $landingUri -Body $hiddenFields -UserAgent $UserAgent -ErrorAction Stop
    }
    catch {
        throw "Failed to complete the admin portal landing flow. $($_.Exception.Message)"
    }

    if ($tokenMetadata) {
        $WebSession | Add-Member -NotePropertyName M365TokenMetadata -NotePropertyValue $tokenMetadata -Force
        $WebSession | Add-Member -NotePropertyName M365TokenRefreshSatisfiedUntilUtc -NotePropertyValue $null -Force
    }

    return Invoke-M365PortalPostLandingBootstrap -WebSession $WebSession -UserAgent $UserAgent
}
