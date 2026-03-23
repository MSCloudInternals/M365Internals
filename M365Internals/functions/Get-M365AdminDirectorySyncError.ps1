function Get-M365AdminDirectorySyncError {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center directory sync errors.

    .DESCRIPTION
        Reads the Settings > Directory sync errors payload from the admin center.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminDirectorySyncError

        Retrieves the current directory sync errors list.

    .OUTPUTS
        Object
        Returns the directory sync errors payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$Force
    )

    begin {
        Update-M365PortalConnectionSettings
    }

    process {
        $cacheKey = 'M365AdminDirectorySyncError:List'
        $currentCacheValue = Get-M365Cache -CacheKey $cacheKey -ErrorAction SilentlyContinue
        if (-not $Force -and $currentCacheValue -and $currentCacheValue.NotValidAfter -gt (Get-Date)) {
            Write-Verbose "Using cached $cacheKey data"
            return $currentCacheValue.Value
        }
        elseif ($Force) {
            Clear-M365Cache -CacheKey $cacheKey
        }

        $result = Invoke-M365RestMethod -Path '/admin/api/dirsyncerrors/listdirsyncerrors' -Method Post
        Set-M365Cache -CacheKey $cacheKey -Value $result -TTLMinutes 15 | Out-Null
        return $result
    }
}