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

    .PARAMETER Raw
        Returns the raw user payload for the selected section.

    .PARAMETER RawJson
        Returns the raw user payload serialized as formatted JSON.

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
        [Parameter()]
        [ValidateSet('All', 'AdministrativeUnits', 'CommonDvPreferences', 'ContextualAlerts', 'CurrentUser', 'DashboardLayout', 'GccTenant', 'ListUsers', 'Products', 'Roles', 'SvInfo', 'TeamsSettingsInfo', 'TokenWithExpiry')]
        [string]$Name = 'All',

        [Parameter()]
        [int]$CardCategory = 1,

        [Parameter()]
        [string]$Culture = 'en-US',

        [Parameter()]
        [string]$TokenAudience = 'https://management.azure.com/',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $cardCategoryValue = $CardCategory
        $cultureValue = $Culture
        $tokenAudienceValue = $TokenAudience
        $forceRequested = $Force
        $allNames = @(
            'AdministrativeUnits',
            'CommonDvPreferences',
            'ContextualAlerts',
            'CurrentUser',
            'DashboardLayout',
            'GccTenant',
            'ListUsers',
            'Products',
            'Roles',
            'SvInfo',
            'TeamsSettingsInfo',
            'TokenWithExpiry'
        )

        function Get-UserSettingView {
            param (
                [Parameter(Mandatory)]
                [string]$RequestedName
            )

            $cacheKey = switch ($RequestedName) {
                'DashboardLayout' {
                    'M365AdminUserSetting:{0}:{1}:{2}' -f $RequestedName, $cardCategoryValue, $cultureValue
                }
                'TokenWithExpiry' {
                    'M365AdminUserSetting:{0}:{1}' -f $RequestedName, $tokenAudienceValue
                }
                default {
                    'M365AdminUserSetting:{0}' -f $RequestedName
                }
            }

            $additionalProperties = @{}
            $path = $null

            switch ($RequestedName) {
                'ContextualAlerts' {
                    $path = '/admin/api/users/contextualalerts'
                    $rawResult = Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Method Post -Body @{} -Force:$forceRequested
                }
                'ListUsers' {
                    $path = '/admin/api/Users/ListUsers'
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

                    $rawResult = Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Method Post -Body $body -Force:$forceRequested
                }
                'Roles' {
                    $path = '/admin/api/users/getuserroles'
                    $currentUser = Get-M365AdminUserSetting -Name CurrentUser -Force:$forceRequested -Raw
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

                    $rawResult = Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Method Post -Body $body -Force:$forceRequested
                }
                'TokenWithExpiry' {
                    $path = '/admin/api/users/tokenWithExpiry'
                    $additionalProperties.TokenAudience = $tokenAudienceValue
                    $rawResult = Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Method Post -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' -Body ('={0}' -f $tokenAudienceValue) -Force:$forceRequested
                }
                default {
                    $path = switch ($RequestedName) {
                        'AdministrativeUnits' { '/admin/api/users/administrativeunits' }
                        'CommonDvPreferences' { '/admin/api/users/getcommondvpreferences' }
                        'CurrentUser' { '/admin/api/users/currentUser' }
                        'DashboardLayout' { '/admin/api/users/dashboardlayout?cardCategory={0}&culture={1}' -f $cardCategoryValue, [uri]::EscapeDataString($cultureValue) }
                        'GccTenant' { '/admin/api/users/isGCCTenant' }
                        'Products' { '/admin/api/users/products' }
                        'SvInfo' { '/admin/api/users/svinfo' }
                        'TeamsSettingsInfo' { '/admin/api/users/teamssettingsinfo' }
                    }

                    if ($RequestedName -eq 'DashboardLayout') {
                        $additionalProperties.CardCategory = $cardCategoryValue
                        $additionalProperties.Culture = $cultureValue
                    }

                    $rawResult = Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Force:$forceRequested
                }
            }

            $defaultResult = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName ("M365Admin.UserSetting.{0}" -f $RequestedName) -Category 'User settings' -ItemName $RequestedName -Endpoint $path -AdditionalProperties $additionalProperties
            return [pscustomobject]@{
                Name = $RequestedName
                Path = $path
                Raw = $rawResult
                Default = $defaultResult
            }
        }

        if ($Name -eq 'All') {
            $rawResults = [ordered]@{}
            $defaultResults = [ordered]@{}

            foreach ($itemName in $allNames) {
                $view = Get-UserSettingView -RequestedName $itemName
                $rawResults[$itemName] = $view.Raw
                $defaultResults[$itemName] = $view.Default
            }

            $result = New-M365AdminResultBundle -TypeName 'M365Admin.UserSetting' -Category 'User settings' -Items $defaultResults -RawData ([pscustomobject]$rawResults)
            return Resolve-M365AdminOutput -DefaultValue $result -RawValue ([pscustomobject]$rawResults) -Raw:$Raw -RawJson:$RawJson
        }

        $view = Get-UserSettingView -RequestedName $Name
        return Resolve-M365AdminOutput -DefaultValue $view.Default -RawValue $view.Raw -Raw:$Raw -RawJson:$RawJson
    }
}