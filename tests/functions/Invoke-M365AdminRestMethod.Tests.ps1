InModuleScope M365Internals {
    Describe 'Invoke-M365AdminRestMethod origin protection' {
        BeforeEach {
            $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $script:m365PortalHeaders = @{ AjaxSessionKey = 'test-session'; 'x-portal-routekey' = 'test-route' }
            Mock Update-M365PortalConnectionSettings {}
            Mock Invoke-RestMethod { [pscustomobject]@{ ok = $true } }
        }

        AfterEach {
            $script:m365PortalSession = $null
            $script:m365PortalHeaders = $null
        }

        It 'allows the portal origin and preserves its headers' {
            $result = Invoke-M365AdminRestMethod -Uri 'https://admin.cloud.microsoft:443/admin/api/test' -Headers @{ 'x-test' = 'value' }
            $result.ok | Should -BeTrue
            Assert-MockCalled Invoke-RestMethod -Exactly 1 -ParameterFilter {
                $Uri -eq 'https://admin.cloud.microsoft:443/admin/api/test' -and
                $Headers['AjaxSessionKey'] -eq 'test-session' -and
                $Headers['x-portal-routekey'] -eq 'test-route' -and
                $Headers['x-test'] -eq 'value' -and
                $MaximumRedirection -eq 0
            }
        }

        It 'keeps relative paths on the portal origin' {
            Invoke-M365AdminRestMethod -Path 'admin/api/test' | Out-Null
            Assert-MockCalled Invoke-RestMethod -Exactly 1 -ParameterFilter {
                $Uri -eq 'https://admin.cloud.microsoft/admin/api/test' -and $MaximumRedirection -eq 0
            }
        }

        It 'rejects unsafe URI <Uri> before refreshing or sending the session' -TestCases @(
            @{ Uri = 'https://example.com/' }
            @{ Uri = 'http://admin.cloud.microsoft/' }
            @{ Uri = 'https://admin.cloud.microsoft.example.com/' }
            @{ Uri = 'https://admin.cloud.microsoft:444/' }
            @{ Uri = 'https://user@admin.cloud.microsoft/' }
            @{ Uri = 'https://admin.cloud.microsoft@example.com/' }
            @{ Uri = '/relative/path' }
        ) {
            param($Uri)
            { Invoke-M365AdminRestMethod -Uri $Uri } | Should -Throw '*admin.cloud.microsoft origin*'
            Assert-MockCalled Update-M365PortalConnectionSettings -Exactly 0
            Assert-MockCalled Invoke-RestMethod -Exactly 0
        }

        It 'surfaces redirect failures without making another request' {
            Mock Invoke-RestMethod {
                $WebSession.MaximumRedirection = 0
                throw 'redirect refused'
            }
            $originalMaximumRedirection = $script:m365PortalSession.MaximumRedirection
            { Invoke-M365AdminRestMethod -Path '/admin/api/test' } | Should -Throw '*redirect refused*'
            Assert-MockCalled Invoke-RestMethod -Exactly 1 -ParameterFilter { $MaximumRedirection -eq 0 }
            $script:m365PortalSession.MaximumRedirection | Should -Be $originalMaximumRedirection
        }

        It 'restores the session redirect setting after a successful request' {
            Mock Invoke-RestMethod {
                $WebSession.MaximumRedirection = 0
                return [pscustomobject]@{ ok = $true }
            }
            $originalMaximumRedirection = $script:m365PortalSession.MaximumRedirection
            Invoke-M365AdminRestMethod -Path '/admin/api/test' | Out-Null
            $script:m365PortalSession.MaximumRedirection | Should -Be $originalMaximumRedirection
        }

        It 'reports an unconfirmed outcome when an admin write receives a redirect' {
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Found)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Redirect refused', $response)
            }
            { Invoke-M365AdminRestMethod -Path '/admin/api/test' -Method Post } | Should -Throw '*write outcome is unconfirmed*'
            Assert-MockCalled Invoke-RestMethod -Exactly 1 -ParameterFilter { $MaximumRedirection -eq 0 }
        }

        It 'follows a same-origin read redirect while retaining portal headers' {
            $script:redirectCalls = 0
            Mock Invoke-RestMethod {
                $script:redirectCalls++
                if ($script:redirectCalls -eq 1) {
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Found)
                    $response.Headers.Location = [uri]'/admin/api/next'
                    throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Redirect refused', $response)
                }
                return [pscustomobject]@{ ok = $true }
            }
            $previous = $script:m365PortalSession.MaximumRedirection
            (Invoke-M365AdminRestMethod -Path '/admin/api/test').ok | Should -BeTrue
            Assert-MockCalled Invoke-RestMethod -Exactly 2 -ParameterFilter { $MaximumRedirection -eq 0 }
            Assert-MockCalled Invoke-RestMethod -Exactly 1 -ParameterFilter {
                $Uri -eq 'https://admin.cloud.microsoft/admin/api/next' -and $Headers['AjaxSessionKey'] -eq 'test-session'
            }
            $script:m365PortalSession.MaximumRedirection | Should -Be $previous
        }

        It 'rejects a read redirect to an unapproved origin before sending headers' {
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Found)
                $response.Headers.Location = [uri]'https://example.com/collect'
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Redirect refused', $response)
            }
            { Invoke-M365AdminRestMethod -Path '/admin/api/test' } | Should -Throw '*admin.cloud.microsoft origin*'
            Assert-MockCalled Invoke-RestMethod -Exactly 1
        }

        It 'handles redirects represented by legacy web response headers' {
            $script:redirectCalls = 0
            Mock Invoke-RestMethod {
                $script:redirectCalls++
                if ($script:redirectCalls -eq 1) {
                    $headers = [System.Net.WebHeaderCollection]::new()
                    $headers['Location'] = '/admin/api/next'
                    $error = [System.Exception]::new('Redirect refused')
                    $error | Add-Member -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{ StatusCode = 302; Headers = $headers })
                    throw $error
                }
                return [pscustomobject]@{ ok = $true }
            }
            (Invoke-M365AdminRestMethod -Path '/admin/api/test').ok | Should -BeTrue
            Assert-MockCalled Invoke-RestMethod -Exactly 1 -ParameterFilter { $Uri -eq 'https://admin.cloud.microsoft/admin/api/next' }
        }

        It 'limits read redirect loops to five redirects' {
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Found)
                $response.Headers.Location = [uri]'/admin/api/test'
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Redirect refused', $response)
            }
            { Invoke-M365AdminRestMethod -Path '/admin/api/test' } | Should -Throw '*maximum of five redirects*'
            Assert-MockCalled Invoke-RestMethod -Exactly 6
        }

        It 'fails safely when a read redirect has no Location header' {
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Found)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Redirect refused', $response)
            }
            { Invoke-M365AdminRestMethod -Path '/admin/api/test' } | Should -Throw '*without a Location*'
            Assert-MockCalled Invoke-RestMethod -Exactly 1
        }
    }
}
