Describe 'Get-M365AdminCommandCatalog' {
    It 'returns flattened catalog entries by default' {
        $result = Get-M365AdminCommandCatalog

        $catalogEntry = $result | Where-Object Cmdlet -eq 'Get-M365AdminCommandCatalog'
        $catalogEntry | Should -Not -BeNullOrEmpty
        $catalogEntry.PSObject.TypeNames | Should -Contain 'M365Admin.CommandCatalog.Entry'
        $catalogEntry.GroupKey | Should -Be 'PlatformAndUtilities'

        ($result | Where-Object Cmdlet -eq 'Set-M365AdminCompanySetting').GroupKey | Should -Be 'WriteOperations'
    }

    It 'returns grouped catalog sections in raw mode' {
        $result = Get-M365AdminCommandCatalog -Group OrgSettingsAndWorkloads -Raw

        $result | Should -HaveCount 1
        $result[0].PSObject.TypeNames | Should -Contain 'M365Admin.CommandCatalog.Group'
        $result[0].GroupKey | Should -Be 'OrgSettingsAndWorkloads'
        $result[0].Cmdlets.Cmdlet | Should -Contain 'Get-M365AdminAppSetting'
    }

    It 'discovers supported Name values and WhatIf without a portal session' {
        $entry = Get-M365AdminCommandCatalog -CmdletName Get-M365AdminUserSetting

        $entry.NameValues | Should -Contain 'UnlicensedUsersCount'
        $entry.NameValues | Should -Contain 'All'
        $entry.SupportsWhatIf | Should -BeFalse
        (Get-M365AdminCommandCatalog -CmdletName Set-M365AdminCompanySetting).SupportsWhatIf | Should -BeTrue
    }

    It 'returns empty Name values for commands without a Name selector' {
        $entry = Get-M365AdminCommandCatalog -CmdletName Get-M365AdminDevice

        $entry.NameValues | Should -HaveCount 0
        $entry.GroupKey | Should -Be 'TenantUsersAndRelationships'
        $entry.SupportsForce | Should -BeTrue
        $entry.SupportsRawOutput | Should -BeTrue
    }

    It 'preserves discovery metadata in grouped JSON output and wildcard filtering' {
        $groups = Get-M365AdminCommandCatalog -CmdletName '*UserSetting' -RawJson | ConvertFrom-Json

        @($groups.Cmdlets) | Should -HaveCount 1
        $groups.Cmdlets.NameValues | Should -Contain 'UnlicensedUsersCount'
        $groups.Cmdlets.SupportsWhatIf | Should -BeFalse
    }
}