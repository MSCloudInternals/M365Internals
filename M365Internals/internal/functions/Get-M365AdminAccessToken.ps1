function Get-M365AdminAccessToken {
    <#
    .SYNOPSIS
        Retrieves an access token issued by the Microsoft 365 admin center.

    .DESCRIPTION
        Calls the admin center token broker endpoint at /admin/api/users/getuseraccesstoken using
        the active portal session. The response currently returns a JSON string containing a raw JWT.
        Tokens are cached by token type and scenario until shortly before expiration.

    .PARAMETER TokenType
        The token type requested from the admin center broker.

    .PARAMETER Scenario
        An optional scenario value sent to the broker endpoint.

    .PARAMETER ReadFromCache
        Requests that the admin center broker reuse its own cached token when supported.

    .PARAMETER AdminAppRequest
        Supplies the x-adminapp-request header used by the originating settings page.

    .PARAMETER Force
        Bypasses the local M365Internals cache and requests a fresh token object.

    .EXAMPLE
        Get-M365AdminAccessToken -TokenType GraphAT -Scenario main -AdminAppRequest '/Settings/enhancedRestore'

        Retrieves a Graph access token from the admin center token broker.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('BusinessStoreAT', 'GraphAT', 'SharePoint')]
        [string]$TokenType,

        [string]$Scenario,

        [switch]$ReadFromCache,

        [string]$AdminAppRequest = '/homepage',

        [switch]$Force
    )

    function ConvertFrom-Base64UrlSegment {
        param (
            [Parameter(Mandatory)]
            [string]$Value
        )

        $normalizedValue = $Value.Replace('-', '+').Replace('_', '/')
        switch ($normalizedValue.Length % 4) {
            2 { $normalizedValue += '==' }
            3 { $normalizedValue += '=' }
        }

        [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($normalizedValue))
    }

    Update-M365PortalConnectionSettings

    $cacheKey = if ([string]::IsNullOrWhiteSpace($Scenario)) {
        'M365AdminAccessToken:{0}' -f $TokenType
    }
    else {
        'M365AdminAccessToken:{0}:{1}' -f $TokenType, $Scenario
    }

    $currentCacheValue = Get-M365Cache -CacheKey $cacheKey -ErrorAction SilentlyContinue
    if (-not $Force -and $currentCacheValue -and $currentCacheValue.NotValidAfter -gt (Get-Date)) {
        Write-Verbose "Using cached $cacheKey data"
        return $currentCacheValue.Value
    }
    elseif ($Force) {
        Write-Verbose 'Force parameter specified, bypassing cache'
        Clear-M365Cache -CacheKey $cacheKey
    }

    $queryParameters = [System.Collections.Generic.List[string]]::new()
    $queryParameters.Add('tokenType={0}' -f [System.Uri]::EscapeDataString($TokenType))
    if ($ReadFromCache) {
        $queryParameters.Add('readFromCache=true')
    }
    if (-not [string]::IsNullOrWhiteSpace($Scenario)) {
        $queryParameters.Add('scenario={0}' -f [System.Uri]::EscapeDataString($Scenario))
    }

    $uri = 'https://admin.cloud.microsoft/admin/api/users/getuseraccesstoken?{0}' -f ($queryParameters -join '&')
    $headers = @{
        Accept                 = 'application/json;odata=minimalmetadata, text/plain, */*'
        'x-adminapp-request'   = $AdminAppRequest
        'x-ms-mac-appid'       = 'f00c5fa5-eee4-4f57-88fa-c082d83b3c94'
        'x-ms-mac-hostingapp'  = 'M365AdminPortal'
        'x-ms-mac-target-app'  = 'MAC'
    }

    $resolvedHeaders = @{}
    foreach ($headerEntry in @($script:m365PortalHeaders.GetEnumerator())) {
        $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
    }
    foreach ($headerEntry in @($headers.GetEnumerator())) {
        $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
    }

    try {
        $rawToken = Invoke-RestMethod -Uri $uri -Method Get -ContentType 'application/json' -WebSession $script:m365PortalSession -Headers $resolvedHeaders
    }
    catch {
        throw "Failed to retrieve M365 admin access token '$TokenType': $($_.Exception.Message)"
    }

    $token = [string]$rawToken
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "The M365 admin access token endpoint returned an empty token for '$TokenType'."
    }

    $jwtParts = $token.Split('.')
    $claims = $null
    $expiresOn = (Get-Date).AddMinutes(45)
    if ($jwtParts.Count -ge 2) {
        try {
            $claims = ConvertFrom-Base64UrlSegment -Value $jwtParts[1] | ConvertFrom-Json -Depth 20
            if ($claims.exp) {
                $expiresOn = [DateTimeOffset]::FromUnixTimeSeconds([long]$claims.exp).UtcDateTime
            }
        }
        catch {
            Write-Verbose "Unable to parse claims for $TokenType token: $($_.Exception.Message)"
        }
    }

    $result = [pscustomobject]@{
        TokenType = $TokenType
        Scenario  = $Scenario
        Token     = $token
        ExpiresOn = $expiresOn
        Audience  = if ($claims) { $claims.aud } else { $null }
        TenantId  = if ($claims) { $claims.tid } else { $null }
        Scope     = if ($claims) { $claims.scp } else { $null }
        Claims    = $claims
    }
    $result.PSObject.TypeNames.Insert(0, 'M365Portal.AccessToken')

    $ttlMinutes = [Math]::Floor((New-TimeSpan -Start (Get-Date) -End $expiresOn.AddMinutes(-5)).TotalMinutes)
    if ($ttlMinutes -lt 1) {
        $ttlMinutes = 1
    }

    Set-M365Cache -CacheKey $cacheKey -Value $result -TTLMinutes $ttlMinutes | Out-Null
    return $result
}