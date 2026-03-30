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
    }
}