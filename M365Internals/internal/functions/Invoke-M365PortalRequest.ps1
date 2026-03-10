function Invoke-M365PortalRequest {
    <#
    .SYNOPSIS
        Sends a request to the Microsoft 365 admin portal.

    .DESCRIPTION
        Wraps Invoke-WebRequest for same-origin requests against admin.cloud.microsoft using the
        current M365Internals portal session and default headers. JSON responses are converted to
        objects automatically unless the raw web response is requested.

    .PARAMETER Path
        A portal-relative path such as '/admin/api/coordinatedbootstrap/shellinfo'.

    .PARAMETER Uri
        A fully qualified request URI.

    .PARAMETER Method
        The HTTP method to use.

    .PARAMETER Headers
        Additional headers to merge with the current portal connection headers.

    .PARAMETER Body
        An optional request body.

    .PARAMETER ContentType
        The request content type to use when a body is provided.

    .PARAMETER WebSession
        The web session to use. When omitted, the current portal connection session is used.

    .PARAMETER RawResponse
        Returns the full web response object instead of parsed content.

    .EXAMPLE
        Invoke-M365PortalRequest -Path '/admin/api/coordinatedbootstrap/shellinfo'

        Calls the shell info endpoint using the current portal session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Uri')]
        [string]$Uri,

        [ValidateSet('Get', 'Post', 'Put', 'Patch', 'Delete')]
        [string]$Method = 'Get',

        [hashtable]$Headers,

        $Body,

        [string]$ContentType,

        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [switch]$RawResponse
    )

    $resolvedSession = if ($WebSession) { $WebSession } else { $script:m365PortalSession }
    if (-not $resolvedSession) {
        throw 'No Microsoft 365 admin portal session is available. Run Connect-M365Portal first or provide -WebSession.'
    }

    $requestUri = if ($PSCmdlet.ParameterSetName -eq 'Uri') {
        $Uri
    }
    elseif ($Path.StartsWith('/')) {
        'https://admin.cloud.microsoft{0}' -f $Path
    }
    else {
        'https://admin.cloud.microsoft/{0}' -f $Path
    }

    $resolvedHeaders = @{}
    if ($script:m365PortalHeaders) {
        foreach ($headerEntry in @($script:m365PortalHeaders.GetEnumerator())) {
            $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
        }
    }
    if ($Headers) {
        foreach ($headerEntry in @($Headers.GetEnumerator())) {
            $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
        }
    }

    $invokeParams = @{
        Uri        = $requestUri
        Method     = $Method
        WebSession = $resolvedSession
        Headers    = $resolvedHeaders
        ErrorAction = 'Stop'
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        if ($PSBoundParameters.ContainsKey('ContentType')) {
            $invokeParams.ContentType = $ContentType
            $invokeParams.Body = $Body
        }
        elseif ($Body -is [string]) {
            $invokeParams.ContentType = 'application/json'
            $invokeParams.Body = $Body
        }
        else {
            $invokeParams.ContentType = 'application/json'
            $invokeParams.Body = $Body | ConvertTo-Json -Depth 10
        }
    }

    try {
        $response = Invoke-WebRequest @invokeParams
    }
    catch {
        throw "Portal request failed for $Method $requestUri. $($_.Exception.Message)"
    }

    if ($RawResponse) {
        return $response
    }

    $responseContentType = $response.Headers['Content-Type']
    if ($responseContentType -match 'json' -and -not [string]::IsNullOrWhiteSpace($response.Content)) {
        try {
            return $response.Content | ConvertFrom-Json -Depth 20
        }
        catch {
            return $response.Content
        }
    }

    $response.Content
}