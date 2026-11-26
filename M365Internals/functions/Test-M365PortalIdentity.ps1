function Test-M365PortalIdentity {
    <#
    .SYNOPSIS
        Checks the identity of the active Microsoft 365 admin portal session.

    .DESCRIPTION
        Compares the current-user principal and active tenant with the authenticated
        admin shell identity on the same web session. Returns only verdicts.
        Missing or unavailable evidence produces Unknown. Conflicting IDs produce Mismatch.

    .EXAMPLE
        Test-M365PortalIdentity

        Checks the account and resource tenant on the active admin portal connection.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $session = $script:m365PortalSession
    $connection = $script:m365PortalConnection
    $verdicts = [ordered]@{
        Connected = $null -ne $session -and $null -ne $connection
        AccountVerification = 'Unknown'
        ResourceTenantVerification = 'Unknown'
    }
    if (-not $verdicts.Connected) {
        return [pscustomobject]$verdicts
    }
    $tenantRoute = [string]$connection.TenantId
    $tenantId = [guid]::Empty
    $hasTenant = [guid]::TryParse($tenantRoute, [ref]$tenantId) -and $tenantId -ne [guid]::Empty

    function Assert-ActiveSession {
        if (-not [object]::ReferenceEquals($session, $script:m365PortalSession) -or
            -not [object]::ReferenceEquals($connection, $script:m365PortalConnection) -or
            [string]$connection.TenantId -ne $tenantRoute) {
            $ErrorActionPreference = 'Stop'
            throw 'The active Microsoft 365 portal connection changed during identity verification.'
        }
    }

    $portalRequest = @{
        WebSession = $session
        Headers = Get-M365PortalContextHeaders -Context Homepage
        SkipConnectionRefresh = $true
        SkipAutoHeal = $true
        Debug = $false
        Verbose = $false
        ErrorAction = 'Stop'
    }
    $portalPrincipal = [guid]::Empty
    try {
        $currentUser = Invoke-M365PortalRequest -Path '/admin/api/users/currentUser' @portalRequest
        $null = [guid]::TryParse([string]$currentUser.UserInfo.ObjectId, [ref]$portalPrincipal)
    }
    catch { Assert-ActiveSession }
    Assert-ActiveSession

    if ($portalPrincipal -eq [guid]::Empty -and -not $hasTenant) {
        return [pscustomobject]$verdicts
    }

    try {
        $shell = Invoke-M365PortalRequest -Path '/admin/api/coordinatedbootstrap/shellinfo' @portalRequest
        if ($shell.shellInfo.navBarJson -is [string]) {
            $navigation = ConvertFrom-Json -InputObject $shell.shellInfo.navBarJson -Depth 30 -ErrorAction Stop
            if ($navigation.ClientData -is [string]) {
                $client = ConvertFrom-Json -InputObject $navigation.ClientData -Depth 30 -ErrorAction Stop
            }
        }
    }
    catch { Assert-ActiveSession }

    Assert-ActiveSession
    $shellPrincipal = [guid]::Empty
    if ($portalPrincipal -ne [guid]::Empty -and
        [guid]::TryParse([string]$client.UID, [ref]$shellPrincipal) -and $shellPrincipal -ne [guid]::Empty) {
        $upnMatches = -not $currentUser.UserInfo.UserPrincipalName -or -not $client.UPN -or
            $currentUser.UserInfo.UserPrincipalName -eq $client.UPN
        $verdicts.AccountVerification = if ($portalPrincipal -eq $shellPrincipal -and $upnMatches) { 'Verified' } else { 'Mismatch' }
    }
    $shellTenant = [guid]::Empty
    if ($hasTenant -and [guid]::TryParse([string]$client.TID, [ref]$shellTenant) -and $shellTenant -ne [guid]::Empty) {
        $verdicts.ResourceTenantVerification = if ($tenantId -eq $shellTenant) { 'Verified' } else { 'Mismatch' }
    }
    return [pscustomobject]$verdicts
}
