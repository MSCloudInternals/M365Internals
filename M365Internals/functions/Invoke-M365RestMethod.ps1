function Invoke-M365RestMethod {
    <#
    .SYNOPSIS
        Invokes a REST API call to the Microsoft 365 admin center.

    .DESCRIPTION
        Executes REST API requests against admin.cloud.microsoft by using the active portal
        session and headers established by Connect-M365Portal. Before each request, the cmdlet
        refreshes the stored portal connection settings from the current cookie jar so headers
        such as AjaxSessionKey and x-portal-routekey stay in sync with the session.

    .PARAMETER Uri
        The fully qualified request URI to call.

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
        Invoke-M365RestMethod -Path '/admin/api/coordinatedbootstrap/shellinfo'

        Makes a GET request to the shell info endpoint by using the active admin portal session.

    .EXAMPLE
        Invoke-M365RestMethod -Uri 'https://admin.cloud.microsoft/adminportal/home/ClassicModernAdminDataStream' -Headers @{ 'x-adminapp-request' = '/homepage' }

        Makes a GET request to a fully qualified admin portal endpoint with an additional header.

    .EXAMPLE
        Invoke-M365RestMethod -Path '/admin/api/example' -Method Post -Body @{ enabled = $true }

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
        foreach ($headerEntry in @($script:m365PortalHeaders.GetEnumerator())) {
            $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
        }
        foreach ($headerEntry in @($Headers.GetEnumerator())) {
            $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
        }

        $invokeParams = @{
            Uri         = $requestUri
            Method      = $Method
            ContentType = $ContentType
            WebSession  = $WebSession
            Headers     = $resolvedHeaders
            ErrorAction = 'Stop'
        }

        if ($PSBoundParameters.ContainsKey('Body')) {
            if (($Body -isnot [string]) -and $ContentType -match 'json') {
                $invokeParams.Body = $Body | ConvertTo-Json -Depth 10
            }
            else {
                $invokeParams.Body = $Body
            }
        }

        try {
            Invoke-RestMethod @invokeParams
        }
        catch {
            throw "Failed to invoke M365 REST method for $Method $requestUri. $($_.Exception.Message)"
        }
    }
}