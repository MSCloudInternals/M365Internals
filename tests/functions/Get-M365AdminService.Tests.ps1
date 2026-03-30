Describe 'Get-M365AdminService' {
    It 'passes Raw through to delegated service cmdlets' {
        Mock -ModuleName M365Internals Get-M365AdminMicrosoft365GroupSetting {
            [pscustomobject]@{
                Value = 'raw-group-result'
            }
        }

        $result = Get-M365AdminService -Name Microsoft365Groups -Raw

        $result.Value | Should -Be 'raw-group-result'

        Assert-MockCalled Get-M365AdminMicrosoft365GroupSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Raw.IsPresent -and -not $RawJson.IsPresent -and -not $Force.IsPresent
        }
    }

    It 'passes RawJson through to delegated service cmdlets' {
        Mock -ModuleName M365Internals Get-M365AdminPeopleSetting {
            '{"People":"RawJson"}'
        }

        $result = Get-M365AdminService -Name PeopleSettings -RawJson

        $result | Should -Be '{"People":"RawJson"}'

        Assert-MockCalled Get-M365AdminPeopleSetting -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            -not $Raw.IsPresent -and $RawJson.IsPresent -and -not $Force.IsPresent
        }
    }

    It 'serializes informational-only service results when RawJson is used' {
        $result = Get-M365AdminService -Name Sales -RawJson

        $result | Should -BeOfType ([string])
        $result | Should -Match '"Name"\s*:\s*"Sales"'
        $result | Should -Match '"Reason"\s*:\s*"Informational"'
        $result | Should -Match '"Status"\s*:\s*"Unavailable"'
    }

    It 'normalizes legacy alias names to the canonical service cache key and type name' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            [pscustomobject]@{
                Enabled = $true
            }
        }

        $result = Get-M365AdminService -Name MicrosoftToDo

        $result.PSObject.TypeNames[0] | Should -Be 'M365Admin.Service.Todo'

        Assert-MockCalled Get-M365AdminPortalData -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq '/admin/api/services/apps/todo' -and $CacheKey -eq 'M365AdminService:Todo'
        }
    }
}