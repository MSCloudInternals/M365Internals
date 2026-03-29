# Run internal pester tests
$repositoryRoot = Join-Path $PSScriptRoot '..'
$testScriptPath = Join-Path (Join-Path $repositoryRoot 'tests') 'pester.ps1'
& $testScriptPath
