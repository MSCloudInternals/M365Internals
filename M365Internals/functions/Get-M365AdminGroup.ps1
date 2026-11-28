function Get-M365AdminGroup {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center group data.

    .DESCRIPTION
        Reads group-related payloads exposed by the admin center groups endpoints.

    .PARAMETER Name
        The group payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER PageToken
        The opaque continuation value returned by the previous Groups page. Omit
        PageToken to retrieve the first page. Each call returns one page.

    .PARAMETER Raw
        Returns the raw group payload for the selected view.

    .PARAMETER RawJson
        Returns the raw group payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminGroup -Name Labels

        Retrieves the group labels payload.

    .EXAMPLE
        $first = Get-M365AdminGroup -Name Groups -Raw
        if ($first.$continuationProperty) {
            $second = Get-M365AdminGroup -Name Groups -PageToken $first.$continuationProperty -Raw
            $isLastPage = -not $second.$continuationProperty
        }

        Set $continuationProperty to the continuation field name in your service
        payload. Pass the first page's value directly to the second call. A page
        with no continuation value is the last page.

    .OUTPUTS
        Object
        Returns the selected group payload.
    #>
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [Parameter(Position = 0)]
        [ValidateSet('Groups', 'Labels', 'Permissions')]
        [string]$Name = 'Groups',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$PageToken,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    begin {
        if ($PSBoundParameters.ContainsKey('PageToken') -and $Name -ne 'Groups') {
            throw 'PageToken is supported only for the Groups view.'
        }
        Update-M365PortalConnectionSettings
    }

    process {
        if ($Name -eq 'Groups') {
            $cacheKey = 'M365AdminGroup:Groups'
            if ($PSBoundParameters.ContainsKey('PageToken')) {
                $tokenBytes = [Text.Encoding]::UTF8.GetBytes($PageToken)
                $tokenHash = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($tokenBytes))
                $cacheKey = '{0}:Page:{1}' -f $cacheKey, $tokenHash
            }
            $currentCacheValue = Get-M365Cache -CacheKey $cacheKey -ErrorAction SilentlyContinue
            if (-not $Force -and $currentCacheValue -and $currentCacheValue.NotValidAfter -gt (Get-Date)) {
                Write-Verbose "Using cached $cacheKey data"
                $result = ConvertTo-M365AdminResult -InputObject $currentCacheValue.Value -TypeName 'M365Admin.Group.Groups' -Category 'Groups' -ItemName 'Groups' -Endpoint '/admin/api/groups/GetGroups'
                return Resolve-M365AdminOutput -DefaultValue $result -RawValue $currentCacheValue.Value -Raw:$Raw -RawJson:$RawJson
            }
            elseif ($Force) {
                Write-Verbose 'Force parameter specified, bypassing cache'
                Clear-M365Cache -CacheKey $cacheKey
            }

            $result = Invoke-M365PortalRequest -Path '/admin/api/groups/GetGroups' -Method Post -Headers @{ 'x-adminapp-request' = '/orgsettings/payasyougo' } -Body @{
                PageToken = if ($PSBoundParameters.ContainsKey('PageToken')) { $PageToken } else { $null }
                GroupTypes = $null
                SearchString = ''
                SortDirection = 0
                SortField = 'GroupName'
            } -RawResponse

            $parsedResult = if ([string]::IsNullOrWhiteSpace($result.Content)) {
                $null
            }
            else {
                $result.Content | ConvertFrom-Json -Depth 20
            }

            Set-M365Cache -CacheKey $cacheKey -Value $parsedResult -TTLMinutes 15 | Out-Null
            $result = ConvertTo-M365AdminResult -InputObject $parsedResult -TypeName 'M365Admin.Group.Groups' -Category 'Groups' -ItemName 'Groups' -Endpoint '/admin/api/groups/GetGroups'
            return Resolve-M365AdminOutput -DefaultValue $result -RawValue $parsedResult -Raw:$Raw -RawJson:$RawJson
        }

        $path = switch ($Name) {
            'Labels' { '/admin/api/groups/labels' }
            'Permissions' { '/admin/api/groups/permissions' }
        }

        $rawResult = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminGroup:$Name" -Force:$Force
        $result = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName ("M365Admin.Group.{0}" -f $Name) -Category 'Groups' -ItemName $Name -Endpoint $path
        return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
    }
}