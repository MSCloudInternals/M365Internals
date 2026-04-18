function Get-M365AdminShellInfo {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center shell information.

    .DESCRIPTION
        Reads the coordinated bootstrap shell information payload used by the admin center shell.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw shell information payload.

    .PARAMETER RawJson
        Returns the raw shell information payload serialized as formatted JSON.

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
        $cacheKey = 'ShellInfo'
        $currentCacheValue = Get-M365Cache -CacheKey $cacheKey -ErrorAction SilentlyContinue
        if (-not $Force -and $currentCacheValue -and $currentCacheValue.NotValidAfter -gt (Get-Date)) {
            Write-Verbose 'Using cached M365 admin shell info'
            $result = ConvertTo-M365AdminResult -InputObject $currentCacheValue.Value -TypeName 'M365Admin.ShellInfo' -Category 'Platform metadata' -ItemName 'ShellInfo' -Endpoint '/admin/api/coordinatedbootstrap/shellinfo'
            return Resolve-M365AdminOutput -DefaultValue $result -RawValue $currentCacheValue.Value -Raw:$Raw -RawJson:$RawJson
        }
        elseif ($Force) {
            Write-Verbose 'Force parameter specified, bypassing cache'
            Clear-M365Cache -CacheKey $cacheKey
        }

        try {
            $rawResult = Invoke-M365PortalRequest -Path '/admin/api/coordinatedbootstrap/shellinfo' -Headers (Get-M365PortalContextHeaders -Context Homepage)
            Set-M365Cache -CacheKey $cacheKey -Value $rawResult -TTLMinutes 15 | Out-Null
            $result = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName 'M365Admin.ShellInfo' -Category 'Platform metadata' -ItemName 'ShellInfo' -Endpoint '/admin/api/coordinatedbootstrap/shellinfo'
            return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
        }
        catch {
            throw "Failed to retrieve M365 admin shell info: $($_.Exception.Message)"
        }
    }
}