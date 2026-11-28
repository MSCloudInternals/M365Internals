InModuleScope M365Internals {
    Describe 'SSO private profile selection' -Skip:(-not $IsWindows) {
        BeforeEach {
            $script:preparedProfile = $null
            Mock Resolve-M365BrowserPath { [pscustomobject]@{ Name = 'Edge'; Path = 'edge.exe' } }
            Mock Initialize-M365SsoProfile { $script:preparedProfile = $ProfilePath }
            Mock Get-M365BrowserFreeTcpPort { 9222 }
            Mock Get-M365BrowserPrivateModeArgument { '--inprivate' }
            Mock Start-M365SsoBrowserProcess {
                Test-Path -LiteralPath $script:preparedProfile -PathType Container | Should -BeTrue
                $ArgumentList | Should -Contain "--user-data-dir=$script:preparedProfile"
                $ArgumentList | Should -Contain '--inprivate'
                throw 'Synthetic launch failure'
            }
            Mock Start-Sleep {}
        }

        It 'uses and cleans up a temporary profile through <EntryPoint>' -TestCases @(
            @{ EntryPoint = 'wrapper' }
            @{ EntryPoint = 'core' }
        ) {
            param($EntryPoint)
            if ($EntryPoint -eq 'wrapper') {
                { Connect-M365PortalBySSO -PrivateSession -SkipValidation } | Should -Throw '*Synthetic launch failure*'
            }
            else {
                { Connect-M365Portal -SSO -PrivateSession -SkipValidation } | Should -Throw '*Synthetic launch failure*'
            }
            $script:preparedProfile | Should -Not -BeNullOrEmpty
            $script:preparedProfile | Should -Not -Be (Get-M365SsoDefaultProfilePath)
            Test-Path -LiteralPath $script:preparedProfile | Should -BeFalse
        }

        It 'rejects a caller-supplied profile path in private mode' {
            { Connect-M365PortalBySSO -PrivateSession -ProfilePath 'C:\Example\Profile' -SkipValidation } |
                Should -Throw '*Do not combine -PrivateSession with -ProfilePath*'
            Should -Invoke Start-M365SsoBrowserProcess -Times 0 -Exactly
        }

        It 'cleans up a temporary profile when initialization fails' {
            Mock Initialize-M365SsoProfile {
                $script:preparedProfile = $ProfilePath
                throw 'Synthetic initialization failure'
            }
            { Connect-M365PortalBySSO -PrivateSession -SkipValidation } | Should -Throw '*Synthetic initialization failure*'
            $script:preparedProfile | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath $script:preparedProfile | Should -BeFalse
        }

        It 'continues to select the persistent SSO default for ordinary sessions' {
            Mock Resolve-M365BrowserProfileConfiguration { throw 'Synthetic resolver stop' }
            { Connect-M365PortalBySSO -SkipValidation } | Should -Throw '*Synthetic resolver stop*'
            Should -Invoke Resolve-M365BrowserProfileConfiguration -Times 1 -Exactly -ParameterFilter {
                $ProfilePath -eq (Get-M365SsoDefaultProfilePath) -and -not $PrivateSession
            }
        }
    }
}
