function Get-M365AdminUserSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center user settings and status data.

    .DESCRIPTION
        Reads user-oriented payloads from the admin center users endpoints, including current user
        context, roles, product data, and dashboard layout.

    .PARAMETER Name
        The user payload to retrieve.

    .PARAMETER CardCategory
        The dashboard card category used when retrieving dashboard layout data.

    .PARAMETER Culture
        The culture used when retrieving dashboard layout data.

    .PARAMETER TokenAudience
        The audience value sent when retrieving the TokenWithExpiry payload.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminUserSetting -Name CurrentUser

        Retrieves the current user payload from the admin center.

    .EXAMPLE
        Get-M365AdminUserSetting -Name DashboardLayout -CardCategory 1 -Culture en-US

        Retrieves the dashboard layout payload.

    .EXAMPLE
        Get-M365AdminUserSetting -Name TokenWithExpiry -TokenAudience 'https://management.azure.com/'

        Retrieves an Azure Resource Manager token and expiry payload from the admin center token broker.

    .OUTPUTS
        Object
        Returns the selected user payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('AdministrativeUnits', 'CommonDvPreferences', 'ContextualAlerts', 'CurrentUser', 'DashboardLayout', 'GccTenant', 'ListUsers', 'Products', 'Roles', 'SvInfo', 'TeamsSettingsInfo', 'TokenWithExpiry')]
        [string]$Name,

        [Parameter()]
        [int]$CardCategory = 1,

        [Parameter()]
        [string]$Culture = 'en-US',

        [Parameter()]
        [string]$TokenAudience = 'https://management.azure.com/',

        [Parameter()]
        [switch]$Force
    )

    process {
        $cacheKey = switch ($Name) {
            'DashboardLayout' {
                'M365AdminUserSetting:{0}:{1}:{2}' -f $Name, $CardCategory, $Culture
            }
            'TokenWithExpiry' {
                'M365AdminUserSetting:{0}:{1}' -f $Name, $TokenAudience
            }
            default {
                'M365AdminUserSetting:{0}' -f $Name
            }
        }

        switch ($Name) {
            'ContextualAlerts' {
                return Get-M365AdminPortalData -Path '/admin/api/users/contextualalerts' -CacheKey $cacheKey -Method Post -Body @{} -Force:$Force
            }
            'ListUsers' {
                $body = @{
                    ListAction       = -1
                    SortDirection    = 0
                    SortPropertyName = 'DisplayName'
                    ListContext      = $null
                    SearchText       = ''
                    SelectedView     = $null
                    SelectedViewType = $null
                    ServerContext    = $null
                }

                return Get-M365AdminPortalData -Path '/admin/api/Users/ListUsers' -CacheKey $cacheKey -Method Post -Body $body -Force:$Force
            }
            'Roles' {
                $currentUser = Get-M365AdminUserSetting -Name CurrentUser -Force:$Force
                $principalId = $null
                if ($null -ne $currentUser) {
                    if ($currentUser.PSObject.Properties.Match('UserInfo').Count -gt 0 -and $null -ne $currentUser.UserInfo) {
                        $principalId = $currentUser.UserInfo.ObjectId
                    }
                    elseif ($currentUser.PSObject.Properties.Match('ObjectId').Count -gt 0) {
                        $principalId = $currentUser.ObjectId
                    }
                }

                $body = if ([string]::IsNullOrWhiteSpace($principalId)) {
                    @{}
                }
                else {
                    @{
                        PrincipalId        = $principalId
                        UserSecurityGroups = @()
                    }
                }

                return Get-M365AdminPortalData -Path '/admin/api/users/getuserroles' -CacheKey $cacheKey -Method Post -Body $body -Force:$Force
            }
            'TokenWithExpiry' {
                return Get-M365AdminPortalData -Path '/admin/api/users/tokenWithExpiry' -CacheKey $cacheKey -Method Post -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' -Body ('={0}' -f $TokenAudience) -Force:$Force
            }
        }

        $path = switch ($Name) {
            'AdministrativeUnits' { '/admin/api/users/administrativeunits' }
            'CommonDvPreferences' { '/admin/api/users/getcommondvpreferences' }
            'CurrentUser' { '/admin/api/users/currentUser' }
            'DashboardLayout' { '/admin/api/users/dashboardlayout?cardCategory={0}&culture={1}' -f $CardCategory, [uri]::EscapeDataString($Culture) }
            'GccTenant' { '/admin/api/users/isGCCTenant' }
            'Products' { '/admin/api/users/products' }
            'SvInfo' { '/admin/api/users/svinfo' }
            'TeamsSettingsInfo' { '/admin/api/users/teamssettingsinfo' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Force:$Force
    }
}