InModuleScope M365Internals {
    Describe 'admin setters with a failing REST transport' {
        BeforeEach {
            $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $script:m365PortalHeaders = @{}
            Mock Update-M365PortalConnectionSettings {}
            Mock Invoke-RestMethod { throw 'Synthetic transport failure' }
            Mock Get-M365AdminCopilotPinPolicy { [pscustomobject]@{ CopilotPinningPolicy = 1 } }
            Mock Get-M365AdminUserOwnedAppSetting { [pscustomobject]@{ StoreAccess = $true } }
            Mock Get-M365PortalTenantId { 'tenant' }
            Mock Clear-M365Cache {}
        }

        AfterEach {
            $script:m365PortalSession = $null
            $script:m365PortalHeaders = $null
        }

        It 'stops pin policy processing with <Preference>' -TestCases @(
            @{ Preference = 'Stop' }
            @{ Preference = 'SilentlyContinue' }
        ) {
            param($Preference)
            $result = $null
            $failure = $null
            try {
                $result = Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = 0 } -PassThru -Confirm:$false -ErrorAction $Preference
            }
            catch { $failure = $_ }
            $result | Should -BeNullOrEmpty
            $failure.Exception.Message | Should -Match 'write outcome is unconfirmed.*No HTTP status was available'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            Should -Invoke Clear-M365Cache -Times 0 -Exactly
            Should -Invoke Get-M365AdminCopilotPinPolicy -Times 1 -Exactly
        }

        It 'stops further user-owned app writes with <Preference>' -TestCases @(
            @{ Preference = 'Stop' }
            @{ Preference = 'SilentlyContinue' }
        ) {
            param($Preference)
            $result = $null
            $failure = $null
            try {
                $result = Set-M365AdminUserOwnedAppSetting -LetUsersAccessOfficeStore $true -LetUsersStartTrials $true -PassThru -Confirm:$false -ErrorAction $Preference
            }
            catch { $failure = $_ }
            $result | Should -BeNullOrEmpty
            $failure.Exception.Message | Should -Match 'write outcome is unconfirmed.*No HTTP status was available'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            Should -Invoke Clear-M365Cache -Times 0 -Exactly
            Should -Invoke Get-M365AdminUserOwnedAppSetting -Times 0 -Exactly
        }

        It 'reports a partial update and clears the cache after a later transport failure with <Preference>' -TestCases @(
            @{ Preference = 'Stop' }
            @{ Preference = 'SilentlyContinue' }
        ) {
            param($Preference)
            $script:transportCalls = 0
            Mock Invoke-RestMethod {
                $script:transportCalls++
                if ($script:transportCalls -eq 2) { throw 'Synthetic transport failure' }
                return [pscustomobject]@{ ok = $true }
            }
            $result = $null
            $failure = $null
            try {
                $result = Set-M365AdminUserOwnedAppSetting -LetUsersAccessOfficeStore $true -LetUsersStartTrials $true -LetUsersAutoClaimLicenses $true -PassThru -Confirm:$false -ErrorAction $Preference
            }
            catch { $failure = $_ }
            $result | Should -BeNullOrEmpty
            $failure.Exception.Message | Should -Match 'earlier update succeeded.*write outcome is unconfirmed'
            Should -Invoke Invoke-RestMethod -Times 2 -Exactly
            Should -Invoke Clear-M365Cache -Times 1 -Exactly
            Should -Invoke Get-M365AdminUserOwnedAppSetting -Times 0 -Exactly
        }

        It 'does not clear cache or read back after a redirected pin-policy write' {
            Mock Invoke-RestMethod {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Found)
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Redirect refused', $response)
            }
            { Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = 0 } -PassThru -Confirm:$false } |
                Should -Throw '*write outcome is unconfirmed*'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            Should -Invoke Clear-M365Cache -Times 0 -Exactly
            Should -Invoke Get-M365AdminCopilotPinPolicy -Times 1 -Exactly
        }
    }
}
