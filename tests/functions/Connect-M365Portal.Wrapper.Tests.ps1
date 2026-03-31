BeforeAll {
    function New-TestSecureString {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Uses fixed placeholder values in unit tests only.')]
        param(
            [Parameter(Mandatory)]
            [string]$Value
        )

        return (ConvertTo-SecureString $Value -AsPlainText -Force)
    }
}

Describe 'Connect-M365Portal public wrappers' {
    Describe 'Connect-M365PortalByBrowser' {
        BeforeEach {
            Mock Connect-M365Portal {
                [pscustomobject]@{
                    Connected = $true
                }
            } -ModuleName M365Internals
        }

        It 'forwards browser sign-in options to Connect-M365Portal' {
            $result = Connect-M365PortalByBrowser -Username 'user@contoso.com' -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2' -TimeoutSeconds 120 -BrowserPath 'msedge.exe' -ProfilePath 'C:\Temp\M365BrowserProfile' -ResetProfile -PrivateSession -UserAgent 'Custom-Agent/1.0' -SkipValidation

            $result.Connected | Should -BeTrue
            Should -Invoke Connect-M365Portal -ModuleName M365Internals -Times 1 -Exactly -ParameterFilter {
                $BrowserSignIn -and
                $Username -eq 'user@contoso.com' -and
                $TenantId -eq '8612f621-73ca-4c12-973c-0da732bc44c2' -and
                $TimeoutSeconds -eq 120 -and
                $BrowserPath -eq 'msedge.exe' -and
                $ProfilePath -eq 'C:\Temp\M365BrowserProfile' -and
                $ResetProfile -and
                $PrivateSession -and
                $UserAgent -eq 'Custom-Agent/1.0' -and
                $SkipValidation
            }
        }
    }

    Describe 'Connect-M365PortalByCredential' {
        BeforeEach {
            $script:lastCredentialConnectParams = $null

            Mock Connect-M365Portal {
                param(
                    $Credential,
                    $Username,
                    $Password,
                    $TotpSecret,
                    $MfaMethod,
                    $TenantId,
                    $UserAgent,
                    [switch]$SkipValidation
                )

                $script:lastCredentialConnectParams = $PSBoundParameters
                [pscustomobject]@{
                    Connected = $true
                }
            } -ModuleName M365Internals

            Mock Get-Credential {
                [pscredential]::new('prompted@contoso.com', (New-TestSecureString -Value 'Password123!'))
            } -ModuleName M365Internals
        }

        It 'forwards PSCredential and MFA options to Connect-M365Portal' {
            $credential = [pscredential]::new('user@contoso.com', (New-TestSecureString -Value 'Password123!'))

            $result = Connect-M365PortalByCredential -Credential $credential -TotpSecret 'JBSWY3DPEHPK3PXP' -MfaMethod 'PhoneAppOTP' -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2' -UserAgent 'Custom-Agent/1.0' -SkipValidation

            $result.Connected | Should -BeTrue
            Should -Invoke Connect-M365Portal -ModuleName M365Internals -Times 1 -Exactly
            $script:lastCredentialConnectParams.Credential.UserName | Should -Be 'user@contoso.com'
            $script:lastCredentialConnectParams.TotpSecret | Should -Be 'JBSWY3DPEHPK3PXP'
            $script:lastCredentialConnectParams.MfaMethod | Should -Be 'PhoneAppOTP'
            $script:lastCredentialConnectParams.TenantId | Should -Be '8612f621-73ca-4c12-973c-0da732bc44c2'
            $script:lastCredentialConnectParams.UserAgent | Should -Be 'Custom-Agent/1.0'
            $script:lastCredentialConnectParams.SkipValidation | Should -BeTrue
        }

        It 'prompts for a PSCredential when explicit credential inputs are omitted' {
            $result = Connect-M365PortalByCredential -UserAgent 'Custom-Agent/1.0'

            $result.Connected | Should -BeTrue
            Should -Invoke Get-Credential -ModuleName M365Internals -Times 1 -Exactly
            Should -Invoke Connect-M365Portal -ModuleName M365Internals -Times 1 -Exactly
            $script:lastCredentialConnectParams.Credential.UserName | Should -Be 'prompted@contoso.com'
            $script:lastCredentialConnectParams.UserAgent | Should -Be 'Custom-Agent/1.0'
        }
    }

    Describe 'Connect-M365PortalByEstsCookie' {
        BeforeEach {
            $script:lastEstsConnectParams = $null

            Mock Connect-M365Portal {
                param(
                    $EstsAuthCookieValue,
                    $SecureEstsAuthCookieValue,
                    $TenantId,
                    $UserAgent,
                    [switch]$SkipValidation
                )

                $script:lastEstsConnectParams = $PSBoundParameters
                [pscustomobject]@{
                    Connected = $true
                }
            } -ModuleName M365Internals
        }

        It 'forwards a plain-text ESTS cookie to Connect-M365Portal' {
            $result = Connect-M365PortalByEstsCookie -EstsAuthCookieValue 'ests-cookie' -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2' -UserAgent 'Custom-Agent/1.0' -SkipValidation

            $result.Connected | Should -BeTrue
            Should -Invoke Connect-M365Portal -ModuleName M365Internals -Times 1 -Exactly
            $script:lastEstsConnectParams.EstsAuthCookieValue | Should -Be 'ests-cookie'
            $script:lastEstsConnectParams.TenantId | Should -Be '8612f621-73ca-4c12-973c-0da732bc44c2'
            $script:lastEstsConnectParams.UserAgent | Should -Be 'Custom-Agent/1.0'
            $script:lastEstsConnectParams.SkipValidation | Should -BeTrue
        }

        It 'forwards a secure-string ESTS cookie to Connect-M365Portal' {
            $secureCookie = New-TestSecureString -Value 'ests-cookie'

            $result = Connect-M365PortalByEstsCookie -SecureEstsAuthCookieValue $secureCookie -UserAgent 'Custom-Agent/1.0'

            $result.Connected | Should -BeTrue
            Should -Invoke Connect-M365Portal -ModuleName M365Internals -Times 1 -Exactly
            $script:lastEstsConnectParams.SecureEstsAuthCookieValue | Should -Not -BeNullOrEmpty
            $script:lastEstsConnectParams.UserAgent | Should -Be 'Custom-Agent/1.0'
        }
    }

    Describe 'Connect-M365PortalByPhoneSignIn' {
        BeforeEach {
            Mock Connect-M365Portal {
                [pscustomobject]@{
                    Connected = $true
                }
            } -ModuleName M365Internals

            Mock Read-Host { 'phone@contoso.com' } -ModuleName M365Internals
        }

        It 'prompts for a username and forwards phone sign-in options' {
            $result = Connect-M365PortalByPhoneSignIn -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2' -TimeoutSeconds 120 -UserAgent 'Custom-Agent/1.0' -SkipValidation

            $result.Connected | Should -BeTrue
            Should -Invoke Read-Host -ModuleName M365Internals -Times 1 -Exactly
            Should -Invoke Connect-M365Portal -ModuleName M365Internals -Times 1 -Exactly -ParameterFilter {
                $PhoneSignIn -and
                $Username -eq 'phone@contoso.com' -and
                $TenantId -eq '8612f621-73ca-4c12-973c-0da732bc44c2' -and
                $TimeoutSeconds -eq 120 -and
                $UserAgent -eq 'Custom-Agent/1.0' -and
                $SkipValidation
            }
        }
    }

    Describe 'Connect-M365PortalBySoftwarePasskey' {
        BeforeEach {
            Mock Connect-M365Portal {
                [pscustomobject]@{
                    Connected = $true
                }
            } -ModuleName M365Internals
        }

        It 'forwards passkey and Key Vault options to Connect-M365Portal' {
            $result = Connect-M365PortalBySoftwarePasskey -KeyFilePath '.\admin-kv.passkey' -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2' -KeyVaultTenantId '72f988bf-86f1-41af-91ab-2d7cd011db47' -KeyVaultClientId '11111111-2222-3333-4444-555555555555' -KeyVaultApiVersion '7.5' -UserAgent 'Custom-Agent/1.0' -SkipValidation

            $result.Connected | Should -BeTrue
            Should -Invoke Connect-M365Portal -ModuleName M365Internals -Times 1 -Exactly -ParameterFilter {
                $KeyFilePath -eq '.\admin-kv.passkey' -and
                $TenantId -eq '8612f621-73ca-4c12-973c-0da732bc44c2' -and
                $KeyVaultTenantId -eq '72f988bf-86f1-41af-91ab-2d7cd011db47' -and
                $KeyVaultClientId -eq '11111111-2222-3333-4444-555555555555' -and
                $KeyVaultApiVersion -eq '7.5' -and
                $UserAgent -eq 'Custom-Agent/1.0' -and
                $SkipValidation
            }
        }
    }

    Describe 'Connect-M365PortalBySSO' {
        BeforeEach {
            Mock Connect-M365Portal {
                [pscustomobject]@{
                    Connected = $true
                }
            } -ModuleName M365Internals
        }

        It 'forwards SSO browser options to Connect-M365Portal' {
            $result = Connect-M365PortalBySSO -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2' -Visible -TimeoutSeconds 120 -BrowserPath 'msedge.exe' -ProfilePath 'C:\Temp\M365SsoProfile' -UserAgent 'Custom-Agent/1.0' -SkipValidation

            $result.Connected | Should -BeTrue
            Should -Invoke Connect-M365Portal -ModuleName M365Internals -Times 1 -Exactly -ParameterFilter {
                $SSO -and
                $TenantId -eq '8612f621-73ca-4c12-973c-0da732bc44c2' -and
                $Visible -and
                $TimeoutSeconds -eq 120 -and
                $BrowserPath -eq 'msedge.exe' -and
                $ProfilePath -eq 'C:\Temp\M365SsoProfile' -and
                $UserAgent -eq 'Custom-Agent/1.0' -and
                $SkipValidation
            }
        }
    }

    Describe 'Connect-M365PortalByTemporaryAccessPass' {
        BeforeEach {
            Mock Connect-M365Portal {
                [pscustomobject]@{
                    Connected = $true
                }
            } -ModuleName M365Internals
        }

        It 'forwards TAP inputs to Connect-M365Portal and leaves tenant resolution to the core flow' {
            $tap = New-TestSecureString -Value 'ABC12345'

            $result = Connect-M365PortalByTemporaryAccessPass -Username 'tap@contoso.com' -TemporaryAccessPass $tap -UserAgent 'Custom-Agent/1.0' -SkipValidation

            $result.Connected | Should -BeTrue
            Should -Invoke Connect-M365Portal -ModuleName M365Internals -Times 1 -Exactly -ParameterFilter {
                $Username -eq 'tap@contoso.com' -and
                $null -ne $TemporaryAccessPass -and
                $UserAgent -eq 'Custom-Agent/1.0' -and
                $SkipValidation -and
                -not $PSBoundParameters.ContainsKey('TenantId')
            }
        }
    }
}

