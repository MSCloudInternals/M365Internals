Describe 'typed output contract coverage' {
    It 'ensures public getters using Resolve-M365AdminOutput also use typed output helpers' {
        $moduleRoot = (Resolve-Path (Join-Path (Join-Path $global:testroot '..') 'M365Internals')).Path
        $publicFunctionPath = Join-Path $moduleRoot 'functions'
        $outliers = foreach ($file in Get-ChildItem -Path $publicFunctionPath -Filter '*.ps1' -File) {
            $content = Get-Content -Path $file.FullName -Raw
            if ($content -match 'Resolve-M365AdminOutput' -and $content -notmatch 'Add-M365TypeName|ConvertTo-M365AdminResult|New-M365AdminResultBundle') {
                $file.BaseName
            }

        }

        @($outliers) | Should -BeNullOrEmpty
    }
}

InModuleScope M365Internals {
    Describe 'JSON scalar output contracts' {
        It 'retains wrapped JSON scalars under Value' -TestCases @(
            @{ Json = '0'; Expected = 0 }
            @{ Json = '42'; Expected = 42 }
            @{ Json = 'false'; Expected = $false }
            @{ Json = 'true'; Expected = $true }
            @{ Json = '"ready"'; Expected = 'ready' }
        ) {
            param($Json, $Expected)

            $inputValue = $Json | ConvertFrom-Json
            $result = ConvertTo-M365AdminResult -InputObject $inputValue -TypeName 'M365Admin.TestScalar' -Category 'Test' -ItemName 'Scalar'

            $result.PSObject.Properties.Name | Should -Contain 'Value'
            $result.Value | Should -Be $Expected
            $result.RawData | Should -Be $Expected
        }

        It 'still merges JSON objects and preserves empty objects as raw data' {
            $result = ConvertTo-M365AdminResult -InputObject ('{"Enabled":false}' | ConvertFrom-Json) -TypeName 'M365Admin.TestScalar' -Category 'Test' -ItemName 'Object'
            $empty = ConvertTo-M365AdminResult -InputObject ('{}' | ConvertFrom-Json) -TypeName 'M365Admin.TestScalar' -Category 'Test' -ItemName 'Object'

            $result.Enabled | Should -BeFalse
            $result.RawData.Enabled | Should -BeFalse
            ($null -eq $empty.RawData) | Should -BeFalse
            $empty.RawData.GetType().FullName | Should -Be 'System.Management.Automation.PSCustomObject'
            $empty.PSObject.Properties.Name | Should -Not -Contain 'Value'
        }
    }
}