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
}