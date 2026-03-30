Describe 'Get-M365AdminDomain' {
    It 'returns a standardized unavailable result for dependency lookups that fail with a tenant-specific bad request' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            throw 'Response status code does not indicate success: 400 (Bad Request).'
        } -ParameterFilter {
            $Path -like '/admin/api/Domains/Dependencies*'
        }

        $result = Get-M365AdminDomain -Dependencies -DomainName 'contoso.com' -DependencyKind 2

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.UnavailableResult'
        $result.Name | Should -Be 'Dependencies'
        $result.Reason | Should -Be 'TenantSpecific'
        $result.DomainName | Should -Be 'contoso.com'
        $result.DependencyKind | Should -Be 2
    }

    It 'returns dependency unavailable results as JSON when RawJson is used' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            throw 'Response status code does not indicate success: 400 (Bad Request).'
        } -ParameterFilter {
            $Path -like '/admin/api/Domains/Dependencies*'
        }

        $result = Get-M365AdminDomain -Dependencies -DomainName 'contoso.com' -DependencyKind 4 -RawJson

        $result | Should -BeOfType ([string])
        $result | Should -Match '"Name"\s*:\s*"Dependencies"'
        $result | Should -Match '"DomainName"\s*:\s*"contoso.com"'
        $result | Should -Match '"DependencyKind"\s*:\s*4'
        $result | Should -Match '"Reason"\s*:\s*"TenantSpecific"'
    }
}