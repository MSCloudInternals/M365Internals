param ()

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
$logPath = Join-Path $artifactRoot 'live-admin-write-expansion-log.md'

$null = New-Item -Path $artifactRoot -ItemType Directory -Force

function Add-RunLog {
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )

    Add-Content -Path $logPath -Value $Message
}

Import-Module (Join-Path $PSScriptRoot '..\M365Internals\M365Internals.psd1') -Force
Connect-M365PortalBySSO -Visible | Out-Null

Add-Content -Path $logPath -Value ''
Add-RunLog '7. Started live validation for the new focused setters after reconnecting with SSO.'

$frontierOriginal = $null
$frontierUpdated = $null
$frontierRestored = $null
$copilotOriginal = $null
$copilotUpdated = $null
$copilotRestored = $null
$validationFailed = $false

try {
    $frontierOriginal = Get-M365AdminAgentFrontierAccess -Force
    $frontierTarget = if ([int]$frontierOriginal.FrontierPolicy -eq 0) { 1 } else { 0 }
    Add-RunLog ("- Frontier access original payload: {0}" -f (($frontierOriginal | ConvertTo-Json -Compress -Depth 10)))
    Add-RunLog ("- Frontier access target change: FrontierPolicy {0} -> {1}" -f $frontierOriginal.FrontierPolicy, $frontierTarget)
    Set-M365AdminAgentFrontierAccess -Settings @{ FrontierPolicy = $frontierTarget } -Confirm:$false | Out-Null
    Start-Sleep -Seconds 5
    $frontierUpdated = Get-M365AdminAgentFrontierAccess -Force
    Add-RunLog ("- Frontier access after change: {0}" -f (($frontierUpdated | ConvertTo-Json -Compress -Depth 10)))
    Set-M365AdminAgentFrontierAccess -Settings @{ FrontierPolicy = $frontierOriginal.FrontierPolicy } -Confirm:$false | Out-Null
    Start-Sleep -Seconds 5
    $frontierRestored = Get-M365AdminAgentFrontierAccess -Force
    Add-RunLog ("- Frontier access after restore: {0}" -f (($frontierRestored | ConvertTo-Json -Compress -Depth 10)))
}
catch {
    $validationFailed = $true
    Add-RunLog ("- Frontier access validation error: {0}" -f $_.Exception.Message)

    try {
        if ($null -ne $frontierOriginal) {
            $frontierCurrent = Get-M365AdminAgentFrontierAccess -Force
            Add-RunLog ("- Frontier access current after error: {0}" -f (($frontierCurrent | ConvertTo-Json -Compress -Depth 10)))

            if ([int]$frontierCurrent.FrontierPolicy -ne [int]$frontierOriginal.FrontierPolicy) {
                Set-M365AdminAgentFrontierAccess -Settings @{ FrontierPolicy = $frontierOriginal.FrontierPolicy } -Confirm:$false | Out-Null
                Start-Sleep -Seconds 5
                $frontierRestored = Get-M365AdminAgentFrontierAccess -Force
                Add-RunLog ("- Frontier access recovered after error: {0}" -f (($frontierRestored | ConvertTo-Json -Compress -Depth 10)))
            }
            else {
                Add-RunLog '- Frontier access remained at the original value after the error.'
            }
        }
    }
    catch {
        Add-RunLog ("- Frontier access recovery error: {0}" -f $_.Exception.Message)
    }
}

try {
    $copilotOriginal = Get-M365AdminCopilotPinPolicy -Force
    $copilotTarget = if ([int]$copilotOriginal.CopilotPinningPolicy -eq 0) { 1 } else { 0 }
    Add-RunLog ("- Copilot pin policy original payload: {0}" -f (($copilotOriginal | ConvertTo-Json -Compress -Depth 10)))
    Add-RunLog ("- Copilot pin policy target change: CopilotPinningPolicy {0} -> {1}" -f $copilotOriginal.CopilotPinningPolicy, $copilotTarget)
    Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = $copilotTarget } -Confirm:$false | Out-Null
    Start-Sleep -Seconds 5
    $copilotUpdated = Get-M365AdminCopilotPinPolicy -Force
    Add-RunLog ("- Copilot pin policy after change: {0}" -f (($copilotUpdated | ConvertTo-Json -Compress -Depth 10)))
    Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = $copilotOriginal.CopilotPinningPolicy } -Confirm:$false | Out-Null
    Start-Sleep -Seconds 5
    $copilotRestored = Get-M365AdminCopilotPinPolicy -Force
    Add-RunLog ("- Copilot pin policy after restore: {0}" -f (($copilotRestored | ConvertTo-Json -Compress -Depth 10)))
}
catch {
    $validationFailed = $true
    Add-RunLog ("- Copilot pin policy validation error: {0}" -f $_.Exception.Message)

    try {
        if ($null -ne $copilotOriginal) {
            $copilotCurrent = Get-M365AdminCopilotPinPolicy -Force
            Add-RunLog ("- Copilot pin policy current after error: {0}" -f (($copilotCurrent | ConvertTo-Json -Compress -Depth 10)))

            if ([int]$copilotCurrent.CopilotPinningPolicy -ne [int]$copilotOriginal.CopilotPinningPolicy) {
                Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = $copilotOriginal.CopilotPinningPolicy } -Confirm:$false | Out-Null
                Start-Sleep -Seconds 5
                $copilotRestored = Get-M365AdminCopilotPinPolicy -Force
                Add-RunLog ("- Copilot pin policy recovered after error: {0}" -f (($copilotRestored | ConvertTo-Json -Compress -Depth 10)))
            }
            else {
                Add-RunLog '- Copilot pin policy remained at the original value after the error.'
            }
        }
    }
    catch {
        Add-RunLog ("- Copilot pin policy recovery error: {0}" -f $_.Exception.Message)
    }
}

if (-not $validationFailed) {
    Add-RunLog '- Live validation completed without unreverted changes.'
}
else {
    throw 'One or more live validations failed. See the markdown log for details.'
}

[pscustomobject]@{
    FrontierOriginal = $frontierOriginal
    FrontierUpdated = $frontierUpdated
    FrontierRestored = $frontierRestored
    CopilotOriginal = $copilotOriginal
    CopilotUpdated = $copilotUpdated
    CopilotRestored = $copilotRestored
} | ConvertTo-Json -Depth 12