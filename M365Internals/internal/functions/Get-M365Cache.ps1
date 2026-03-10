function Get-M365Cache {
    <#
    .SYNOPSIS
        Gets a cached M365 portal value.

    .DESCRIPTION
        Retrieves an entry from the in-memory cache used by M365Internals. Expired entries are
        removed automatically and return no result.

    .PARAMETER CacheKey
        The cache key to retrieve.

    .PARAMETER TenantId
        The tenant ID scope for the cache key. When omitted, the current portal connection tenant
        is used when available.

    .EXAMPLE
        Get-M365Cache -CacheKey 'ShellInfo'

        Gets the cached shell info response for the current tenant if it is still valid.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$CacheKey,

        [string]$TenantId
    )

    if (-not $script:m365CacheStore) {
        return
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

    if (-not $script:m365CacheStore.ContainsKey($resolvedCacheKey)) {
        return
    }

    $cacheEntry = $script:m365CacheStore[$resolvedCacheKey]
    if ($cacheEntry.NotValidAfter -le (Get-Date)) {
        $null = $script:m365CacheStore.Remove($resolvedCacheKey)
        return
    }

    $cacheEntry
}