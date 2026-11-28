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
            $result = M365Internals\Invoke-M365AdminRestMethod -Uri 'https://admin.cloud.microsoft:443/admin/api/test' -Headers @{ 'x-test' = 'value' }
            $result.ok | Should -BeTrue
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://admin.cloud.microsoft:443/admin/api/test' -and
                $Headers['AjaxSessionKey'] -eq 'test-session' -and
                $Headers['x-portal-routekey'] -eq 'test-route' -and
                $Headers['x-test'] -eq 'value' -and
                $MaximumRedirection -eq 0
            }
        }

        It 'keeps relative paths on the portal origin' {
            Invoke-M365AdminRestMethod -Path 'admin/api/test' | Out-Null
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
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
            Should -Invoke Update-M365PortalConnectionSettings -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }

        It 'reports a read transport failure and restores the redirect setting' {
            Mock Invoke-RestMethod {
                $WebSession.MaximumRedirection = 0
                throw 'Synthetic transport failure'
            }
            $originalMaximumRedirection = $script:m365PortalSession.MaximumRedirection
            { Invoke-M365AdminRestMethod -Path '/admin/api/test' } | Should -Throw '*No HTTP status was available*'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $MaximumRedirection -eq 0 }
            $script:m365PortalSession.MaximumRedirection | Should -Be $originalMaximumRedirection
        }

        It 'returns a successful write and restores the session redirect setting before a subsequent read' {
            $originalMaximumRedirection = 3
            $script:m365PortalSession.MaximumRedirection = $originalMaximumRedirection
            Mock Invoke-RestMethod {
                if ($Method -eq 'Get' -and $Uri -like '*/test') {
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Found)
                    $response.Headers.Location = [uri]'/admin/api/next'
                    throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Redirect refused', $response)
                }
                $WebSession.MaximumRedirection = 0
                [pscustomobject]@{ ok = $true }
            }

            (Invoke-M365AdminRestMethod -Path '/admin/api/test' -Method Post -Body @{ enabled = $true }).ok | Should -BeTrue
            $script:m365PortalSession.MaximumRedirection | Should -Be $originalMaximumRedirection
            (Invoke-M365AdminRestMethod -Path '/admin/api/test').ok | Should -BeTrue
            $script:m365PortalSession.MaximumRedirection | Should -Be $originalMaximumRedirection

            Should -Invoke Invoke-RestMethod -Times 3 -Exactly
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Post' -and $MaximumRedirection -eq 0 -and ($Body | ConvertFrom-Json).enabled -eq $true
            }
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'Get' -and $Uri -eq 'https://admin.cloud.microsoft/admin/api/next'
            }
        }

        It 'reports an unconfirmed outcome without replaying a redirected <Method> write' -TestCases @(
            @{ Method = 'Post'; Status = 302 }
            @{ Method = 'Put'; Status = 307 }
            @{ Method = 'Patch'; Status = 303 }
            @{ Method = 'Delete'; Status = 308 }
        ) {
            param($Method, $Status)
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$Status)
                $response.Headers.Location = [uri]'/admin/api/next'
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Redirect refused', $response)
            }
            { Invoke-M365AdminRestMethod -Path '/admin/api/test' -Method $Method } | Should -Throw "*write outcome is unconfirmed*HTTP $Status*"
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $MaximumRedirection -eq 0 }
        }

        It 'reports an unconfirmed outcome if the write response is lost' {
            Mock Invoke-RestMethod { throw [System.TimeoutException]::new('synthetic-provider-canary') }
            { Invoke-M365AdminRestMethod -Path '/admin/api/test' -Method Post } |
                Should -Throw '*write outcome is unconfirmed*timed out or was canceled*'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        }

        It 'reports HTTP <Status> with the appropriate certainty' -TestCases @(
            @{ Status = 403; Expected = 'Failed to invoke M365 REST method (Post). HTTP 403 (Forbidden).' }
            @{ Status = 408; Expected = '*write outcome is unconfirmed*HTTP 408*' }
            @{ Status = 503; Expected = '*write outcome is unconfirmed*HTTP 503*' }
        ) {
            param($Status, $Expected)
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$Status)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('synthetic-provider-canary', $response)
            }
            { Invoke-M365AdminRestMethod -Path '/admin/api/test' -Method Post } | Should -Throw $Expected
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
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
            Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter { $MaximumRedirection -eq 0 }
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
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
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
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
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://admin.cloud.microsoft/admin/api/next' }
        }

        It 'limits read redirect loops to five redirects' {
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Found)
                $response.Headers.Location = [uri]'/admin/api/test'
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Redirect refused', $response)
            }
            { Invoke-M365AdminRestMethod -Path '/admin/api/test' } | Should -Throw '*maximum of five redirects*'
            Should -Invoke Invoke-RestMethod -Times 6 -Exactly
        }

        It 'fails safely when a read redirect has no Location header' {
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Found)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Redirect refused', $response)
            }
            { Invoke-M365AdminRestMethod -Path '/admin/api/test' } | Should -Throw '*without a Location*'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        }
    }
}
