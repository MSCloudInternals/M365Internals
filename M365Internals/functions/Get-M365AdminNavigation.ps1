function Get-M365AdminNavigation {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center navigation data.

    .DESCRIPTION
        Reads the navigation payload exposed by the admin center. The async variant uses the
        separate endpoint observed in the portal HAR.

    .PARAMETER Async
        Retrieves the asynchronous navigation payload.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminNavigation

        Retrieves the primary admin center navigation payload.

    .EXAMPLE
        Get-M365AdminNavigation -Async

        Retrieves the asynchronous navigation payload.

    .OUTPUTS
        Object
        Returns the navigation payload.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(ParameterSetName = 'Async')]
        [switch]$Async,

        [Parameter()]
        [switch]$Force
    )

    process {
        $cacheKey = if ($Async) { 'M365AdminNavigation:Async' } else { 'M365AdminNavigation' }
        $path = if ($Async) {
            '/admin/api/navigation/async'
        }
        else {
            '/admin/api/navigation'
        }

        Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Force:$Force
    }
}