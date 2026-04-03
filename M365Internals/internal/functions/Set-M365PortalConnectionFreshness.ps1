function Set-M365PortalConnectionFreshness {
    <#
    .SYNOPSIS
        Projects token freshness metadata onto a portal connection object.

    .DESCRIPTION
        Copies derived token lifetime information onto the in-memory Microsoft 365 admin portal
        connection object so later request helpers can decide when a refresh is recommended.

    .PARAMETER Connection
        The portal connection object to update.

    .PARAMETER TokenMetadata
        Optional token metadata to apply. When omitted, existing connection token metadata is reused.

    .EXAMPLE
        Set-M365PortalConnectionFreshness -Connection $connection -TokenMetadata $tokenMetadata

        Adds normalized token freshness fields to the supplied connection object.

    .OUTPUTS
        Object
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates only the in-memory connection object with derived freshness metadata.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Connection,

        [pscustomobject]$TokenMetadata
    )

    if (-not $Connection) {
        return $null
    }

    $effectiveTokenMetadata = if ($TokenMetadata) {
        $TokenMetadata
    }
    elseif ($Connection.PSObject.Properties['TokenMetadata']) {
        $Connection.TokenMetadata
    }
    else {
        $null
    }

    $utcNow = [datetime]::UtcNow
    $tokenExpiresOnUtc = if ($effectiveTokenMetadata) { $effectiveTokenMetadata.ExpiresOnUtc } else { $null }
    $tokenFreshUntilUtc = if ($effectiveTokenMetadata) { $effectiveTokenMetadata.FreshUntilUtc } else { $null }
    $tokenRefreshSatisfiedUntilUtc = if ($Connection.PSObject.Properties['TokenRefreshSatisfiedUntilUtc']) {
        $Connection.TokenRefreshSatisfiedUntilUtc
    }
    else {
        $null
    }
    $tokenExpiresInMinutes = if ($tokenExpiresOnUtc) {
        [math]::Floor(($tokenExpiresOnUtc - $utcNow).TotalMinutes)
    }
    else {
        $null
    }
    $tokenIsFresh = if ($tokenFreshUntilUtc) {
        $tokenFreshUntilUtc -gt $utcNow
    }
    else {
        $null
    }
    $tokenRefreshRecommended = [bool](
        $tokenFreshUntilUtc -and
        $tokenFreshUntilUtc -le $utcNow -and
        (
            -not $tokenRefreshSatisfiedUntilUtc -or
            $tokenRefreshSatisfiedUntilUtc -lt $tokenFreshUntilUtc
        )
    )

    $Connection | Add-Member -NotePropertyName TokenMetadata -NotePropertyValue $effectiveTokenMetadata -Force
    $Connection | Add-Member -NotePropertyName TokenFreshnessSource -NotePropertyValue $(if ($effectiveTokenMetadata) { $effectiveTokenMetadata.Source } else { $null }) -Force
    $Connection | Add-Member -NotePropertyName TokenExpiresOnUtc -NotePropertyValue $tokenExpiresOnUtc -Force
    $Connection | Add-Member -NotePropertyName TokenFreshUntilUtc -NotePropertyValue $tokenFreshUntilUtc -Force
    $Connection | Add-Member -NotePropertyName TokenExpiresInMinutes -NotePropertyValue $tokenExpiresInMinutes -Force
    $Connection | Add-Member -NotePropertyName TokenIssuedAtUtc -NotePropertyValue $(if ($effectiveTokenMetadata) { $effectiveTokenMetadata.IssuedAtUtc } else { $null }) -Force
    $Connection | Add-Member -NotePropertyName TokenAudience -NotePropertyValue $(if ($effectiveTokenMetadata) { $effectiveTokenMetadata.Audience } else { $null }) -Force
    $Connection | Add-Member -NotePropertyName TokenFresh -NotePropertyValue $tokenIsFresh -Force
    $Connection | Add-Member -NotePropertyName TokenRefreshSatisfiedUntilUtc -NotePropertyValue $tokenRefreshSatisfiedUntilUtc -Force
    $Connection | Add-Member -NotePropertyName TokenRefreshRecommended -NotePropertyValue $tokenRefreshRecommended -Force

    return $Connection
}
