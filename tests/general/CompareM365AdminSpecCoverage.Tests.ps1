Describe 'Compare M365 admin spec coverage' {
    BeforeAll {
        if ($global:testroot) {
            $repoRoot = (Resolve-Path (Join-Path $global:testroot '..')).Path
        }
        else {
            $repoRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
        }
        . (Join-Path (Join-Path $repoRoot 'build') 'Compare-M365AdminSpecCoverage.ps1')
        $specRoot = Join-Path (Join-Path (Join-Path $repoRoot 'tests') 'fixtures') 'm365-admin-spec-sample'
        $artifactRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("M365Internals-SpecCoverage-" + [Guid]::NewGuid().Guid)
        $comparison = Compare-M365AdminSpecCoverage -RepositoryRoot $repoRoot -SpecRoot $specRoot -OutputDirectory $artifactRoot
    }

    AfterAll {
        if ($artifactRoot -and (Test-Path -LiteralPath $artifactRoot)) {
            Remove-Item -LiteralPath $artifactRoot -Recurse -Force
        }
    }

    It 'parses canonical path aliases from the nodoc spec' {
        $officeOnTheWeb = $comparison.SpecOperations | Where-Object OperationId -eq 'AppSettings.GetOfficeOnTheWeb'

        $officeOnTheWeb.PathTemplate | Should -Be '/admin/api/settings/apps/officeontheweb'
        $officeOnTheWeb.EffectivePathTemplate | Should -Be '/admin/api/settings/apps/officeonline'
    }

    It 'keeps non-aliased operations on their original paths' {
        $loop = $comparison.SpecOperations | Where-Object OperationId -eq 'AppSettings.GetMicrosoftLoop'

        $loop.PathTemplate | Should -Be '/admin/api/settings/apps/MicrosoftLoop'
        $loop.EffectivePathTemplate | Should -Be '/admin/api/settings/apps/MicrosoftLoop'
        $loop.PendingSchema | Should -BeTrue
    }

    It 'treats canonical aliases as covered by the current registry' {
        $officeOnTheWeb = $comparison.Details | Where-Object OperationId -eq 'AppSettings.GetOfficeOnTheWeb'

        $officeOnTheWeb.CoverageStatus | Should -Be 'CoveredByRegistry'
        $officeOnTheWeb.RegistrySources | Should -Contain 'PlaywrightPlan:OfficeOnline:Get'
    }

    It 'surfaces unmapped operations as missing from registry and code' {
        $billingModel = $comparison.Details | Where-Object OperationId -eq 'Billing.GetBillingModel'

        $billingModel.CoverageStatus | Should -Be 'MissingFromRegistryAndCode'
        $comparison.HighConfidenceMissing.OperationId | Should -Contain 'Billing.GetBillingModel'
    }

    It 'writes JSON artifacts for the coverage report' {
        Test-Path -LiteralPath (Join-Path $artifactRoot 'm365-admin-spec-coverage-summary.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $artifactRoot 'm365-admin-spec-coverage-details.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $artifactRoot 'm365-admin-spec-coverage-high-confidence.json') | Should -BeTrue
    }
}

