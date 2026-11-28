Describe 'M365 portal diagnostic policy' {
    It 'explicitly suppresses raw diagnostics at every stock web transport and Az token call' {
        $moduleRoot = Join-Path $PSScriptRoot '../../M365Internals'
        $violations = foreach ($file in Get-ChildItem -Path $moduleRoot -Recurse -File -Include '*.ps1','*.psm1') {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $null, [ref] $null)
            $calls = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -match '(?i)(?:^|\\)(?:Invoke-RestMethod|Invoke-WebRequest|irm|iwr|Get-AzAccessToken)$'
            }, $true)
            foreach ($call in $calls) {
                foreach ($setting in @('Debug', 'Verbose')) {
                    $parameter = @($call.CommandElements | Where-Object {
                        $_ -is [System.Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -eq $setting
                    })
                    if ($parameter.Count -ne 1 -or $parameter[0].Argument.Extent.Text -ne '$false') {
                        '{0}:{1} missing explicit -{2}:$false' -f $file.Name,$call.Extent.StartLineNumber,$setting
                    }
                }
            }
        }
        $violations | Should -BeNullOrEmpty
    }
}

InModuleScope M365Internals {
    Describe 'Safe portal diagnostics' {
        BeforeEach {
            $originalSession = $script:m365PortalSession
            $originalHeaders = $script:m365PortalHeaders
            $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $script:m365PortalHeaders = @{ AjaxSessionKey = 'synthetic-ajax-canary'; 'x-portal-routekey' = 'synthetic-route-canary' }
            Mock Update-M365PortalConnectionSettings { }
        }

        AfterEach {
            $script:m365PortalSession = $originalSession
            $script:m365PortalHeaders = $originalHeaders
        }

        It 'retains a safe status for REST failures without URL, header, body or provider text' {
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('synthetic-provider-canary', $response)
            }

            try {
                Invoke-M365AdminRestMethod -Uri 'https://admin.cloud.microsoft/?q=synthetic-query-canary' -Method Post -Body @{ data = 'synthetic-body-canary' } -Debug -Verbose -ErrorAction Stop | Out-Null
                throw 'Expected transport to fail.'
            }
            catch {
                $_.Exception.Message | Should -Be 'Failed to invoke M365 REST method (Post). HTTP 403 (Forbidden).'
                ($_ | Out-String) | Should -Not -Match 'synthetic-(provider|query|body|ajax|route)-canary'
            }
        }

        It 'formats a non-HTTP failure in strict scope without arbitrary message text' {
            $result = & {
                Set-StrictMode -Version Latest
                Get-M365SafeFailureDetail -Message 'synthetic-provider-canary'
            }

            $result | Should -Be 'No HTTP status was available.'
        }

        It 'does not echo the cache key in a cache-hit diagnostic' {
            Mock Get-M365Cache {
                [pscustomobject]@{ NotValidAfter = (Get-Date).AddMinutes(5); Value = [pscustomobject]@{ Cached = $true } }
            }
            $records = @(Get-M365AdminPortalData -Path '/test' -CacheKey 'synthetic-cache-canary' -Verbose 4>&1)

            ($records | Where-Object Cached).Cached | Should -BeTrue
            ($records | Out-String) | Should -Match 'Using cached Microsoft 365 admin portal data'
            ($records | Out-String) | Should -Not -Match 'synthetic-cache-canary'
        }

        It 'retains the classification of unavailable responses without returning arbitrary provider text' {
            $result = New-M365AdminUnavailableResultFromError -Name 'Test' -Area 'settings' -ErrorMessage 'HTTP 429 https://example.invalid/?data=synthetic-query-canary'
            $result.HttpStatusCode | Should -Be 429
            $result.Reason | Should -Be 'Throttled'
            $result.Error | Should -Be 'HTTP 429 (TooManyRequests).'
            $result.SuggestedAction | Should -Match 'retry'
        }

        It 'does not rewrite the deliberately requested raw response' {
            Mock Invoke-WebRequest {
                [pscustomobject]@{ Content = 'synthetic-body-canary'; Headers = @{ 'Content-Type' = 'text/plain' } }
            }

            $result = Invoke-M365PortalRequest -Uri 'https://example.invalid/' -RawResponse -SkipConnectionRefresh -SkipAutoHeal -Debug -Verbose
            $result.Content | Should -Be 'synthetic-body-canary'
        }

        It 'preserves the Graph bearer request and returns its data without adding diagnostics' {
            Mock Get-M365AdminAccessToken { [pscustomobject]@{ Token = 'synthetic-bearer-canary'; TenantId = $null } }
            Mock Invoke-RestMethod {
                if ($Headers.Authorization -ne 'Bearer synthetic-bearer-canary' -or $Headers.AjaxSessionKey -ne 'synthetic-ajax-canary') {
                    throw 'Expected the original synthetic request headers.'
                }
                [pscustomobject]@{ Value = 42 }
            }

            $result = Invoke-M365AdminGraphRequest -Uri 'https://example.invalid/' -AdminAppRequest '/homepage' -IncludeAuthorizationHeader -Debug -Verbose
            $result.Value | Should -Be 42
        }

        It 'sanitizes a direct credential-provider transport failure at the public boundary' {
            Mock Invoke-M365CredentialAuthentication {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Unauthorized)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('synthetic-provider-canary', $response)
            }

            $dummyPassword = ConvertTo-SecureString 'synthetic-password' -AsPlainText -Force
            $credential = [pscredential]::new('unit-test@example.invalid', $dummyPassword)
            try {
                Connect-M365Portal -Credential $credential -Debug -Verbose -ErrorAction Stop | Out-Null
                throw 'Expected the mocked provider to fail.'
            }
            catch {
                $_.Exception.Message | Should -Be 'Microsoft 365 portal sign-in request failed. HTTP 401 (Unauthorized).'
                ($_ | Out-String) | Should -Not -Match 'synthetic-(provider-canary|password)'
            }
        }

        It 'uses numeric HTTP <Status> through the real app-setting wrappers' -TestCases @(
            @{ Status = 400; Phrase = 'BadRequest' }
            @{ Status = 404; Phrase = 'NotFound' }
        ) {
            param($Status, $Phrase)
            Mock Get-M365Cache { }
            Mock Clear-M365Cache { }
            Mock Invoke-WebRequest {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$Status)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('synthetic-provider-canary', $response)
            }

            $result = Get-M365AdminAppSetting -Name OfficeScripts -Force -ErrorAction Stop

            $result.DataBacked | Should -BeFalse
            $result.HttpStatusCode | Should -Be $Status
            $result.Reason | Should -Be 'ProvisioningOrLicensing'
            $result.Error | Should -Be "HTTP $Status ($Phrase)."
        }

        It 'does not broaden app-setting fallback to a transport authorization failure' {
            Mock Get-M365Cache { }
            Mock Clear-M365Cache { }
            Mock Invoke-WebRequest {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('synthetic-provider-canary', $response)
            }

            { Get-M365AdminAppSetting -Name OfficeScripts -Force -ErrorAction Stop } | Should -Throw '*HTTP 403 (Forbidden).*'
        }

        It 'does not interpret an incidental number as an unavailable app-setting status' {
            Mock Get-M365AdminPortalData { throw 'Synthetic configuration item 404 could not be parsed.' }

            { Get-M365AdminAppSetting -Name OfficeScripts -Force -ErrorAction Stop } | Should -Throw '*configuration item 404*'
        }

        It 'keeps only the allowed browser origin in the shared Browser and SSO diagnostic context' {
            Mock Get-M365BrowserTargetList {
                [pscustomobject]@{
                    type = 'page'
                    url = 'https://login.microsoftonline.com/synthetic-path?field=synthetic-query#synthetic-fragment'
                    title = 'synthetic-title'
                    webSocketDebuggerUrl = 'ws://127.0.0.1:1/devtools'
                }
            }

            $context = Get-M365BrowserPreferredTargetContext -Port 1
            $context.Description | Should -Be 'https://login.microsoftonline.com'
            $context.PSObject.Properties.Name | Should -Not -Contain 'Title'
            $context.PSObject.Properties.Name | Should -Not -Contain 'Url'
            $context.WebSocketUrl | Should -Be 'ws://127.0.0.1:1/devtools'
        }

        It 'omits unsupported browser origins and callback data' -TestCases @(
            @{ CandidateUrl = 'https://synthetic-host.example.invalid/?field=synthetic-query' }
            @{ CandidateUrl = 'https://login.microsoftonline.com.example.invalid/?field=synthetic-query' }
            @{ CandidateUrl = 'https://synthetic-user@login.microsoftonline.com/?field=synthetic-query' }
            @{ CandidateUrl = 'https://login.microsoftonline.com:444/?field=synthetic-query' }
            @{ CandidateUrl = 'msauth://synthetic-host/synthetic-path?field=synthetic-query' }
            @{ CandidateUrl = 'http://login.microsoftonline.com/?field=synthetic-query' }
        ) {
            param($CandidateUrl)
            Format-M365BrowserTargetDescription -Url $CandidateUrl | Should -Be 'unrecognized origin'
        }

        It 'retains safe handoff context without leaking the provider response URL or title' {
            Mock Invoke-WebRequest {
                if ($Uri -like 'https://admin.cloud.microsoft/login*') {
                    return [pscustomobject]@{ Headers = @{ Location = 'https://login.microsoftonline.com/common/oauth2/authorize?probe=synthetic-query-canary' }; Content = ''; BaseResponse = [pscustomobject]@{} }
                }

                [pscustomobject]@{
                    Content = '<html><title>synthetic-title-canary</title><script>$Config = {"pgid":"Unexpected","sErrorCode":"50058"};</script></html>'
                    BaseResponse = [pscustomobject]@{ ResponseUri = [uri]'https://login.microsoftonline.com/common/oauth2/authorize?probe=synthetic-query-canary' }
                }
            }

            try {
                Complete-M365AdminPortalSignIn -WebSession $script:m365PortalSession -UserAgent 'Unit test' -Debug -Verbose -ErrorAction Stop | Out-Null
                throw 'Expected incomplete sign-in handoff to fail.'
            }
            catch {
                $_.Exception.Message | Should -Match 'Missing response fields'
                $_.Exception.Message | Should -Match 'Service error code: 50058'
                ($_ | Out-String) | Should -Not -Match 'synthetic-(query|title)-canary'
            }
        }
    }
}
