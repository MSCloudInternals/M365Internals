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

    .PARAMETER Raw
        Returns the raw navigation payload.

    .PARAMETER RawJson
        Returns the raw navigation payload serialized as formatted JSON.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $cacheKey = if ($Async) { 'M365AdminNavigation:Async' } else { 'M365AdminNavigation' }
        $path = if ($Async) {
            '/admin/api/navigation/async'
        }
        else {
            '/admin/api/navigation'
        }

        $itemName = if ($Async) { 'Async' } else { 'Primary' }
        $rawResult = Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Force:$Force
        $result = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName ("M365Admin.Navigation.{0}" -f $itemName) -Category 'Navigation' -ItemName $itemName -Endpoint $path
        return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
    }
}