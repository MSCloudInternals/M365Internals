function Test-M365PortalIdentity {
    <#
    .SYNOPSIS
        Checks the identity of the active Microsoft 365 admin portal session.

    .DESCRIPTION
        Compares the admin portal principal with Microsoft Graph and corroborates the
        active tenant against the Graph organization. The admin portal issues the token
        on the same web session used for the principal check. Returns only verdicts.
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
        $rawToken = Invoke-M365PortalRequest -Path '/admin/api/users/getuseraccesstoken?tokenType=GraphAT&scenario=main' @portalRequest
        if ($rawToken -isnot [string] -or $rawToken -cnotmatch '\A[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+){2}\z') {
            Assert-ActiveSession
            return [pscustomobject]$verdicts
        }
    }
    catch {
        Assert-ActiveSession
        return [pscustomobject]$verdicts
    }

    $token = [securestring]::new()
    $graphRequest = @{
        Authentication = 'Bearer'
        Token = $token
        MaximumRedirection = 0
        TimeoutSec = 20
        Debug = $false
        Verbose = $false
        ErrorAction = 'Stop'
    }
    try {
        foreach ($character in $rawToken.ToCharArray()) {
            $token.AppendChar($character)
        }
        $token.MakeReadOnly()
        $rawToken = $null
        Assert-ActiveSession
        if ($portalPrincipal -ne [guid]::Empty) {
            try {
                $user = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/me?$select=id' @graphRequest
                $id = [guid]::Empty
                if ([guid]::TryParse([string]$user.id, [ref]$id) -and $id -ne [guid]::Empty) {
                    $verdicts.AccountVerification = if ($id -eq $portalPrincipal) { 'Verified' } else { 'Mismatch' }
                }
            }
            catch { Assert-ActiveSession }
        }
        Assert-ActiveSession
        if ($hasTenant) {
            try {
                $organizations = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/organization?$select=id' @graphRequest
                $id = [guid]::Empty
                if ($organizations.value -is [array] -and $organizations.value.Count -eq 1 -and
                    [guid]::TryParse([string]$organizations.value[0].id, [ref]$id) -and $id -ne [guid]::Empty) {
                    $verdicts.ResourceTenantVerification = if ($id -eq $tenantId) { 'Verified' } else { 'Mismatch' }
                }
            }
            catch { Assert-ActiveSession }
        }
        Assert-ActiveSession
        return [pscustomobject]$verdicts
    }
    finally { $token.Dispose() }
}
