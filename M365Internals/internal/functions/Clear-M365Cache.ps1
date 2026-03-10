function Clear-M365Cache {
    <#
    .SYNOPSIS
        Clears cached M365 portal data.

    .DESCRIPTION
        Removes entries from the in-memory cache used by M365Internals for short-lived portal
        metadata and response payloads. You can clear a specific cache key, all entries for a
        tenant, or the entire cache store.

    .PARAMETER CacheKey
        The cache key to clear.

    .PARAMETER TenantId
        The tenant ID scope for the cache key. When omitted for tenant-scoped operations, the
        current portal connection tenant is used when available.

    .PARAMETER All
        Clears the entire cache store.

    .EXAMPLE
        Clear-M365Cache -All

        Clears all cached portal data.

    .EXAMPLE
        Clear-M365Cache -CacheKey 'ShellInfo' -TenantId 'contoso-tenant-id'

        Clears the cached shell info response for the specified tenant.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Key')]
        [string]$CacheKey,

        [Parameter(ParameterSetName = 'Key')]
        [Parameter(ParameterSetName = 'Tenant')]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All
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

    switch ($PSCmdlet.ParameterSetName) {
        'Key' {
            $resolvedCacheKey = if ($resolvedTenantId) {
                '{0}::{1}' -f $resolvedTenantId, $CacheKey
            }
            else {
                $CacheKey
            }
            $null = $script:m365CacheStore.Remove($resolvedCacheKey)
        }
        'Tenant' {
            if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) {
                return
            }

            foreach ($cacheEntryKey in @($script:m365CacheStore.Keys)) {
                if ($cacheEntryKey -like "$resolvedTenantId::*") {
                    $null = $script:m365CacheStore.Remove($cacheEntryKey)
                }
            }
        }
        default {
            if ($All -or $PSCmdlet.ParameterSetName -eq 'All') {
                $script:m365CacheStore = @{}
            }
        }
    }
}