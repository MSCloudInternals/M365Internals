param (
    [Parameter()]
    [string]$ModuleOutputPath,

    [Parameter()]
    [string]$BrowserPlanPath,

    [Parameter()]
    [string]$BrowserOutputPath
)

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
if ([string]::IsNullOrWhiteSpace($ModuleOutputPath)) {
    $ModuleOutputPath = Join-Path $artifactRoot 'module-settings-surface-captures.json'
}

if ([string]::IsNullOrWhiteSpace($BrowserPlanPath)) {
    $BrowserPlanPath = Join-Path $artifactRoot 'settings-browser-capture-plan.json'
}

if ([string]::IsNullOrWhiteSpace($BrowserOutputPath)) {
    $BrowserOutputPath = Join-Path $artifactRoot 'browser-settings-surface-captures.json'
}

$previousPlanPath = $env:M365_BROWSER_CAPTURE_PLAN

try {
    & (Join-Path $PSScriptRoot 'export-settings-surface-captures.ps1') -OutputPath $ModuleOutputPath -BrowserPlanPath $BrowserPlanPath | Out-Null

    $env:M365_BROWSER_CAPTURE_PLAN = $BrowserPlanPath

    & (Join-Path $PSScriptRoot 'run-edge-browser-capture.ps1') -SpecPath (Join-Path $PSScriptRoot 'capture-settings-browser-endpoints.spec.js') -OutputPath $BrowserOutputPath
}
finally {
    if ([string]::IsNullOrWhiteSpace($previousPlanPath)) {
        Remove-Item Env:M365_BROWSER_CAPTURE_PLAN -ErrorAction SilentlyContinue
    }
    else {
        $env:M365_BROWSER_CAPTURE_PLAN = $previousPlanPath
    }
}