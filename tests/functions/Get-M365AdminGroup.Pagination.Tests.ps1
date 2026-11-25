InModuleScope M365Internals {
    Describe 'Get-M365AdminGroup manual pagination' {
        BeforeEach {
            $script:m365CacheStore = @{}
            $script:m365PortalConnection = [pscustomobject]@{ TenantId = 'synthetic-tenant' }
            $script:requestedPageTokens = [System.Collections.Generic.List[object]]::new()
            Mock Update-M365PortalConnectionSettings {}
            Mock Invoke-M365PortalRequest {
                $script:requestedPageTokens.Add($Body.PageToken)
                $value = if ($null -eq $Body.PageToken) { 'initial' } else { $Body.PageToken }
                [pscustomobject]@{ Content = (@{ Marker = $value } | ConvertTo-Json -Compress) }
            }
        }

        AfterEach {
            $script:m365CacheStore = @{}
            $script:m365PortalConnection = $null
        }

        It 'keeps the existing initial request and raw output contract' {
            $result = Get-M365AdminGroup -Raw
            $result.Marker | Should -Be 'initial'
            $script:requestedPageTokens.Count | Should -Be 1
            $script:requestedPageTokens[0] | Should -BeNullOrEmpty
        }

        It 'forwards opaque tokens exactly and isolates cached pages' {
            $tokenA = 'opaque+/= token A'
            $tokenB = 'opaque+/= token B'
            (Get-M365AdminGroup -PageToken $tokenA -Raw).Marker | Should -Be $tokenA
            (Get-M365AdminGroup -PageToken $tokenB -Raw).Marker | Should -Be $tokenB
            (Get-M365AdminGroup -PageToken $tokenA -Raw).Marker | Should -Be $tokenA
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

        It 'rejects PageToken for other views before contacting the portal' {
            { Get-M365AdminGroup -Name Labels -PageToken 'token' } | Should -Throw '*only for the Groups view*'
            Should -Invoke Update-M365PortalConnectionSettings -Times 0
            Should -Invoke Invoke-M365PortalRequest -Times 0
        }
    }
}
