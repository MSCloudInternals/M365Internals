function Test-M365PortalConnectionNeedsRefresh {
    <#
    .SYNOPSIS
        Determines whether the current portal connection should be refreshed.

    .DESCRIPTION
        Evaluates token freshness hints and required portal headers to decide whether the stored
        Microsoft 365 admin portal session should be refreshed before issuing a request.

    .PARAMETER Connection
        The current portal connection object.

    .PARAMETER Headers
        The current portal request headers.

    .EXAMPLE
        Test-M365PortalConnectionNeedsRefresh -Connection $script:m365PortalConnection -Headers $script:m365PortalHeaders

        Returns True when the connection appears stale and should be refreshed.

    .OUTPUTS
        Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        $Connection,

        [hashtable]$Headers
    )

    if (-not $Connection) {
        return $false
    }

    if ($Connection.PSObject.Properties['TokenRefreshRecommended'] -and $Connection.TokenRefreshRecommended) {
        return $true
    }

    if (-not $Headers -or $Headers.Count -eq 0) {
        return $true
    }

    foreach ($requiredHeader in @('AjaxSessionKey', 'x-portal-routekey')) {
        if (-not $Headers.ContainsKey($requiredHeader) -or [string]::IsNullOrWhiteSpace([string]$Headers[$requiredHeader])) {
            return $true
        }
    }

    return $false
}
