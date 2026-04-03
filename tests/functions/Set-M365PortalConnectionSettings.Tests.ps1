InModuleScope M365Internals {
    Describe 'Set-M365PortalConnectionSettings' {
        BeforeEach {
            Set-Variable -Scope Script -Name m365PortalSession -Value $null
            Set-Variable -Scope Script -Name m365PortalHeaders -Value $null
            Set-Variable -Scope Script -Name m365PortalConnection -Value $null
            Set-Variable -Scope Script -Name m365PortalLastBootstrapState -Value $null

            $script:classicModernProbeCount = 0
            $script:newTestPortalWebSession = {
                param (
                    [string]$TenantId = '11111111-1111-1111-1111-111111111111',
                    [switch]$WithoutAjaxSessionKey
                )

                $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()

                $cookies = @(
                    [System.Net.Cookie]::new('RootAuthToken', 'root-auth', '/', 'admin.cloud.microsoft'),
                    [System.Net.Cookie]::new('SPAAuthCookie', 'spa-auth', '/', 'admin.cloud.microsoft'),
                    [System.Net.Cookie]::new('OIDCAuthCookie', 'oidc-auth', '/', 'admin.cloud.microsoft'),
                    [System.Net.Cookie]::new('s.SessID', 'session-123', '/', 'admin.cloud.microsoft'),
                    [System.Net.Cookie]::new('s.UserTenantId', $TenantId, '/', 'admin.cloud.microsoft'),
                    [System.Net.Cookie]::new('s.userid', 'admin%40contoso.com', '/', 'admin.cloud.microsoft'),
                    [System.Net.Cookie]::new('x-portal-routekey', 'route-key', '/', 'admin.cloud.microsoft'),
                    [System.Net.Cookie]::new('UserLoginRef', '%2Fhomepage', '/', 'admin.cloud.microsoft')
                )

                if (-not $WithoutAjaxSessionKey) {
                    $cookies += [System.Net.Cookie]::new('s.AjaxSessionKey', 'ajax-session', '/', 'admin.cloud.microsoft')
                }

                foreach ($cookie in $cookies) {
                    $session.Cookies.Add($cookie)
                }

                return $session
            }

            Mock Get-M365PortalContextHeaders { @{} }
            Mock Set-M365Cache { }
        }

        AfterEach {
            Set-Variable -Scope Script -Name m365PortalSession -Value $null
            Set-Variable -Scope Script -Name m365PortalHeaders -Value $null
            Set-Variable -Scope Script -Name m365PortalConnection -Value $null
            Set-Variable -Scope Script -Name m365PortalLastBootstrapState -Value $null
        }

        It 'retries the bootstrap flow when ClassicModernAdminDataStream returns the admin HTML shell' {
            $session = & $script:newTestPortalWebSession

            Mock Invoke-M365PortalPostLandingBootstrap {
                $script:m365PortalLastBootstrapState = [pscustomobject]@{
                    AjaxSessionKeyPresent = $true
                    LogClientAttempted = $true
                    LogClientSucceeded = $true
                    LogClientError = $null
                }

                return $WebSession
            }

            Mock Invoke-M365PortalRequest {
                switch ($Path) {
                    '/adminportal/home/ClassicModernAdminDataStream?ref=/homepage' {
                        $script:classicModernProbeCount++

                        if ($script:classicModernProbeCount -eq 1) {
                            return [pscustomobject]@{
                                StatusCode = 200
                                Content = '<html><body>Temporary portal shell</body></html>'
                                Headers = @{ 'Content-Type' = 'text/html' }
                            }
                        }

                        return [pscustomobject]@{
                            StatusCode = 200
                            Content = '$Config = {"TID":"11111111-1111-1111-1111-111111111111"}'
                            Headers = @{ 'Content-Type' = 'text/html' }
                        }
                    }
                    '/admin/api/coordinatedbootstrap/shellinfo' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content = '{"TID":"11111111-1111-1111-1111-111111111111"}'
                            Headers = @{ 'Content-Type' = 'application/json' }
                        }
                    }
                    '/admin/api/navigation' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content = '{}'
                            Headers = @{ 'Content-Type' = 'application/json' }
                        }
                    }
                    '/admin/api/features/all' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content = '{}'
                            Headers = @{ 'Content-Type' = 'application/json' }
                        }
                    }
                    default {
                        throw "Unexpected path: $Path"
                    }
                }
            }

            $result = Set-M365PortalConnectionSettings -WebSession $session -AuthSource 'UnitTest' -UserAgent 'UnitTestAgent/1.0'

            $result.TenantId | Should -Be '11111111-1111-1111-1111-111111111111'
            $result.Username | Should -Be 'admin@contoso.com'
            $script:classicModernProbeCount | Should -Be 2

            Assert-MockCalled Invoke-M365PortalPostLandingBootstrap -Times 1
            Assert-MockCalled Invoke-M365PortalRequest -Times 5 -ParameterFilter {
                $SkipConnectionRefresh -and $SkipAutoHeal
            }
        }

        It 'surfaces logclient failures when the HTML shell persists after the retry' {
            $session = & $script:newTestPortalWebSession

            Mock Invoke-M365PortalPostLandingBootstrap {
                $script:m365PortalLastBootstrapState = [pscustomobject]@{
                    AjaxSessionKeyPresent = $true
                    LogClientAttempted = $true
                    LogClientSucceeded = $false
                    LogClientError = 'logclient failed with 500'
                }

                return $WebSession
            }

            Mock Invoke-M365PortalRequest {
                return [pscustomobject]@{
                    StatusCode = 200
                    Content = '<html><body>Portal shell</body></html>'
                    Headers = @{ 'Content-Type' = 'text/html' }
                }
            } -ParameterFilter {
                $Path -eq '/adminportal/home/ClassicModernAdminDataStream?ref=/homepage'
            }

            {
                Set-M365PortalConnectionSettings -WebSession $session -AuthSource 'UnitTest' -UserAgent 'UnitTestAgent/1.0'
            } | Should -Throw '*ClassicModernAdminDataStream*HTML error shell*logclient failed with 500*'

            Assert-MockCalled Invoke-M365PortalPostLandingBootstrap -Times 1
        }

        It 'accepts cookie sessions that bootstrap the AjaxSessionKey later' {
            $session = & $script:newTestPortalWebSession -WithoutAjaxSessionKey

            Mock Invoke-M365PortalPostLandingBootstrap {
                $WebSession.Cookies.Add([System.Net.Cookie]::new('s.AjaxSessionKey', 'ajax-session', '/', 'admin.cloud.microsoft'))
                $script:m365PortalLastBootstrapState = [pscustomobject]@{
                    AjaxSessionKeyPresent = $true
                    LogClientAttempted = $true
                    LogClientSucceeded = $true
                    LogClientError = $null
                }

                return $WebSession
            }

            Mock Invoke-M365PortalRequest {
                switch ($Path) {
                    '/adminportal/home/ClassicModernAdminDataStream?ref=/homepage' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content = '$Config = {"TID":"11111111-1111-1111-1111-111111111111"}'
                            Headers = @{ 'Content-Type' = 'text/html' }
                        }
                    }
                    '/admin/api/coordinatedbootstrap/shellinfo' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content = '{"TID":"11111111-1111-1111-1111-111111111111"}'
                            Headers = @{ 'Content-Type' = 'application/json' }
                        }
                    }
                    '/admin/api/navigation' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content = '{}'
                            Headers = @{ 'Content-Type' = 'application/json' }
                        }
                    }
                    '/admin/api/features/all' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content = '{}'
                            Headers = @{ 'Content-Type' = 'application/json' }
                        }
                    }
                    default {
                        throw "Unexpected path: $Path"
                    }
                }
            }

            $result = Set-M365PortalConnectionSettings -WebSession $session -AuthSource 'UnitTest' -UserAgent 'UnitTestAgent/1.0'

            $result.TenantId | Should -Be '11111111-1111-1111-1111-111111111111'
            $script:m365PortalHeaders['AjaxSessionKey'] | Should -Be 'ajax-session'

            Assert-MockCalled Invoke-M365PortalPostLandingBootstrap -Times 1
        }

        It 'projects token freshness metadata onto the stored connection' {
            $session = & $script:newTestPortalWebSession
            $tokenMetadata = [pscustomobject]@{
                Source         = 'id_token'
                ExpiresOnUtc   = [datetime]::UtcNow.AddMinutes(55)
                FreshUntilUtc  = [datetime]::UtcNow.AddMinutes(50)
                IssuedAtUtc    = [datetime]::UtcNow.AddMinutes(-5)
                Audience       = 'https://admin.cloud.microsoft/'
            }
            $session | Add-Member -NotePropertyName M365TokenMetadata -NotePropertyValue $tokenMetadata -Force

            Mock Invoke-M365PortalPostLandingBootstrap { $WebSession }

            Mock Invoke-M365PortalRequest {
                switch ($Path) {
                    '/adminportal/home/ClassicModernAdminDataStream?ref=/homepage' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content = '$Config = {"TID":"11111111-1111-1111-1111-111111111111"}'
                            Headers = @{ 'Content-Type' = 'text/html' }
                        }
                    }
                    '/admin/api/coordinatedbootstrap/shellinfo' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content = '{"TID":"11111111-1111-1111-1111-111111111111"}'
                            Headers = @{ 'Content-Type' = 'application/json' }
                        }
                    }
                    default {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Content = '{}'
                            Headers = @{ 'Content-Type' = 'application/json' }
                        }
                    }
                }
            }

            $result = Set-M365PortalConnectionSettings -WebSession $session -AuthSource 'UnitTest' -AuthFlow 'Credential' -UserAgent 'UnitTestAgent/1.0'

            $result.TokenMetadata.Source | Should -Be 'id_token'
            $result.TokenFreshnessSource | Should -Be 'id_token'
            $result.TokenExpiresOnUtc | Should -Be $tokenMetadata.ExpiresOnUtc
            $result.TokenFreshUntilUtc | Should -Be $tokenMetadata.FreshUntilUtc
            $result.TokenIssuedAtUtc | Should -Be $tokenMetadata.IssuedAtUtc
            $result.TokenAudience | Should -Be 'https://admin.cloud.microsoft/'
            $result.TokenFresh | Should -BeTrue
            $result.TokenRefreshRecommended | Should -BeFalse
            $result.RefreshedAt | Should -Not -BeNullOrEmpty
        }

        It 'does not carry prior connection age or token metadata into a new session' {
            $previousSession = & $script:newTestPortalWebSession -TenantId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            $previousConnectedAt = (Get-Date).AddHours(-6)
            $previousTokenMetadata = [pscustomobject]@{
                Source         = 'old_id_token'
                ExpiresOnUtc   = [datetime]::UtcNow.AddMinutes(10)
                FreshUntilUtc  = [datetime]::UtcNow.AddMinutes(5)
                IssuedAtUtc    = [datetime]::UtcNow.AddMinutes(-50)
                Audience       = 'https://admin.cloud.microsoft/'
            }

            Set-Variable -Scope Script -Name m365PortalSession -Value $previousSession
            Set-Variable -Scope Script -Name m365PortalConnection -Value ([pscustomobject]@{
                ConnectedAt                   = $previousConnectedAt
                TenantId                      = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                AuthFlow                      = 'OldFlow'
                TokenMetadata                 = $previousTokenMetadata
                TokenRefreshSatisfiedUntilUtc = $previousTokenMetadata.FreshUntilUtc
            })
            Set-Variable -Scope Script -Name m365PortalHeaders -Value @{}

            $newSession = & $script:newTestPortalWebSession -TenantId '22222222-2222-2222-2222-222222222222'
            $result = Set-M365PortalConnectionSettings -WebSession $newSession -AuthSource 'NewFlow' -UserAgent 'UnitTestAgent/1.0' -SkipValidation

            $result.TenantId | Should -Be '22222222-2222-2222-2222-222222222222'
            $result.AuthFlow | Should -Be 'NewFlow'
            $result.TokenMetadata | Should -BeNullOrEmpty
            $result.TokenFreshnessSource | Should -BeNullOrEmpty
            $result.TokenRefreshSatisfiedUntilUtc | Should -BeNullOrEmpty
            $result.ConnectedAt | Should -Not -Be $previousConnectedAt
            ($result.ConnectedAt -gt $previousConnectedAt) | Should -BeTrue
        }

        It 'preserves prior connection age and token metadata when refreshing the same session' {
            $session = & $script:newTestPortalWebSession
            $previousConnectedAt = (Get-Date).AddHours(-3)
            $previousTokenMetadata = [pscustomobject]@{
                Source         = 'id_token'
                ExpiresOnUtc   = [datetime]::UtcNow.AddMinutes(20)
                FreshUntilUtc  = [datetime]::UtcNow.AddMinutes(15)
                IssuedAtUtc    = [datetime]::UtcNow.AddMinutes(-40)
                Audience       = 'https://admin.cloud.microsoft/'
            }

            Set-Variable -Scope Script -Name m365PortalSession -Value $session
            Set-Variable -Scope Script -Name m365PortalConnection -Value ([pscustomobject]@{
                ConnectedAt                   = $previousConnectedAt
                TenantId                      = '11111111-1111-1111-1111-111111111111'
                AuthFlow                      = 'Credential'
                TokenMetadata                 = $previousTokenMetadata
                TokenRefreshSatisfiedUntilUtc = $previousTokenMetadata.FreshUntilUtc
            })
            Set-Variable -Scope Script -Name m365PortalHeaders -Value @{}

            $result = Set-M365PortalConnectionSettings -WebSession $session -AuthSource 'Credential' -UserAgent 'UnitTestAgent/1.0' -SkipValidation

            $result.ConnectedAt | Should -Be $previousConnectedAt
            $result.TokenMetadata.Source | Should -Be 'id_token'
            $result.TokenRefreshSatisfiedUntilUtc | Should -Be $previousTokenMetadata.FreshUntilUtc
        }
    }

    Describe 'Invoke-M365PortalRequest' {
        BeforeEach {
            Set-Variable -Scope Script -Name m365PortalLastBootstrapState -Value $null
            $script:staleTokenFreshUntilUtc = [datetime]::UtcNow.AddMinutes(-6)
            $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $script:m365PortalHeaders = @{
                AjaxSessionKey    = 'ajax-session'
                'x-portal-routekey' = 'route-key'
            }
            $script:m365PortalConnection = [pscustomobject]@{
                TokenMetadata                 = [pscustomobject]@{
                    Source        = 'AdminPortalIdToken'
                    ExpiresOnUtc  = [datetime]::UtcNow.AddMinutes(-1)
                    FreshUntilUtc = $script:staleTokenFreshUntilUtc
                    IssuedAtUtc   = [datetime]::UtcNow.AddMinutes(-66)
                    Audience      = 'https://admin.cloud.microsoft/'
                }
                TokenFreshUntilUtc           = $script:staleTokenFreshUntilUtc
                TokenRefreshSatisfiedUntilUtc = $null
                TokenRefreshRecommended      = $true
            }

            Mock Update-M365PortalConnectionSettings { }
            Mock Invoke-M365PortalPostLandingBootstrap { }
            Mock Invoke-WebRequest {
                [pscustomobject]@{
                    StatusCode = 200
                    Content    = '{}'
                    Headers    = @{ 'Content-Type' = 'application/json' }
                }
            }
        }

        AfterEach {
            Set-Variable -Scope Script -Name m365PortalSession -Value $null
            Set-Variable -Scope Script -Name m365PortalHeaders -Value $null
            Set-Variable -Scope Script -Name m365PortalConnection -Value $null
            Set-Variable -Scope Script -Name m365PortalLastBootstrapState -Value $null
        }

        It 'marks a stale token freshness window as satisfied after a successful proactive self-heal' {
            $null = Invoke-M365PortalRequest -Path '/admin/api/navigation'

            $script:m365PortalSession.M365TokenRefreshSatisfiedUntilUtc | Should -Be $script:staleTokenFreshUntilUtc
            $script:m365PortalConnection.TokenRefreshSatisfiedUntilUtc | Should -Be $script:staleTokenFreshUntilUtc
            $script:m365PortalConnection.TokenRefreshRecommended | Should -BeFalse

            $script:m365PortalSession | Add-Member -NotePropertyName M365LastTokenRefreshAttemptAt -NotePropertyValue (Get-Date).AddMinutes(-6) -Force

            $null = Invoke-M365PortalRequest -Path '/admin/api/navigation'

            Assert-MockCalled Invoke-M365PortalPostLandingBootstrap -Times 1
        }
    }

    Describe 'Test-M365PortalConnectionNeedsRefresh' {
        It 'treats a missing header map as needing refresh' {
            $connection = [pscustomobject]@{
                TokenRefreshRecommended = $false
            }

            (Test-M365PortalConnectionNeedsRefresh -Connection $connection) | Should -BeTrue
        }
    }
}
