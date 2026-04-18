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
}