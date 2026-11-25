InModuleScope M365Internals {
    Describe 'Connection replacement cache isolation' {
        BeforeEach {
            $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $script:m365PortalConnection = [pscustomobject]@{ ConnectionGeneration = [guid]::NewGuid() }
            $script:m365PortalHeaders = @{ original = 'header' }
            $script:m365PortalLastBootstrapState = $null
            $script:m365CacheStore = @{ original = 'cached value' }
            $script:originalSession = $script:m365PortalSession
            $script:originalConnection = $script:m365PortalConnection
            $script:originalCache = $script:m365CacheStore
            $replacement = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            foreach ($pair in @(
                @('RootAuthToken', 'root'), @('SPAAuthCookie', 'spa'), @('OIDCAuthCookie', 'oidc'),
                @('s.AjaxSessionKey', 'ajax'), @('s.UserTenantId', '11111111-1111-1111-1111-111111111111'),
                @('x-portal-routekey', 'route'), @('UserLoginRef', '%2Fhomepage')
            )) {
                $replacement.Cookies.Add([System.Net.Cookie]::new($pair[0], $pair[1], '/', 'admin.cloud.microsoft'))
            }
            Mock Invoke-WebRequest { throw 'Unexpected network request' }
            Mock Invoke-RestMethod { throw 'Unexpected network request' }
        }

        AfterEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
            $script:m365PortalHeaders = $null
            $script:m365CacheStore = @{}
        }

        It 'keeps the existing cache when authentication fails before registration' {
            Mock Invoke-M365BrowserAuthentication { throw 'Synthetic authentication failure' }
            { Connect-M365Portal -BrowserSignIn } | Should -Throw '*Synthetic authentication failure*'
            [object]::ReferenceEquals($script:m365CacheStore, $script:originalCache) | Should -BeTrue
            $script:m365CacheStore.original | Should -Be 'cached value'
        }

        It 'restores the original cache and connection when independent replacement validation fails' {
            Mock Invoke-M365PortalRequest {
                $script:m365CacheStore['replacement'] = 'temporary'
                throw 'Synthetic validation failure'
            }
            { Connect-M365Portal -WebSession $replacement } | Should -Throw '*Synthetic validation failure*'
            [object]::ReferenceEquals($script:m365PortalSession, $script:originalSession) | Should -BeTrue
            [object]::ReferenceEquals($script:m365PortalConnection, $script:originalConnection) | Should -BeTrue
            [object]::ReferenceEquals($script:m365CacheStore, $script:originalCache) | Should -BeTrue
            $script:m365CacheStore.original | Should -Be 'cached value'
            $script:m365CacheStore.ContainsKey('replacement') | Should -BeFalse
        }

        It 'replaces the cache after a successful connection' {
            $null = Connect-M365Portal -WebSession $replacement -SkipValidation
            [object]::ReferenceEquals($script:m365PortalSession, $replacement) | Should -BeTrue
            [object]::ReferenceEquals($script:m365CacheStore, $script:originalCache) | Should -BeFalse
            $script:m365CacheStore.ContainsKey('original') | Should -BeFalse
        }

        It 'keeps the existing cache during a refresh' {
            $null = Connect-M365Portal -WebSession $replacement -SkipValidation
            $script:m365CacheStore['current'] = 'cached value'
            $currentCache = $script:m365CacheStore
            Update-M365PortalConnectionSettings
            [object]::ReferenceEquals($script:m365CacheStore, $currentCache) | Should -BeTrue
            $script:m365CacheStore.current | Should -Be 'cached value'
        }
    }
}
