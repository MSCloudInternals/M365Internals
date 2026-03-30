param (
    [Parameter()]
    [string]$SpecPath = (Join-Path $PSScriptRoot 'capture-agent-copilot-browser-endpoints.spec.js'),

    [Parameter()]
    [string]$OutputPath
)

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $artifactRoot 'browser-agent-copilot-captures.json'
}

function Initialize-PlaywrightCaptureRuntime {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuntimeRoot
    )

    $testModulePath = Join-Path $RuntimeRoot 'node_modules\@playwright\test'
    if (-not (Test-Path -LiteralPath $testModulePath)) {
        New-Item -Path $RuntimeRoot -ItemType Directory -Force | Out-Null
        npm install --prefix $RuntimeRoot --no-package-lock --no-save @playwright/test
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install @playwright/test for browser capture."
        }
    }

    $playwrightCliPath = Join-Path $RuntimeRoot 'node_modules\.bin\playwright.cmd'
    if (-not (Test-Path -LiteralPath $playwrightCliPath)) {
        throw "Playwright CLI was not installed at '$playwrightCliPath'."
    }

    return [pscustomobject]@{
        CliPath = $playwrightCliPath
        NodeModulesPath = Join-Path $RuntimeRoot 'node_modules'
    }
}

$storageStatePath = Join-Path $artifactRoot 'playwright-admin-storage-state.json'
$metadataPath = Join-Path $artifactRoot 'playwright-admin-metadata.json'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$resolvedSpecPath = Resolve-Path -LiteralPath $SpecPath
$specDirectory = Split-Path -Path $resolvedSpecPath -Parent
$specFileName = Split-Path -Path $resolvedSpecPath -Leaf
$runtimeRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'M365Internals-PlaywrightCaptureRuntime'
$previousNodePath = $env:NODE_PATH

$null = New-Item -Path $artifactRoot -ItemType Directory -Force

try {
    & (Join-Path $PSScriptRoot 'export-playwright-storage-state.ps1') -OutputPath $storageStatePath -MetadataPath $metadataPath | Out-Null

    $metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
    $runtime = Initialize-PlaywrightCaptureRuntime -RuntimeRoot $runtimeRoot
    $env:M365_TENANT_ID = [string]$metadata.TenantId
    $env:M365_PLAYWRIGHT_STORAGE = $storageStatePath
    $env:M365_PLAYWRIGHT_METADATA = $metadataPath
    $env:M365_BROWSER_CAPTURE_OUTPUT = $OutputPath
    $env:NODE_PATH = if ([string]::IsNullOrWhiteSpace($previousNodePath)) {
        $runtime.NodeModulesPath
    }
    else {
        "$($runtime.NodeModulesPath);$previousNodePath"
    }

    Push-Location $specDirectory
    try {
        & $runtime.CliPath test $specFileName --workers=1 --reporter=line
        if ($LASTEXITCODE -ne 0) {
            throw "Playwright browser capture failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    Remove-Item -Path $storageStatePath -Force -ErrorAction SilentlyContinue
    Remove-Item Env:M365_TENANT_ID -ErrorAction SilentlyContinue
    Remove-Item Env:M365_PLAYWRIGHT_STORAGE -ErrorAction SilentlyContinue
    Remove-Item Env:M365_PLAYWRIGHT_METADATA -ErrorAction SilentlyContinue
    Remove-Item Env:M365_BROWSER_CAPTURE_OUTPUT -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($previousNodePath)) {
        Remove-Item Env:NODE_PATH -ErrorAction SilentlyContinue
    }
    else {
        $env:NODE_PATH = $previousNodePath
    }
}