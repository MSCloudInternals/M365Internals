Describe 'Public portal connection recovery' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../M365Internals/M365Internals.psd1"
        function New-RecoverySession([string]$Account) {
            $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $session.UserAgent = "fixture-$Account"
            $session.Headers['X-Fixture'] = $Account
            $cookies = @{
                RootAuthToken = "root-$Account"
                SPAAuthCookie = "spa-$Account"
                OIDCAuthCookie = "oidc-$Account"
                's.userid' = "$Account@example.test"
                's.SessID' = "session-$Account"
                's.UserTenantId' = '11111111-1111-1111-1111-111111111111'
                's.AjaxSessionKey' = "ajax-$Account"
                'x-portal-routekey' = "route-$Account"
                UserLoginRef = '%2Fhomepage'
            }
            foreach ($cookie in $cookies.GetEnumerator()) {
                $session.Cookies.Add([Net.Cookie]::new($cookie.Key, $cookie.Value, '/', 'admin.cloud.microsoft'))
            }
            $session
        }
    }

    BeforeEach {
        $alice = New-RecoverySession alice
        $bob = New-RecoverySession bob
        Mock Invoke-WebRequest -ModuleName M365Internals {
            throw "Unexpected fixture request: $Method $Uri"
        }
        Mock Invoke-WebRequest -ModuleName M365Internals -ParameterFilter {
            $Method -eq 'Get' -and ([uri]$Uri).AbsolutePath -eq '/admin/api/settings/company/copilotpolicy/pin'
        } {
            $username = $WebSession.Cookies.GetCookies([uri]'https://admin.cloud.microsoft/')['s.userid'].Value
            $policy = if ($username -eq 'alice@example.test') { 1 } else { 2 }
            @{
                StatusCode = 200
                Headers = @{ 'Content-Type' = 'application/json' }
                Content = @{ CopilotPinningPolicy = $policy; Owner = $username } | ConvertTo-Json -Compress
            }
        }
        Mock Invoke-RestMethod -ModuleName M365Internals { throw "Unexpected fixture request: $Method $Uri" }
        Mock Invoke-RestMethod -ModuleName M365Internals -ParameterFilter {
            $Method -eq 'Post' -and ([uri]$Uri).AbsolutePath -eq '/admin/api/settings/company/copilotpolicy/pin'
        } {
            @{ Success = $true }
        }
        $original = Connect-M365Portal -WebSession $alice -UserAgent fixture-alice -SkipValidation
        $original.Username | Should -Be 'alice@example.test'
    }

    It 'preserves Alice and her cached policy after a failed <Candidate> reconnect' -ForEach @(
        @{ Candidate = 'independent' }
        @{ Candidate = 'active-session' }
    ) {
        Mock Invoke-WebRequest -ModuleName M365Internals -ParameterFilter {
            ([uri]$Uri).AbsolutePath -eq '/adminportal/home/ClassicModernAdminDataStream'
        } {
            $WebSession.Cookies.Add([Net.Cookie]::new('s.userid', 'changed@example.test', '/', 'admin.cloud.microsoft'))
            $WebSession.Headers['X-Fixture'] = 'changed'
            throw [System.Net.Http.HttpRequestException]::new('Synthetic validation failure', $null, [Net.HttpStatusCode]::Forbidden)
        }

        (Get-M365AdminCopilotPinPolicy -Raw).Owner | Should -Be 'alice@example.test'
        $replacement = if ($Candidate -eq 'independent') { $bob } else { $alice }
        { Connect-M365Portal -WebSession $replacement -UserAgent 'candidate-agent' -ErrorAction Stop } |
            Should -Throw '*HTTP 403*'

        $cached = Get-M365AdminCopilotPinPolicy -Raw
        $cached.Owner | Should -Be 'alice@example.test'
        $cached.CopilotPinningPolicy | Should -Be 1
        Should -Invoke Invoke-WebRequest -ModuleName M365Internals -Exactly -Times 1 -ParameterFilter {
            ([uri]$Uri).AbsolutePath -eq '/admin/api/settings/company/copilotpolicy/pin'
        }
        $alice.UserAgent | Should -Be 'fixture-alice'
        $alice.Headers['X-Fixture'] | Should -Be 'alice'
        $alice.Cookies.GetCookies([uri]'https://admin.cloud.microsoft/')['s.userid'].Value | Should -Be 'alice@example.test'
        (Get-M365AdminCopilotPinPolicy -Raw -Force).Owner | Should -Be 'alice@example.test'
    }

    It 'keeps the cache during refresh and reads Bob data after a same-tenant account switch' {
        (Get-M365AdminCopilotPinPolicy -Raw).Owner | Should -Be 'alice@example.test'
        (Get-M365AdminCopilotPinPolicy -Raw).CopilotPinningPolicy | Should -Be 1
        Should -Invoke Invoke-WebRequest -ModuleName M365Internals -Exactly -Times 1

        $connection = Connect-M365Portal -WebSession $bob -SkipValidation
        $connection.TenantId | Should -Be $original.TenantId
        $connection.Username | Should -Be 'bob@example.test'
        $connection.SessionId | Should -Be 'session-bob'
        $policy = Get-M365AdminCopilotPinPolicy -Raw
        $policy.Owner | Should -Be 'bob@example.test'
        $policy.CopilotPinningPolicy | Should -Be 2
        Should -Invoke Invoke-WebRequest -ModuleName M365Internals -Exactly -Times 2
    }

    It 'stops before writing or reading back when the account switches after pin policy preflight' {
        $settings = @{ CopilotPinningPolicy = 0 }
        Mock Merge-M365AdminSettingsPayload -ModuleName M365Internals {
            $CurrentSettings.Owner | Should -Be 'alice@example.test'
            $null = Connect-M365Portal -WebSession $bob -SkipValidation
            $Settings
        }

        $failure = try {
            $null = Set-M365AdminCopilotPinPolicy -Settings $settings -PassThru -Confirm:$false -ErrorAction Stop
        }
        catch { $_ }
        Should -Invoke Invoke-RestMethod -ModuleName M365Internals -Exactly -Times 0
        Should -Invoke Invoke-WebRequest -ModuleName M365Internals -Exactly -Times 1 -ParameterFilter { $Method -eq 'Get' }
        $failure.Exception.Message | Should -BeLike '*connection changed*new invocation*'
        (Get-M365AdminCopilotPinPolicy -Raw).Owner | Should -Be 'bob@example.test'
    }

    It 'stops a connector update when the connection changes between its preflight reads' {
        Mock Get-M365AdminCopilotConnector -ModuleName M365Internals {
            if ($Name -eq 'Connections') {
                $null = Connect-M365Portal -WebSession $bob -SkipValidation
                return @{ connections = @(@{ connectionId = 'c1'; connectionName = 'Alice Connector' }) }
            }
            @{ LogicalId = 'all'; Payload = '{"Entities":[]}' }
        }
        { Set-M365AdminCopilotConnector -ConnectionId c1 -Enabled $false -PassThru -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*connection changed*new invocation*'
        Should -Invoke Get-M365AdminCopilotConnector -ModuleName M365Internals -Exactly -Times 1
        Should -Invoke Invoke-RestMethod -ModuleName M365Internals -Exactly -Times 0
    }

    It 'dispatches <Writes> writes with WhatIf set to <DryRun>' -ForEach @(
        @{ Writes = 1; DryRun = $false }
        @{ Writes = 0; DryRun = $true }
    ) {
        $null = Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = 0 } -WhatIf:$DryRun -Confirm:$false
        Should -Invoke Invoke-RestMethod -ModuleName M365Internals -Exactly -Times $Writes -ParameterFilter { $Method -eq 'Post' }
    }
}
