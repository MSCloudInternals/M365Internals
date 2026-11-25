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

        It 'leaves an active web session unchanged when same-session reconnect validation fails' {
            $null = Connect-M365Portal -WebSession $replacement -SkipValidation
            $originalSession = $script:m365PortalSession
            $originalConnection = $script:m365PortalConnection
            $originalCache = $script:m365CacheStore
            $originalSession.UserAgent = 'original-agent'
            $originalSession.Headers['X-Test'] = 'original-header'
            Mock Invoke-M365PortalRequest {
                $script:m365PortalSession.Cookies.Add([System.Net.Cookie]::new('RootAuthToken', 'changed', '/', 'admin.cloud.microsoft'))
                $script:m365PortalSession.Headers['X-Test'] = 'changed'
                throw 'Synthetic validation failure'
            }

            { Connect-M365Portal -WebSession $originalSession -UserAgent 'replacement-agent' } |
                Should -Throw '*Synthetic validation failure*'

            [object]::ReferenceEquals($script:m365PortalSession, $originalSession) | Should -BeTrue
            [object]::ReferenceEquals($script:m365PortalConnection, $originalConnection) | Should -BeTrue
            [object]::ReferenceEquals($script:m365CacheStore, $originalCache) | Should -BeTrue
            $originalSession.UserAgent | Should -Be 'original-agent'
            $originalSession.Headers['X-Test'] | Should -Be 'original-header'
            $originalSession.Cookies.GetCookies([uri]'https://admin.cloud.microsoft/')['RootAuthToken'].Value | Should -Be 'root'
        }

        It 'uses the staged session after a successful same-session reconnect' {
            $null = Connect-M365Portal -WebSession $replacement -SkipValidation
            $originalSession = $script:m365PortalSession
            $generation = Get-M365PortalConnectionGeneration
            $null = Connect-M365Portal -WebSession $originalSession -UserAgent 'replacement-agent' -SkipValidation
            [object]::ReferenceEquals($script:m365PortalSession, $originalSession) | Should -BeFalse
            $script:m365PortalSession.UserAgent | Should -Be 'replacement-agent'
            $originalSession.UserAgent | Should -Not -Be 'replacement-agent'
            $script:m365PortalSession.Cookies.GetCookies([uri]'https://admin.cloud.microsoft/')['RootAuthToken'].Value | Should -Be 'root'
            Get-M365PortalConnectionGeneration | Should -Not -Be $generation
        }
    }

    Describe 'Copy-M365PortalWebSession' {
        It 'copies cookies from multiple domains and paths without sharing mutable state' {
            $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $session.Cookies.SetCookies([uri]'https://admin.cloud.microsoft/adminportal/', 'hostonly=one; Path=/adminportal; Secure; HttpOnly')
            $session.Cookies.Add([System.Net.Cookie]::new('login', 'two', '/', 'login.microsoftonline.com'))
            $legacyCookies = @(Get-M365LegacyCookieCollection -CookieContainer $session.Cookies)
            $legacyCookies.Count | Should -Be 2
            @($legacyCookies.Name) | Should -Contain 'hostonly'
            @($legacyCookies.Name) | Should -Contain 'login'
            $session.Headers['X-Test'] = 'original'
            $session.UserAgent = 'original-agent'
            $session.MaximumRedirection = 3
            $session | Add-Member -NotePropertyName M365TokenRefreshSatisfiedUntilUtc -NotePropertyValue ([datetime]'2030-01-01')
            $copy = Copy-M365PortalWebSession -WebSession $session
            $copy.Cookies.GetCookies([uri]'https://admin.cloud.microsoft/adminportal/')['hostonly'].Value | Should -Be 'one'
            $copy.Cookies.GetCookies([uri]'https://sub.admin.cloud.microsoft/adminportal/')['hostonly'] | Should -BeNullOrEmpty
            $copy.Cookies.GetCookies([uri]'https://login.microsoftonline.com/')['login'].Value | Should -Be 'two'
            $copy.MaximumRedirection | Should -Be 3
            $copy.M365TokenRefreshSatisfiedUntilUtc | Should -Be ([datetime]'2030-01-01')
            $copy.Headers['X-Test'] = 'changed'
            $copy.Cookies.Add([System.Net.Cookie]::new('login', 'changed', '/', 'login.microsoftonline.com'))
            $session.Headers['X-Test'] | Should -Be 'original'
            $session.Cookies.GetCookies([uri]'https://login.microsoftonline.com/')['login'].Value | Should -Be 'two'
        }
    }
}
