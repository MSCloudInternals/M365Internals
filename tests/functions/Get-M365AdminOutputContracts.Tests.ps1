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