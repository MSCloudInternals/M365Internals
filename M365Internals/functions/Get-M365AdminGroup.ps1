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

    .EXAMPLE
        Get-M365AdminGroup -Name Labels

        Retrieves the group labels payload.

    .OUTPUTS
        Object
        Returns the selected group payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('Groups', 'Labels', 'Permissions')]
        [string]$Name = 'Groups',

        [Parameter()]
        [switch]$Force
    )

    begin {
        Update-M365PortalConnectionSettings
    }

    process {
        if ($Name -eq 'Groups') {
            $cacheKey = 'M365AdminGroup:Groups'
            $currentCacheValue = Get-M365Cache -CacheKey $cacheKey -ErrorAction SilentlyContinue
            if (-not $Force -and $currentCacheValue -and $currentCacheValue.NotValidAfter -gt (Get-Date)) {
                Write-Verbose "Using cached $cacheKey data"
                return $currentCacheValue.Value
            }
            elseif ($Force) {
                Write-Verbose 'Force parameter specified, bypassing cache'
                Clear-M365Cache -CacheKey $cacheKey
            }

            $result = Invoke-M365PortalRequest -Path '/admin/api/groups/GetGroups' -Method Post -Headers @{ 'x-adminapp-request' = '/orgsettings/payasyougo' } -Body @{
                PageToken = $null
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
            return $parsedResult
        }

        $path = switch ($Name) {
            'Labels' { '/admin/api/groups/labels' }
            'Permissions' { '/admin/api/groups/permissions' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminGroup:$Name" -Force:$Force
    }
}