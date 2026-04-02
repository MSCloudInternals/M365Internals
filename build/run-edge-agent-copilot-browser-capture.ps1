param (
    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [string]$BrowserPlanPath,

    [Parameter()]
    [string]$SpecPath = (Join-Path $PSScriptRoot 'capture-agent-copilot-browser-endpoints.spec.js')
)

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $artifactRoot 'browser-agent-copilot-captures.json'
}

if ([string]::IsNullOrWhiteSpace($BrowserPlanPath)) {
    $BrowserPlanPath = Join-Path $artifactRoot 'agent-copilot-browser-capture-plan.json'
}

$planStorageStatePath = Join-Path $artifactRoot 'playwright-agent-copilot-plan-storage-state.json'
$planMetadataPath = Join-Path $artifactRoot 'playwright-agent-copilot-plan-metadata.json'
$previousPlanPath = $env:M365_BROWSER_CAPTURE_PLAN

. (Join-Path $PSScriptRoot 'PortalSurfaceRegistry.ps1')

try {
    & (Join-Path $PSScriptRoot 'export-playwright-storage-state.ps1') -OutputPath $planStorageStatePath -MetadataPath $planMetadataPath | Out-Null

    $metadata = Get-Content -Path $planMetadataPath -Raw | ConvertFrom-Json
    $browserPlan = New-PortalSurfaceBrowserCapturePlan -RepositoryRoot (Join-Path $PSScriptRoot '..') -PlanIds 'agent-copilot-browser' -TenantId ([string]$metadata.TenantId)
    $browserPlan | ConvertTo-Json -Depth 40 | Set-Content -Path $BrowserPlanPath -Encoding utf8

    $env:M365_BROWSER_CAPTURE_PLAN = $BrowserPlanPath
    & (Join-Path $PSScriptRoot 'run-edge-browser-capture.ps1') -SpecPath $SpecPath -OutputPath $OutputPath
}
finally {
    Remove-Item -Path $planStorageStatePath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $planMetadataPath -Force -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($previousPlanPath)) {
        Remove-Item Env:M365_BROWSER_CAPTURE_PLAN -ErrorAction SilentlyContinue
    }
    else {
        $env:M365_BROWSER_CAPTURE_PLAN = $previousPlanPath
    }
}
