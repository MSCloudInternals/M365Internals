param (
    [string]
    $Repository = 'PSGallery'
)

# Skip if running in GitHub Actions to avoid conflicts
if ($env:GITHUB_ACTIONS -eq 'true') {
    Write-Host "Skipping prerequisite installation in GitHub Actions environment." -ForegroundColor Yellow
    return
}

# List of required modules
$modules = @("Pester", "PSScriptAnalyzer")

# Automatically add missing dependencies
$data = Import-PowerShellDataFile -Path "$PSScriptRoot\..\M365Internals\M365Internals.psd1"
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
    Write-Host "Installing $module" -ForegroundColor Cyan
    Install-Module $module -Force -SkipPublisherCheck -Repository $Repository
    Import-Module $module -Force -PassThru
}