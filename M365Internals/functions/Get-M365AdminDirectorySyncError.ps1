function Get-M365AdminDirectorySyncError {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center directory sync errors.

    .DESCRIPTION
        Reads the Settings > Directory sync errors payload from the admin center.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw directory sync errors payload.

    .PARAMETER RawJson
        Returns the raw directory sync errors payload serialized as formatted JSON.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    begin {
        Update-M365PortalConnectionSettings
    }

    process {
        $cacheKey = 'M365AdminDirectorySyncError:List'
        $currentCacheValue = Get-M365Cache -CacheKey $cacheKey -ErrorAction SilentlyContinue
        if (-not $Force -and $currentCacheValue -and $currentCacheValue.NotValidAfter -gt (Get-Date)) {
            Write-Verbose "Using cached $cacheKey data"
            $result = ConvertTo-M365AdminResult -InputObject $currentCacheValue.Value -TypeName 'M365Admin.DirectorySyncError' -Category 'Directory synchronization' -ItemName 'DirectorySyncErrors' -Endpoint '/admin/api/dirsyncerrors/listdirsyncerrors'
            return Resolve-M365AdminOutput -DefaultValue $result -RawValue $currentCacheValue.Value -Raw:$Raw -RawJson:$RawJson
        }
        elseif ($Force) {
            Clear-M365Cache -CacheKey $cacheKey
        }

        $rawResult = Invoke-M365AdminRestMethod -Path '/admin/api/dirsyncerrors/listdirsyncerrors' -Method Post
        Set-M365Cache -CacheKey $cacheKey -Value $rawResult -TTLMinutes 15 | Out-Null
        $result = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName 'M365Admin.DirectorySyncError' -Category 'Directory synchronization' -ItemName 'DirectorySyncErrors' -Endpoint '/admin/api/dirsyncerrors/listdirsyncerrors'
        return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
    }
}