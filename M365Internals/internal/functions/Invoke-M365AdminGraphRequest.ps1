function Invoke-M365AdminGraphRequest {
    <#
    .SYNOPSIS
        Sends a request through the Microsoft 365 admin center Graph proxy.

    .DESCRIPTION
        Calls the admin.cloud.microsoft fd/msgraph proxy endpoints using the active portal session
        and current cookie-derived headers. The helper also acquires a GraphAT token from the admin
        center broker so tenant metadata such as the anchor mailbox tenant ID can be derived for
        proxied requests.

    .PARAMETER Path
        A Graph-relative path such as '/beta/$batch' or '/v1.0/me'.

    .PARAMETER Uri
        A fully qualified Graph proxy URI.

    .PARAMETER Method
        The HTTP method to use.

    .PARAMETER AdminAppRequest
        Supplies the x-adminapp-request header used by the originating admin page.

    .PARAMETER Headers
        Additional headers to merge with the current request headers.

    .PARAMETER Body
        An optional request body.

    .PARAMETER ContentType
        The request content type to use when a body is provided.

    .PARAMETER IncludeAuthorizationHeader
        Adds the brokered GraphAT token as an Authorization header. The portal proxy requests in the
        HAR are same-origin and do not require this by default, so the switch is off unless needed.

    .PARAMETER GraphScenario
        The scenario value used when requesting the GraphAT token.

    .EXAMPLE
        Invoke-M365AdminGraphRequest -Path '/beta/$batch' -Method Post -AdminAppRequest '/Settings/enhancedRestore' -Body $payload

        Sends a batch request through the admin center Graph proxy.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Uri')]
        [string]$Uri,

        [ValidateSet('Get', 'Post', 'Put', 'Patch', 'Delete')]
        [string]$Method = 'Get',

        [Parameter(Mandatory)]
        [string]$AdminAppRequest,

        [hashtable]$Headers,

        $Body,

        [string]$ContentType = 'application/json',

        [switch]$IncludeAuthorizationHeader,

        [string]$GraphScenario = 'main'
    )

    Update-M365PortalConnectionSettings

    $graphToken = Get-M365AdminAccessToken -TokenType GraphAT -Scenario $GraphScenario -AdminAppRequest $AdminAppRequest

    $requestUri = if ($PSCmdlet.ParameterSetName -eq 'Uri') {
        $Uri
    }
    elseif ($Path -match '^https://') {
        $Path
    }
    elseif ($Path.StartsWith('/fd/msgraph/')) {
        'https://admin.cloud.microsoft{0}' -f $Path
    }
    elseif ($Path.StartsWith('/')) {
        'https://admin.cloud.microsoft/fd/msgraph{0}' -f $Path
    }
    else {
        'https://admin.cloud.microsoft/fd/msgraph/{0}' -f $Path
    }

    $resolvedHeaders = @{}
    foreach ($headerEntry in @($script:m365PortalHeaders.GetEnumerator())) {
        $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
    }

    $resolvedHeaders['Accept'] = 'application/json;odata=minimalmetadata, text/plain, */*'
    $resolvedHeaders['client-request-id'] = [guid]::NewGuid().Guid
    $resolvedHeaders['x-adminapp-request'] = $AdminAppRequest
    $resolvedHeaders['x-ms-mac-appid'] = 'f00c5fa5-eee4-4f57-88fa-c082d83b3c94'
    $resolvedHeaders['x-ms-mac-hostingapp'] = 'M365AdminPortal'
    $resolvedHeaders['x-ms-mac-target-app'] = 'Graph'

    if ($graphToken.TenantId) {
        $resolvedHeaders['x-anchormailbox'] = 'TID:{0}' -f $graphToken.TenantId
    }

    if ($IncludeAuthorizationHeader) {
        $resolvedHeaders['Authorization'] = 'Bearer {0}' -f $graphToken.Token
    }

    if ($Headers) {
        foreach ($headerEntry in @($Headers.GetEnumerator())) {
            $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
        }
    }

    $invokeParams = @{
        Uri         = $requestUri
        Method      = $Method
        WebSession  = $script:m365PortalSession
        Headers     = $resolvedHeaders
        ErrorAction = 'Stop'
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        if ($Body -is [string]) {
            $invokeParams.ContentType = $ContentType
            $invokeParams.Body = $Body
        }
        else {
            $invokeParams.ContentType = $ContentType
            $invokeParams.Body = $Body | ConvertTo-Json -Depth 20 -Compress
        }
    }

    try {
        return Invoke-RestMethod @invokeParams
    }
    catch {
        throw "Graph proxy request failed for $Method $requestUri. $($_.Exception.Message)"
    }
}