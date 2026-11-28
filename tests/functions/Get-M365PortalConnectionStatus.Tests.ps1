InModuleScope M365Internals {
    Describe 'Get-M365PortalConnectionStatus' {
        BeforeEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
            $script:m365PortalRetainedProfilePath = $null
            $profile = (New-Item -ItemType Directory -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString()))).FullName
            Mock Clear-M365Cache {}
            Mock Invoke-WebRequest { throw 'Unexpected network request' }
            Mock Invoke-RestMethod { throw 'Unexpected network request' }
            Mock Invoke-M365BrowserAuthentication { throw 'Unexpected authentication' }

            $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            foreach ($pair in @(
                @('RootAuthToken', 'root'), @('SPAAuthCookie', 'spa'), @('OIDCAuthCookie', 'oidc'),
                @('s.AjaxSessionKey', 'ajax'), @('s.UserTenantId', '11111111-1111-1111-1111-111111111111'),
                @('x-portal-routekey', 'route'), @('UserLoginRef', '%2Fhomepage')
            )) {
                $session.Cookies.Add([System.Net.Cookie]::new($pair[0], $pair[1], '/', 'admin.cloud.microsoft'))
            }
        }

        AfterEach {
            $script:m365PortalSession = $null
            $script:m365PortalConnection = $null
            $script:m365PortalRetainedProfilePath = $null
        }

        It 'reports only local flags when disconnected' {
            $status = Get-M365PortalConnectionStatus
            $status.ConnectionPresent | Should -BeFalse
            $status.RetainedBrowserProfile | Should -BeFalse
            @($status.PSObject.Properties.Name) | Should -HaveCount 2
            Should -Invoke Invoke-M365BrowserAuthentication -Times 0 -Exactly
            Should -Invoke Invoke-WebRequest -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }

        It 'reports a registered directory without disclosing the profile path' {
            $connection = Set-M365PortalConnectionSettings -WebSession $session -AuthFlow BrowserSignIn -RetainedProfilePath $profile -SkipValidation
            $status = Get-M365PortalConnectionStatus
            $status.ConnectionPresent | Should -BeTrue
            $status.RetainedBrowserProfile | Should -BeTrue
            @($status.PSObject.Properties.Name) | Should -HaveCount 2
            $connection.PSObject.Properties.Name | Should -Not -Contain 'RetainedProfilePath'
            Should -Invoke Invoke-M365BrowserAuthentication -Times 0 -Exactly
            Should -Invoke Invoke-WebRequest -Times 0 -Exactly
            Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        }

        It 'reports an unavailable directory after deletion or replacement with a file' {
            $null = Set-M365PortalConnectionSettings -WebSession $session -AuthFlow BrowserSignIn -RetainedProfilePath $profile -SkipValidation
            Remove-Item -LiteralPath $profile
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeFalse
            $null = New-Item -ItemType File -Path $profile
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeFalse
        }

        It 'preserves retained status during an ordinary refresh' {
            $null = Set-M365PortalConnectionSettings -WebSession $session -AuthFlow BrowserSignIn -RetainedProfilePath $profile -SkipValidation
            Update-M365PortalConnectionSettings
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeTrue
        }

        It 'clears retained status when a non-browser replacement uses the same input session' {
            $null = Set-M365PortalConnectionSettings -WebSession $session -AuthFlow BrowserSignIn -RetainedProfilePath $profile -SkipValidation
            $null = Connect-M365Portal -WebSession $session -SkipValidation
            $status = Get-M365PortalConnectionStatus
            $status.ConnectionPresent | Should -BeTrue
            $status.RetainedBrowserProfile | Should -BeFalse
        }

        It 'preserves the established profile when browser authentication fails' {
            $null = Set-M365PortalConnectionSettings -WebSession $session -AuthFlow BrowserSignIn -RetainedProfilePath $profile -SkipValidation
            Mock Invoke-M365BrowserAuthentication { throw 'Synthetic authentication failure' }
            { Connect-M365Portal -BrowserSignIn -SkipValidation } | Should -Throw '*Synthetic authentication failure*'
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeTrue
        }

        It 'records profile availability on the browser and SSO artifact routes' {
            Mock Invoke-M365BrowserAuthentication {
                [pscustomobject]@{ PortalWebSession = $session; RetainedProfilePath = $profile }
            }
            Mock Invoke-M365SsoAuthentication {
                [pscustomobject]@{ PortalWebSession = (Copy-M365PortalWebSession -WebSession $session); RetainedProfilePath = $profile }
            }
            $null = Connect-M365Portal -BrowserSignIn -SkipValidation
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeTrue
            $null = Connect-M365Portal -SSO -SkipValidation
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeTrue
        }

        It 'clears retained status when a private browser session replaces an existing connection' {
            $null = Set-M365PortalConnectionSettings -WebSession $session -AuthFlow BrowserSignIn -RetainedProfilePath $profile -SkipValidation
            Mock Invoke-M365BrowserAuthentication {
                [pscustomobject]@{ PortalWebSession = (Copy-M365PortalWebSession -WebSession $session); RetainedProfilePath = $null }
            } -ParameterFilter { $PrivateSession }
            $null = Connect-M365Portal -BrowserSignIn -PrivateSession -SkipValidation
            (Get-M365PortalConnectionStatus).ConnectionPresent | Should -BeTrue
            (Get-M365PortalConnectionStatus).RetainedBrowserProfile | Should -BeFalse
        }
    }
}
