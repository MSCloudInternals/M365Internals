function Get-M365AdminHomeData {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center home page data.

    .DESCRIPTION
        Reads the ClassicModernAdminDataStream payload used by the admin center home page.
        This endpoint requires the x-adminapp-request header observed in the portal HAR.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw home page data payload.

    .PARAMETER RawJson
        Returns the raw home page data payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminHomeData

        Retrieves the admin center home page data stream.

    .OUTPUTS
        Object
        Returns the parsed home page data payload.
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
        $cacheKey = 'M365AdminHomeData'
        $currentCacheValue = Get-M365Cache -CacheKey $cacheKey -ErrorAction SilentlyContinue
        if (-not $Force -and $currentCacheValue -and $currentCacheValue.NotValidAfter -gt (Get-Date)) {
            Write-Verbose 'Using cached M365 admin home data'
            return Resolve-M365AdminOutput -DefaultValue $currentCacheValue.Value -Raw:$Raw -RawJson:$RawJson
        }
        elseif ($Force) {
            Write-Verbose 'Force parameter specified, bypassing cache'
            Clear-M365Cache -CacheKey $cacheKey
        }

        try {
            $result = Invoke-M365PortalRequest -Path '/adminportal/home/ClassicModernAdminDataStream?ref=/homepage' -Headers (Get-M365PortalContextHeaders -Context Homepage)
            Set-M365Cache -CacheKey $cacheKey -Value $result -TTLMinutes 5 | Out-Null
            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
        }
        catch {
            throw "Failed to retrieve M365 admin home data: $($_.Exception.Message)"
        }
    }
}