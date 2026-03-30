[CmdletBinding()]
param (
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$PesterOutput = 'None',

    [string[]]$LiveScript = @(),

    [switch]$SkipPester,

    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

$startedAt = Get-Date
$repositoryRoot = Join-Path $PSScriptRoot '..'
$testScriptPath = Join-Path (Join-Path $repositoryRoot 'tests') 'pester.ps1'
$testResultsPath = Join-Path $repositoryRoot 'TestResults'
$artifactPath = Join-Path $testResultsPath 'Artifacts'
$summaryJsonPath = Join-Path $artifactPath 'maintainer-validation-summary.json'
$summaryMarkdownPath = Join-Path $artifactPath 'maintainer-validation-summary.md'

$null = New-Item -Path $testResultsPath -ItemType Directory -Force
$null = New-Item -Path $artifactPath -ItemType Directory -Force

$stepResults = New-Object System.Collections.Generic.List[object]
$failureMessages = New-Object System.Collections.Generic.List[string]

function Resolve-LiveScriptPath {
    param (
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ([System.IO.Path]::IsPathRooted($Name)) {
        return $Name
    }

    return Join-Path $PSScriptRoot $Name
}

if (-not $SkipPester) {
    $pesterStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $pesterSummary = & $testScriptPath -Output $PesterOutput -PassThru
        $pesterStopwatch.Stop()

        $stepResults.Add([pscustomobject]@{
            Name = 'Pester'
            Kind = 'Unit'
            Success = $true
            DurationSeconds = [math]::Round($pesterStopwatch.Elapsed.TotalSeconds, 2)
            TotalCount = $pesterSummary.TotalCount
            PassedCount = $pesterSummary.PassedCount
            FailedCount = $pesterSummary.FailedCount
            ResultPath = $pesterSummary.TestResultsPath
        })
    }
    catch {
        $pesterStopwatch.Stop()
        $failureMessages.Add("Pester: $($_.Exception.Message)")
        $stepResults.Add([pscustomobject]@{
            Name = 'Pester'
            Kind = 'Unit'
            Success = $false
            DurationSeconds = [math]::Round($pesterStopwatch.Elapsed.TotalSeconds, 2)
            TotalCount = $null
            PassedCount = $null
            FailedCount = $null
            ResultPath = $testResultsPath
            Error = $_.Exception.Message
        })
    }
}

if ($failureMessages.Count -eq 0) {
    foreach ($scriptName in @($LiveScript)) {
        $resolvedScriptPath = Resolve-LiveScriptPath -Name $scriptName
        $liveStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            if (-not (Test-Path -Path $resolvedScriptPath -PathType Leaf)) {
                throw "The live validation script '$scriptName' was not found at '$resolvedScriptPath'."
            }

            & $resolvedScriptPath
            $liveStopwatch.Stop()

            $stepResults.Add([pscustomobject]@{
                Name = [System.IO.Path]::GetFileName($resolvedScriptPath)
                Kind = 'Live'
                Success = $true
                DurationSeconds = [math]::Round($liveStopwatch.Elapsed.TotalSeconds, 2)
                ScriptPath = $resolvedScriptPath
            })
        }
        catch {
            $liveStopwatch.Stop()
            $failureMessages.Add("${scriptName}: $($_.Exception.Message)")
            $stepResults.Add([pscustomobject]@{
                Name = [System.IO.Path]::GetFileName($resolvedScriptPath)
                Kind = 'Live'
                Success = $false
                DurationSeconds = [math]::Round($liveStopwatch.Elapsed.TotalSeconds, 2)
                ScriptPath = $resolvedScriptPath
                Error = $_.Exception.Message
            })
            break
        }
    }
}

$completedAt = Get-Date
$summary = [pscustomobject]@{
    StartedAt = $startedAt
    CompletedAt = $completedAt
    RepositoryRoot = $repositoryRoot
    ArtifactPath = $artifactPath
    Success = ($failureMessages.Count -eq 0)
    Steps = [object[]]$stepResults.ToArray()
}

$summary | ConvertTo-Json -Depth 10 | Set-Content -Path $summaryJsonPath -Encoding utf8

$markdownLines = @(
    '# Maintainer Validation Summary'
    ''
    "- Started: $startedAt"
    "- Completed: $completedAt"
    "- Success: $($summary.Success)"
    "- Artifacts: $artifactPath"
    ''
    '| Step | Kind | Success | DurationSeconds | Details |'
    '| ---- | ---- | ------- | --------------- | ------- |'
)

foreach ($step in $summary.Steps) {
    $detailParts = @()

    if ($step.PSObject.Properties.Name -contains 'TotalCount' -and $null -ne $step.TotalCount) {
        $detailParts += "Total=$($step.TotalCount)"
    }
    if ($step.PSObject.Properties.Name -contains 'PassedCount' -and $null -ne $step.PassedCount) {
        $detailParts += "Passed=$($step.PassedCount)"
    }
    if ($step.PSObject.Properties.Name -contains 'FailedCount' -and $null -ne $step.FailedCount) {
        $detailParts += "Failed=$($step.FailedCount)"
    }
    if ($step.PSObject.Properties.Name -contains 'ScriptPath' -and -not [string]::IsNullOrWhiteSpace([string]$step.ScriptPath)) {
        $detailParts += $step.ScriptPath
    }
    if ($step.PSObject.Properties.Name -contains 'ResultPath' -and -not [string]::IsNullOrWhiteSpace([string]$step.ResultPath)) {
        $detailParts += $step.ResultPath
    }
    if ($step.PSObject.Properties.Name -contains 'Error' -and -not [string]::IsNullOrWhiteSpace([string]$step.Error)) {
        $detailParts += $step.Error
    }

    $markdownLines += "| $($step.Name) | $($step.Kind) | $($step.Success) | $($step.DurationSeconds) | $($detailParts -join '; ') |"
}

$markdownLines | Set-Content -Path $summaryMarkdownPath -Encoding utf8

if ($failureMessages.Count -gt 0) {
    throw ($failureMessages -join [Environment]::NewLine)
}

if ($PassThru) {
    return $summary
}