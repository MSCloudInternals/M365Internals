InModuleScope M365Internals {
    Describe 'Get-M365AdminGroup manual pagination' {
        BeforeEach {
            $script:m365CacheStore = @{}
            $script:m365PortalConnection = [pscustomobject]@{ TenantId = 'synthetic-tenant' }
            $script:requestedPageTokens = [System.Collections.Generic.List[object]]::new()
            Mock Update-M365PortalConnectionSettings {}
            Mock Invoke-M365PortalRequest {
                $script:requestedPageTokens.Add($Body.PageToken)
                $payload = if ($null -eq $Body.PageToken) {
                    @{ Marker = 'initial'; Groups = @(@{ Id = 'first-group' }); PageToken = 'opaque+/= token A' }
                }
                elseif ($Body.PageToken -ceq 'opaque+/= token A') {
                    @{ Marker = 'second'; Groups = @(@{ Id = 'second-group' }); PageToken = $null }
                }
                else {
                    @{ Marker = $Body.PageToken }
                }
                [pscustomobject]@{ Content = ($payload | ConvertTo-Json -Depth 4 -Compress) }
            }
        }

        AfterEach {
            $script:m365CacheStore = @{}
            $script:m365PortalConnection = $null
        }

        It 'passes the returned continuation to a second call and reaches the last page' {
            $first = M365Internals\Get-M365AdminGroup -Name Groups -Raw
            $first.Groups.Id | Should -BeExactly 'first-group'
            $first.PageToken | Should -BeExactly 'opaque+/= token A'
            $script:requestedPageTokens.Count | Should -Be 1
            ($null -eq $script:requestedPageTokens[0]) | Should -BeTrue

            $second = M365Internals\Get-M365AdminGroup -Name Groups -PageToken $first.PageToken -Raw
            $second.Groups.Id | Should -BeExactly 'second-group'
            $second.PSObject.Properties.Name | Should -Contain 'PageToken'
            ($null -eq $second.PageToken) | Should -BeTrue
            $script:requestedPageTokens.Count | Should -Be 2
            $script:requestedPageTokens[1] | Should -BeExactly $first.PageToken
        }

        It 'keeps the default, Raw, and RawJson single-page output contracts' {
            $typed = Get-M365AdminGroup Groups
            $raw = Get-M365AdminGroup -Name Groups -Raw
            $json = Get-M365AdminGroup -Name Groups -RawJson

            $typed.PSObject.TypeNames | Should -Contain 'M365Admin.Group.Groups'
            $typed.ItemName | Should -BeExactly 'Groups'
            $typed.Category | Should -BeExactly 'Groups'
            $typed.Endpoint | Should -BeExactly '/admin/api/groups/GetGroups'
            $typed.Groups.Id | Should -BeExactly 'first-group'
            $typed.RawData.Groups.Id | Should -BeExactly 'first-group'
            $raw.Groups.Id | Should -BeExactly 'first-group'
            $raw.PSObject.Properties.Name | Should -Not -Contain 'RawData'
            $json | Should -BeOfType [string]
            ($json | ConvertFrom-Json -AsHashtable).Keys | Should -Not -Contain 'RawData'
            ($json | ConvertFrom-Json).Groups.Id | Should -BeExactly 'first-group'
            $script:requestedPageTokens.Count | Should -Be 1
        }

        It 'forwards opaque tokens exactly and isolates cached pages' {
            $tokenA = 'opaque+/= token A'
            $tokenB = 'opaque+/= token B'
            (Get-M365AdminGroup -PageToken $tokenA -Raw).Marker | Should -Be 'second'
            (Get-M365AdminGroup -PageToken $tokenB -Raw).Marker | Should -Be $tokenB
            (Get-M365AdminGroup -PageToken $tokenA -Raw).Marker | Should -Be 'second'
            (Get-M365AdminGroup -Raw).Marker | Should -Be 'initial'
            $script:requestedPageTokens.Count | Should -Be 3
            $script:requestedPageTokens[0] | Should -BeExactly $tokenA
            $script:requestedPageTokens[1] | Should -BeExactly $tokenB
            $script:requestedPageTokens[2] | Should -BeNullOrEmpty
            (@($script:m365CacheStore.Keys) -join ' ') | Should -Not -Match ([regex]::Escape($tokenA))
        }

        It 'bypasses only the requested page cache with Force' {
            $null = Get-M365AdminGroup -PageToken 'a' -Raw
            $null = Get-M365AdminGroup -PageToken 'b' -Raw
            $null = Get-M365AdminGroup -PageToken 'a' -Raw -Force
            $null = Get-M365AdminGroup -PageToken 'b' -Raw
            $script:requestedPageTokens.Count | Should -Be 3
        }

        It 'preserves RawJson output for a page token' {
            $result = Get-M365AdminGroup -PageToken 'token' -RawJson | ConvertFrom-Json
            $result.Marker | Should -Be 'token'
        }

        It 'preserves the typed output contract for a page token' {
            $result = Get-M365AdminGroup -PageToken 'token'
            $result.PSObject.TypeNames | Should -Contain 'M365Admin.Group.Groups'
        }

        It 'rejects PageToken for <View> before contacting the portal' -TestCases @(
            @{ View = 'Labels' }
            @{ View = 'Permissions' }
        ) {
            param($View)

            { Get-M365AdminGroup -Name $View -PageToken 'token' } | Should -Throw '*only for the Groups view*'
            Should -Invoke Update-M365PortalConnectionSettings -Times 0
            Should -Invoke Invoke-M365PortalRequest -Times 0
        }
    }
}