InModuleScope M365Internals {
    Describe 'Connect-M365AuthArtifactSet' {
        BeforeEach {
            $script:portalWebSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $script:estsResolvedSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()

            Mock Invoke-WebRequest {
                [pscustomobject]@{
                    StatusCode = 200
                }
            }

            Mock Complete-M365AdminPortalSignIn {
                $script:estsResolvedSession
            }

            Mock Set-M365PortalConnectionSettings {
                if ($WebSession -eq $script:portalWebSession) {
                    return [pscustomobject]@{
                        ConnectedBy = 'Portal'
                        AuthFlow    = $AuthFlow
                    }
                }

                if ($WebSession -eq $script:estsResolvedSession) {
                    return [pscustomobject]@{
                        ConnectedBy = 'Ests'
                        AuthFlow    = $AuthFlow
                    }
                }

                throw 'Unexpected web session received by Set-M365PortalConnectionSettings.'
            }
        }

        It 'prefers portal bootstrap when requested and does not stamp TenantId onto the portal session path' {
            $result = Connect-M365AuthArtifactSet -EstsAuthCookieValue 'ests-cookie-value' -PortalWebSession $script:portalWebSession -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2' -UserAgent 'Custom-Agent/1.0' -ConnectionPreference PreferPortal -AuthFlow 'SSO' -SkipValidation -FailureLabel 'SSO authentication'

            $result.ConnectedBy | Should -Be 'Portal'
            $result.AuthFlow | Should -Be 'SSO'
            Assert-MockCalled Set-M365PortalConnectionSettings -Times 1 -ParameterFilter {
                $WebSession -eq $script:portalWebSession -and
                $AuthSource -eq 'WebSession' -and
                $AuthFlow -eq 'WebSession' -and
                $UserAgent -eq 'Custom-Agent/1.0' -and
                $SkipValidation
            }
            Assert-MockCalled Complete-M365AdminPortalSignIn -Times 0
        }

        It 'falls back to ESTS bootstrap when the preferred portal bootstrap fails' {
            Mock Set-M365PortalConnectionSettings {
                if ($WebSession -eq $script:portalWebSession) {
                    throw 'Portal bootstrap failed.'
                }

                if ($WebSession -eq $script:estsResolvedSession) {
                    return [pscustomobject]@{
                        ConnectedBy = 'Ests'
                        AuthFlow    = $AuthFlow
                    }
                }

                throw 'Unexpected web session received by Set-M365PortalConnectionSettings.'
            }

            $result = Connect-M365AuthArtifactSet -EstsAuthCookieValue 'ests-cookie-value' -PortalWebSession $script:portalWebSession -TenantId '8612f621-73ca-4c12-973c-0da732bc44c2' -UserAgent 'Custom-Agent/1.0' -ConnectionPreference PreferPortal -AuthFlow 'SSO' -FailureLabel 'SSO authentication'

            $result.ConnectedBy | Should -Be 'Ests'
            $result.AuthFlow | Should -Be 'SSO'
            Assert-MockCalled Complete-M365AdminPortalSignIn -Times 1 -ParameterFilter {
                $UserAgent -eq 'Custom-Agent/1.0'
            }
            Assert-MockCalled Set-M365PortalConnectionSettings -Times 1 -ParameterFilter {
                $WebSession -eq $script:portalWebSession -and $AuthSource -eq 'WebSession'
            }
            Assert-MockCalled Set-M365PortalConnectionSettings -Times 1 -ParameterFilter {
                $WebSession -eq $script:estsResolvedSession -and $AuthSource -eq 'ESTSAUTHPERSISTENT' -and $AuthFlow -eq 'EstsCookie'
            }
        }

        It 'falls back to the portal session when ESTS bootstrap fails and fallback is enabled' {
            Mock Complete-M365AdminPortalSignIn { throw 'ESTS bootstrap failed.' }

            $result = Connect-M365AuthArtifactSet -EstsAuthCookieValue 'ests-cookie-value' -PortalWebSession $script:portalWebSession -UserAgent 'Custom-Agent/1.0' -ConnectionPreference PreferEsts -FallbackToPortalOnEstsBootstrapFailure -AuthFlow 'BrowserSignIn' -FailureLabel 'Browser sign-in'

            $result.ConnectedBy | Should -Be 'Portal'
            $result.AuthFlow | Should -Be 'BrowserSignIn'
            Assert-MockCalled Complete-M365AdminPortalSignIn -Times 1 -ParameterFilter {
                $UserAgent -eq 'Custom-Agent/1.0'
            }
            Assert-MockCalled Set-M365PortalConnectionSettings -Times 1 -ParameterFilter {
                $WebSession -eq $script:portalWebSession -and $AuthSource -eq 'WebSession'
            }
            Assert-MockCalled Set-M365PortalConnectionSettings -Times 0 -ParameterFilter {
                $WebSession -eq $script:estsResolvedSession
            }
        }

        It 'uses ESTS bootstrap when only an ESTS cookie is available' {
            $result = Connect-M365AuthArtifactSet -EstsAuthCookieValue 'ests-cookie-value' -UserAgent 'Custom-Agent/1.0' -AuthFlow 'Credential' -FailureLabel 'Credential authentication'

            $result.ConnectedBy | Should -Be 'Ests'
            $result.AuthFlow | Should -Be 'Credential'
            Assert-MockCalled Complete-M365AdminPortalSignIn -Times 1 -ParameterFilter {
                $UserAgent -eq 'Custom-Agent/1.0'
            }
            Assert-MockCalled Set-M365PortalConnectionSettings -Times 1 -ParameterFilter {
                $WebSession -eq $script:estsResolvedSession -and $AuthSource -eq 'ESTSAUTHPERSISTENT' -and $AuthFlow -eq 'EstsCookie'
            }
        }

        It 'throws when no supported authentication artifacts are provided' {
            {
                Connect-M365AuthArtifactSet -FailureLabel 'Authentication'
            } | Should -Throw '*no supported authentication artifacts*'
        }
    }
}