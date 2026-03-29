param (
    [string]
    $Repository = 'PSGallery'
)

$repositoryRoot = Join-Path $PSScriptRoot '..'
$moduleRoot = Join-Path $repositoryRoot 'M365Internals'

# List of required modules
$modules = @("Pester", "PSScriptAnalyzer")

# Automatically add missing dependencies
$data = Import-PowerShellDataFile -Path (Join-Path $moduleRoot 'M365Internals.psd1')
foreach ($dependency in $data.RequiredModules) {
    if ($dependency -is [string]) {
        if ($modules -contains $dependency) { continue }
        $modules += $dependency
    } else {
        if ($modules -contains $dependency.ModuleName) { continue }
        $modules += $dependency.ModuleName
    }
}

foreach ($module in $modules) {
    $availableModule = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1

    if (-not $availableModule) {
        Write-Host "Installing missing module $module" -ForegroundColor Cyan
        Install-Module $module -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck -Repository $Repository
    } else {
        Write-Host "Using available module $($availableModule.Name) $($availableModule.Version)" -ForegroundColor Cyan
    }

    Import-Module $module -Force -PassThru | Out-Null
}
