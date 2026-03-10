function Get-M365AdminShellInfo {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center shell information.

    .DESCRIPTION
        Reads the coordinated bootstrap shell information payload used by the admin center shell.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminShellInfo

        Retrieves the admin center shell information payload.

    .EXAMPLE
        Get-M365AdminShellInfo -Force

        Retrieves fresh shell information without using cache.

    .OUTPUTS
        Object
        Returns the shell information payload.
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
        $cacheKey = 'ShellInfo'
        $currentCacheValue = Get-M365Cache -CacheKey $cacheKey -ErrorAction SilentlyContinue
        if (-not $Force -and $currentCacheValue -and $currentCacheValue.NotValidAfter -gt (Get-Date)) {
            Write-Verbose 'Using cached M365 admin shell info'
            return $currentCacheValue.Value
        }
        elseif ($Force) {
            Write-Verbose 'Force parameter specified, bypassing cache'
            Clear-M365Cache -CacheKey $cacheKey
        }

        try {
            $result = Invoke-M365PortalRequest -Path '/admin/api/coordinatedbootstrap/shellinfo' -Headers (Get-M365PortalContextHeaders -Context Homepage)
            Set-M365Cache -CacheKey $cacheKey -Value $result -TTLMinutes 15 | Out-Null
            return $result
        }
        catch {
            throw "Failed to retrieve M365 admin shell info: $($_.Exception.Message)"
        }
    }
}