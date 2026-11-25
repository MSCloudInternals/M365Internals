Describe 'Get-M365AdminDevice' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            [pscustomobject]@{
                Id = 'device-1'
                DisplayName = 'Admin laptop'
                UserPrincipalName = 'admin@contoso.example'
                OperatingSystem = 'Windows'
                ComplianceState = 'Compliant'
                LastSyncDateTime = '2026-08-31T12:00:00Z'
                SupportsFactoryReset = $true
            }

            [pscustomobject]@{
                Id = 'device-2'
                DisplayName = 'Test tablet'
                OperatingSystem = 'iOS'
                ComplianceState = 'Noncompliant'
            }
        }
    }

    It 'returns pipeline-friendly typed records with original fields and payloads' {
        $result = @(Get-M365AdminDevice)

        $result | Should -HaveCount 2
        $result[0].PSObject.TypeNames | Should -Contain 'M365Admin.Device'
        $result[0].Endpoint | Should -Be '/admin/api/Intune/devices'
        $result[0].SupportsFactoryReset | Should -BeTrue
        $result[0].RawData.Id | Should -Be 'device-1'
        @($result | Where-Object ComplianceState -eq 'Noncompliant').Id | Should -Be 'device-2'
    }

    It 'forwards fresh-read and short cache settings to the shared portal helper' {
        $null = Get-M365AdminDevice -Force

        Should -Invoke Get-M365AdminPortalData -ModuleName M365Internals -Times 1 -Exactly -ParameterFilter {
            $Path -eq '/admin/api/Intune/devices' -and
            $CacheKey -eq 'M365AdminDevice:Devices' -and
            $CacheMinutes -eq 5 -and $Force
        }
    }

    It 'returns original records in raw mode' {
        $result = @(Get-M365AdminDevice -Raw)

        $result | Should -HaveCount 2
        $result[0].Id | Should -Be 'device-1'
        $result[0].PSObject.Properties.Name | Should -Not -Contain 'RawData'
        $result[0].PSObject.TypeNames | Should -Not -Contain 'M365Admin.Device'
    }

    It 'returns JSON arrays for multiple devices' {
        $json = Get-M365AdminDevice -RawJson

        $json.TrimStart() | Should -Match '^\['
        @($json | ConvertFrom-Json) | Should -HaveCount 2
    }

    It 'preserves singleton JSON arrays and RawJson precedence' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData { [pscustomobject]@{ Id = 'only-device' } }

        $json = Get-M365AdminDevice -Raw -RawJson

        $json.TrimStart() | Should -Match '^\['
        @($json | ConvertFrom-Json).Id | Should -Be 'only-device'
    }

    It 'returns no records and an empty JSON array for an empty inventory' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData { @() }

        @(Get-M365AdminDevice) | Should -HaveCount 0
        @(Get-M365AdminDevice -Raw) | Should -HaveCount 0
        Get-M365AdminDevice -RawJson | Should -Be '[]'
    }

    It 'does not hide authentication or permission failures as empty inventory' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData { throw '403 Forbidden' }

        { Get-M365AdminDevice } | Should -Throw '*403 Forbidden*'
    }
}

InModuleScope M365Internals {
    Describe 'device inventory cache integration' {
        BeforeAll {
            $originalCache = $script:m365CacheStore
            $originalConnection = $script:m365PortalConnection
        }

        AfterAll {
            $script:m365CacheStore = $originalCache
            $script:m365PortalConnection = $originalConnection
        }

        BeforeEach {
            $script:m365CacheStore = @{}
            $script:m365PortalConnection = [pscustomobject]@{ TenantId = '11111111-1111-1111-1111-111111111111' }
            Mock Update-M365PortalConnectionSettings {}
            Mock Invoke-M365PortalRequest {
                '[{"Id":"device-1","OperatingSystem":"Windows","SupportsFactoryReset":false}]' | ConvertFrom-Json
            }
        }

        It 'reuses cached inventory and refreshes on Force' {
            $fresh = @(Get-M365AdminDevice -Force)
            $cached = @(Get-M365AdminDevice)
            $null = Get-M365AdminDevice -Force

            $fresh[0].Id | Should -Be 'device-1'
            $fresh[0].SupportsFactoryReset | Should -BeFalse
            $cached[0].Id | Should -Be $fresh[0].Id
            Should -Invoke Invoke-M365PortalRequest -Times 2 -Exactly
        }

        It 'does not reuse device inventory across tenants' {
            $null = Get-M365AdminDevice
            $script:m365PortalConnection.TenantId = '22222222-2222-2222-2222-222222222222'
            $null = Get-M365AdminDevice

            Should -Invoke Invoke-M365PortalRequest -Times 2 -Exactly
        }
    }
}
