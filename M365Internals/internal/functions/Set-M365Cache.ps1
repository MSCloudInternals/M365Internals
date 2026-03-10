function Set-M365Cache {
    <#
    .SYNOPSIS
        Stores a cached M365 portal value.

    .DESCRIPTION
        Adds or updates an entry in the in-memory cache used by M365Internals for short-lived
        portal metadata and response payloads.

    .PARAMETER CacheKey
        The cache key to create or update.

    .PARAMETER Value
        The value to store.

    .PARAMETER TTLMinutes
        The cache time-to-live in minutes.

    .PARAMETER TenantId
        The tenant ID scope for the cache key. When omitted, the current portal connection tenant
        is used when available.

    .EXAMPLE
        Set-M365Cache -CacheKey 'ShellInfo' -Value $response -TTLMinutes 15

        Stores a shell info response for the current tenant for 15 minutes.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates only the in-memory cache for the current PowerShell session')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$CacheKey,

        [Parameter(Mandatory)]
        $Value,

        [int]$TTLMinutes = 15,

        [string]$TenantId
    )

    if (-not $script:m365CacheStore) {
        $script:m365CacheStore = @{}
    }

    $resolvedTenantId = if ($TenantId) {
        $TenantId
    }
    elseif ($script:m365PortalConnection -and $script:m365PortalConnection.TenantId) {
        $script:m365PortalConnection.TenantId
    }

    $resolvedCacheKey = if ($resolvedTenantId) {
        '{0}::{1}' -f $resolvedTenantId, $CacheKey
    }
    else {
        $CacheKey
    }

    $cacheEntry = [pscustomobject]@{
        CacheKey      = $CacheKey
        TenantId      = $resolvedTenantId
        Value         = $Value
        CachedAt      = Get-Date
        NotValidAfter = (Get-Date).AddMinutes($TTLMinutes)
    }
    $cacheEntry.PSObject.TypeNames.Insert(0, 'M365.CacheEntry')

    $script:m365CacheStore[$resolvedCacheKey] = $cacheEntry
    $cacheEntry
}