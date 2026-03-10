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

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminUserSetting -Name CurrentUser

        Retrieves the current user payload from the admin center.

    .EXAMPLE
        Get-M365AdminUserSetting -Name DashboardLayout -CardCategory 1 -Culture en-US

        Retrieves the dashboard layout payload.

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
        [switch]$Force
    )

    process {
        $path = switch ($Name) {
            'AdministrativeUnits' { '/admin/api/users/administrativeunits' }
            'CommonDvPreferences' { '/admin/api/users/getcommondvpreferences' }
            'ContextualAlerts' { '/admin/api/users/contextualalerts' }
            'CurrentUser' { '/admin/api/users/currentUser' }
            'DashboardLayout' { '/admin/api/users/dashboardlayout?cardCategory={0}&culture={1}' -f $CardCategory, [uri]::EscapeDataString($Culture) }
            'GccTenant' { '/admin/api/users/isGCCTenant' }
            'ListUsers' { '/admin/api/Users/ListUsers' }
            'Products' { '/admin/api/users/products' }
            'Roles' { '/admin/api/users/getuserroles' }
            'SvInfo' { '/admin/api/users/svinfo' }
            'TeamsSettingsInfo' { '/admin/api/users/teamssettingsinfo' }
            'TokenWithExpiry' { '/admin/api/users/tokenWithExpiry' }
        }

        $cacheKey = if ($Name -eq 'DashboardLayout') {
            'M365AdminUserSetting:{0}:{1}:{2}' -f $Name, $CardCategory, $Culture
        }
        else {
            'M365AdminUserSetting:{0}' -f $Name
        }

        Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Force:$Force
    }
}