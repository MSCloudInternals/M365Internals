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

$current = Get-M365AdminCopilotPinPolicy -Force
Add-RunLog ("- Copilot pin policy before explicit baseline restore: {0}" -f (($current | ConvertTo-Json -Compress -Depth 10)))

if ([int]$current.CopilotPinningPolicy -ne 1) {
    Set-M365AdminCopilotPinPolicy -Settings @{ CopilotPinningPolicy = 1 } -Confirm:$false | Out-Null
    Start-Sleep -Seconds 5
    $current = Get-M365AdminCopilotPinPolicy -Force
}

Add-RunLog ("- Copilot pin policy explicit restore to original baseline (1): {0}" -f (($current | ConvertTo-Json -Compress -Depth 10)))

if ([int]$current.CopilotPinningPolicy -ne 1) {
    throw 'Copilot pin policy did not restore to the original baseline value of 1.'
}

$current | ConvertTo-Json -Depth 10