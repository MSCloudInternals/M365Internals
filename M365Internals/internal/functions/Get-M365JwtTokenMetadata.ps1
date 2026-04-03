function Get-M365JwtTokenMetadata {
    <#
    .SYNOPSIS
        Extracts freshness metadata from a JWT.

    .DESCRIPTION
        Parses a JWT payload and returns the expiration, issued-at, not-before, audience, tenant,
        and username fields needed for portal freshness tracking.

    .PARAMETER Token
        The JWT string to parse.

    .PARAMETER Source
        A label describing where the token was captured from, such as id_token or access_token.

    .PARAMETER IncludeClaims
        Includes the raw decoded JWT claims in the returned object. This is intended only for
        callers that explicitly need the full claim set.

    .EXAMPLE
        Get-M365JwtTokenMetadata -Token $idToken -Source 'id_token'

        Returns normalized token lifetime metadata from the supplied JWT.

    .OUTPUTS
        PSCustomObject
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'JWT token metadata is treated as a single logical payload for internal freshness tracking.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Token,

        [string]$Source = 'Jwt',

        [switch]$IncludeClaims
    )

    if ([string]::IsNullOrWhiteSpace($Token)) {
        return $null
    }

    $tokenSegments = $Token.Split('.')
    if ($tokenSegments.Count -lt 2) {
        return $null
    }

    try {
        $claims = ConvertFrom-M365Base64UrlSegment -Value $tokenSegments[1] | ConvertFrom-Json -Depth 20
    }
    catch {
        Write-Verbose "The supplied token could not be parsed as a JWT while reading freshness metadata. $($_.Exception.Message)"
        return $null
    }

    if (-not $claims -or -not $claims.PSObject.Properties['exp'] -or -not $claims.exp) {
        return $null
    }

    $expiresOnUtc = [DateTimeOffset]::FromUnixTimeSeconds([long]$claims.exp).UtcDateTime
    $issuedAtUtc = if ($claims.PSObject.Properties['iat'] -and $claims.iat) {
        [DateTimeOffset]::FromUnixTimeSeconds([long]$claims.iat).UtcDateTime
    }
    else {
        $null
    }
    $notBeforeUtc = if ($claims.PSObject.Properties['nbf'] -and $claims.nbf) {
        [DateTimeOffset]::FromUnixTimeSeconds([long]$claims.nbf).UtcDateTime
    }
    else {
        $null
    }

    $metadata = [ordered]@{
        Source              = $Source
        ExpiresOnUtc        = $expiresOnUtc
        FreshUntilUtc       = $expiresOnUtc.AddMinutes(-5)
        IssuedAtUtc         = $issuedAtUtc
        NotBeforeUtc        = $notBeforeUtc
        TenantId            = if ($claims.PSObject.Properties['tid']) { $claims.tid } else { $null }
        Audience            = if ($claims.PSObject.Properties['aud']) { $claims.aud } else { $null }
        Subject             = if ($claims.PSObject.Properties['sub']) { $claims.sub } else { $null }
        Username            = if ($claims.PSObject.Properties['preferred_username']) { $claims.preferred_username } elseif ($claims.PSObject.Properties['upn']) { $claims.upn } else { $null }
    }

    if ($IncludeClaims) {
        $metadata['Claims'] = $claims
    }

    [pscustomobject]$metadata
}
