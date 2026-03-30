# Run the standard maintainer validation workflow used by CI.
$repositoryRoot = Join-Path $PSScriptRoot '..'
$validationScriptPath = Join-Path $PSScriptRoot 'run-maintainer-validation.ps1'
& $validationScriptPath -PesterOutput None
