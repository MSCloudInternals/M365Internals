Describe 'Get-M365AdminUserSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            switch ($Path) {
                '/admin/api/users/currentUser' {
                    [pscustomobject]@{
                        UserInfo = [pscustomobject]@{
                            ObjectId = 'user-1'
                        }
                    }
                }
                '/admin/api/users/getuserroles' {
                    [pscustomobject]@{
                        PrincipalId = $Body.PrincipalId
                        Roles = @('Global Administrator')
                    }
                }
                '/admin/api/Users/getunlicenseduserscount' { '0' | ConvertFrom-Json }
                default {
                    [pscustomobject]@{
                        Path = $Path
                    }
                }
            }
        }
    }

    It 'returns grouped user settings by default' {
        $result = Get-M365AdminUserSetting

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.UserSetting'
        $result.CurrentUser.PSObject.TypeNames | Should -Contain 'M365Admin.UserSetting.CurrentUser'
        $result.Roles.PSObject.TypeNames | Should -Contain 'M365Admin.UserSetting.Roles'
        $result.TokenWithExpiry.PSObject.TypeNames | Should -Contain 'M365Admin.UserSetting.TokenWithExpiry'
        $result.UnlicensedUsersCount.PSObject.TypeNames | Should -Contain 'M365Admin.UserSetting.UnlicensedUsersCount'
        $result.UnlicensedUsersCount.Value | Should -Be 0
        $result.UnlicensedUsersCount.CountAvailable | Should -BeTrue
    }

    It 'preserves dashboard layout metadata in typed leaf output' {
        $result = Get-M365AdminUserSetting -Name DashboardLayout -CardCategory 7 -Culture 'fr-FR'

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.UserSetting.DashboardLayout'
        $result.CardCategory | Should -Be 7
        $result.Culture | Should -Be 'fr-FR'
        $result.Endpoint | Should -Be '/admin/api/users/dashboardlayout?cardCategory=7&culture=fr-FR'
    }

    It 'preserves token audience metadata in typed leaf output' {
        $result = Get-M365AdminUserSetting -Name TokenWithExpiry -TokenAudience 'https://admin.microsoft.com/'

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.UserSetting.TokenWithExpiry'
        $result.TokenAudience | Should -Be 'https://admin.microsoft.com/'
        $result.Endpoint | Should -Be '/admin/api/users/tokenWithExpiry'
    }

    It 'retrieves a zero unlicensed count without listing users' {
        $result = Get-M365AdminUserSetting -Name UnlicensedUsersCount -Force

        $result.Value | Should -Be 0
        $result.RawData | Should -Be 0
        $result.CountAvailable | Should -BeTrue
        $result.Endpoint | Should -Be '/admin/api/Users/getunlicenseduserscount'
        Should -Invoke Get-M365AdminPortalData -ModuleName M365Internals -Times 1 -Exactly -ParameterFilter {
            $Path -eq '/admin/api/Users/getunlicenseduserscount' -and
            $CacheKey -eq 'M365AdminUserSetting:UnlicensedUsersCount' -and $Force
        }
        Should -Invoke Get-M365AdminPortalData -ModuleName M365Internals -Times 0 -ParameterFilter {
            $Path -eq '/admin/api/Users/ListUsers'
        }
    }

    It 'preserves the original integer in raw and JSON views' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData { '42' | ConvertFrom-Json } -ParameterFilter {
            $Path -eq '/admin/api/Users/getunlicenseduserscount'
        }

        Get-M365AdminUserSetting -Name UnlicensedUsersCount -Raw | Should -Be 42
        Get-M365AdminUserSetting -Name UnlicensedUsersCount -RawJson | Should -Be '42'
        (Get-M365AdminUserSetting -Name UnlicensedUsersCount).CountAvailable | Should -BeTrue
    }

    It 'surfaces failures from the unlicensed count endpoint' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData { throw '403 Forbidden' } -ParameterFilter {
            $Path -eq '/admin/api/Users/getunlicenseduserscount'
        }

        { Get-M365AdminUserSetting -Name UnlicensedUsersCount } | Should -Throw '*403 Forbidden*'
    }

    It 'preserves negative portal values while marking the count unavailable' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData { '-1' | ConvertFrom-Json } -ParameterFilter {
            $Path -eq '/admin/api/Users/getunlicenseduserscount'
        }

        $result = Get-M365AdminUserSetting -Name UnlicensedUsersCount

        $result.CountAvailable | Should -BeFalse
        $result.Value | Should -Be -1
        $result.RawData | Should -Be -1
        Get-M365AdminUserSetting -Name UnlicensedUsersCount -Raw | Should -Be -1
        Get-M365AdminUserSetting -Name UnlicensedUsersCount -RawJson | Should -Be '-1'
    }
}