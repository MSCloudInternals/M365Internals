function Invoke-M365AdminRestMethod {
    <#
    .SYNOPSIS
        Invokes a REST API call to the Microsoft 365 admin center.

    .DESCRIPTION
        Executes REST API requests against admin.cloud.microsoft by using the active portal
        session and headers established by Connect-M365Portal. Before each request, the cmdlet
        refreshes the stored portal connection settings from the current cookie jar so headers
        such as AjaxSessionKey and x-portal-routekey stay in sync with the session.
        Requests use the HTTPS admin.cloud.microsoft origin. Reads may follow up to five
        redirects within that origin. Writes make one attempt and report an unconfirmed
        outcome if a redirect or transport failure prevents confirmation.

    .PARAMETER Uri
        The fully qualified HTTPS request URI on admin.cloud.microsoft.

    .PARAMETER Path
        The portal-relative path to call, such as '/admin/api/coordinatedbootstrap/shellinfo'.

    .PARAMETER Method
        The HTTP method to use for the request. Defaults to 'Get'.

    .PARAMETER ContentType
        The content type to use for the request. Defaults to 'application/json'.

    .PARAMETER WebSession
        The web session to use for the request. Defaults to the current script-scoped portal session.

    .PARAMETER Headers
        Additional headers to merge with the current portal headers.

    .PARAMETER Body
        The request body, if applicable.

    .EXAMPLE
        Invoke-M365AdminRestMethod -Path '/admin/api/coordinatedbootstrap/shellinfo'

        Makes a GET request to the shell info endpoint by using the active admin portal session.

    .EXAMPLE
        Invoke-M365AdminRestMethod -Uri 'https://admin.cloud.microsoft/adminportal/home/ClassicModernAdminDataStream' -Headers @{ 'x-adminapp-request' = '/homepage' }

        Makes a GET request to a fully qualified admin portal endpoint with an additional header.

    .EXAMPLE
        Invoke-M365AdminRestMethod -Path '/admin/api/example' -Method Post -Body @{ enabled = $true }

        Makes a POST request and serializes the body as JSON.

    .OUTPUTS
        Object
        Returns the parsed response object from the admin center endpoint.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Uri')]
        [string]$Uri,

        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [string]$Path,

        [ValidateSet('Get', 'Post', 'Put', 'Patch', 'Delete')]
        [string]$Method = 'Get',

        [string]$ContentType = 'application/json',

        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession = $script:m365PortalSession,

        [hashtable]$Headers,

        $Body
    )

    begin {
        $requestUri = if ($PSCmdlet.ParameterSetName -eq 'Uri') {
            $Uri
        }
        elseif ($Path.StartsWith('/')) {
            'https://admin.cloud.microsoft{0}' -f $Path
        }
        else {
            'https://admin.cloud.microsoft/{0}' -f $Path
        }
        Assert-M365AdminPortalUri -Uri $requestUri

        if (-not $WebSession) {
            throw 'No Microsoft 365 admin portal session is available. Run Connect-M365Portal first or provide -WebSession.'
        }

        if ($WebSession -eq $script:m365PortalSession) {
            Update-M365PortalConnectionSettings
        }
        else {
            $authSource = if ($script:m365PortalConnection -and $script:m365PortalConnection.Source) {
                $script:m365PortalConnection.Source
            }
            else {
                'WebSession'
            }

            $null = Set-M365PortalConnectionSettings -WebSession $WebSession -AuthSource $authSource -UserAgent $WebSession.UserAgent -SkipValidation
        }
    }

    process {
        $resolvedHeaders = @{}
        foreach ($headerEntry in @($script:m365PortalHeaders.GetEnumerator())) {
            $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
        }
        if ($Headers) {
            foreach ($headerEntry in @($Headers.GetEnumerator())) {
                $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
            }
        }

        $resolvedContentType = if ($PSBoundParameters.ContainsKey('ContentType')) {
            $ContentType
        }
        elseif ($PSBoundParameters.ContainsKey('Body')) {
            'application/json'
        }

        $invokeParams = @{
            Uri         = $requestUri
            Method      = $Method
            WebSession  = $WebSession
            Headers     = $resolvedHeaders
            MaximumRedirection = 0
            ErrorAction = 'Stop'
        }

        if (-not [string]::IsNullOrWhiteSpace($resolvedContentType)) {
            $invokeParams.ContentType = $resolvedContentType
        }

        if ($PSBoundParameters.ContainsKey('Body')) {
            if (($Body -isnot [string]) -and $resolvedContentType -match 'json') {
                $invokeParams.Body = $Body | ConvertTo-Json -Depth 10
            }
            else {
                $invokeParams.Body = $Body
            }
        }

        $previousMaximumRedirection = $WebSession.MaximumRedirection
        try {
            $redirectCount = 0
            while ($true) {
                try {
                    return Invoke-RestMethod -Debug:$false -Verbose:$false @invokeParams
                }
                catch {
                    $responseProperty = $_.Exception.PSObject.Properties['Response']
                    $response = if ($responseProperty) { $responseProperty.Value }
                    $statusCode = if ($response) {
                        [int]$response.StatusCode
                    }
                    elseif ($_.Exception -is [System.Net.Http.HttpRequestException]) {
                        [int]$_.Exception.StatusCode
                    }
                    else {
                        0
                    }

                    if ($Method -eq 'Get' -and $response -and $statusCode -in @(301, 302, 303, 307, 308)) {
                        if ($redirectCount -ge 5) {
                            throw 'The admin read exceeded the maximum of five redirects.'
                        }
                        $location = if ($response.Headers -is [System.Net.Http.Headers.HttpResponseHeaders]) {
                            $response.Headers.Location
                        }
                        else {
                            $response.Headers['Location']
                        }
                        if (-not $location) {
                            throw 'The admin read received a redirect without a Location header.'
                        }
                        $nextUri = $null
                        if (-not [uri]::TryCreate([uri]$invokeParams.Uri, [string]$location, [ref]$nextUri)) {
                            throw 'The admin read received an invalid redirect Location.'
                        }

                        Assert-M365AdminPortalUri -Uri $nextUri.AbsoluteUri
                        $invokeParams.Uri = $nextUri.AbsoluteUri
                        $redirectCount++
                        continue
                    }

                    $detail = Get-M365SafeFailureDetail -ErrorRecord $_ -HttpStatusCode $statusCode
                    if ($Method -ne 'Get' -and ($statusCode -lt 400 -or $statusCode -eq 408 -or $statusCode -ge 500)) {
                        throw "Failed to invoke M365 REST method ($Method). The write outcome is unconfirmed. $detail"
                    }
                    throw "Failed to invoke M365 REST method ($Method). $detail"
                }
            }
        }
        finally {
            $WebSession.MaximumRedirection = $previousMaximumRedirection
        }
    }
}
