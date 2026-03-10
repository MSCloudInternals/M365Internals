function Get-M365AdminPortalData {
    <#
    .SYNOPSIS
        Retrieves cached JSON data from a Microsoft 365 admin portal endpoint.

    .DESCRIPTION
        Wraps direct Invoke-RestMethod GET calls against admin.cloud.microsoft by reusing the
        current portal session, merging optional headers, and caching successful responses.

    .PARAMETER Path
        The portal-relative path or fully qualified URI to query.

    .PARAMETER CacheKey
        The cache key used to store the retrieved response.

    .PARAMETER CacheMinutes
        The number of minutes that a successful response remains valid in cache.

    .PARAMETER Headers
        Optional request headers to merge with the current portal headers.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminPortalData -Path '/admin/api/settings/apps/bookings' -CacheKey 'Example'

        Retrieves the Bookings app settings payload and caches the response.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$CacheKey,

        [Parameter()]
        [ValidateRange(1, 1440)]
        [int]$CacheMinutes = 15,

        [Parameter()]
        [hashtable]$Headers,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Update-M365PortalConnectionSettings
    }

    process {
        $currentCacheValue = Get-M365Cache -CacheKey $CacheKey -ErrorAction SilentlyContinue
        if (-not $Force -and $currentCacheValue -and $currentCacheValue.NotValidAfter -gt (Get-Date)) {
            Write-Verbose "Using cached $CacheKey data"
            return $currentCacheValue.Value
        }
        elseif ($Force) {
            Write-Verbose 'Force parameter specified, bypassing cache'
            Clear-M365Cache -CacheKey $CacheKey
        }

        $uri = if ($Path -match '^https://') {
            $Path
        }
        elseif ($Path.StartsWith('/')) {
            'https://admin.cloud.microsoft{0}' -f $Path
        }
        else {
            'https://admin.cloud.microsoft/{0}' -f $Path
        }

        $resolvedHeaders = @{}
        foreach ($entry in @($script:m365PortalHeaders.GetEnumerator())) {
            $resolvedHeaders[$entry.Key] = $entry.Value
        }
        if ($Headers) {
            foreach ($entry in @($Headers.GetEnumerator())) {
                $resolvedHeaders[$entry.Key] = $entry.Value
            }
        }

        try {
            $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType 'application/json' -WebSession $script:m365PortalSession -Headers $resolvedHeaders
        }
        catch {
            throw "Failed to retrieve M365 admin portal data from ${uri}: $($_.Exception.Message)"
        }

        if ($null -eq $result) {
            return $null
        }

        Set-M365Cache -CacheKey $CacheKey -Value $result -TTLMinutes $CacheMinutes | Out-Null
        return $result
    }
}