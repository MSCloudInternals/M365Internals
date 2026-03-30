param (
    [Parameter()]
    [string]$OutputPath
)

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $artifactRoot 'module-agent-copilot-settings-captures.json'
}

$null = New-Item -Path (Split-Path -Path $OutputPath -Parent) -ItemType Directory -Force

function Get-ActiveM365PortalModule {
    $module = Get-Module M365Internals
    if ($null -eq $module) {
        Import-Module (Join-Path $PSScriptRoot '..\M365Internals\M365Internals.psd1') -ErrorAction Stop
        $module = Get-Module M365Internals
    }

    if ($null -eq $module) {
        throw 'The M365Internals module is not loaded in the current PowerShell process.'
    }

    return $module
}

function Get-ResolvedTenantId {
    param (
        [Parameter(Mandatory)]
        $Module
    )

    $connection = $Module.SessionState.PSVariable.GetValue('m365PortalConnection')
    if ($null -eq $connection -or [string]::IsNullOrWhiteSpace([string]$connection.TenantId)) {
        throw 'The active M365 admin portal connection does not currently expose a tenant ID.'
    }

    return [string]$connection.TenantId
}

$module = Get-ActiveM365PortalModule
$portalSession = $module.SessionState.PSVariable.GetValue('m365PortalSession')

if ($null -eq $portalSession) {
    throw 'No active M365 admin portal session is loaded in the current PowerShell process. Reuse the authenticated shell, connect first, and rerun this script without spawning a new PowerShell instance.'
}

$results = [ordered]@{
    CapturedAt = (Get-Date).ToUniversalTime().ToString('o')
    TenantId = Get-ResolvedTenantId -Module $module
    Agent = [ordered]@{
        FrontierAccess = Get-M365AdminAgentFrontierAccess -Force
        SharedSettings = Get-M365AdminAgent -Name SharedSettings -Force
        RequestSettings = Get-M365AdminAgent -Name RequestSettings -Force
        Settings = Get-M365AdminAgentSetting -Name All -Force
        SettingsRaw = Get-M365AdminAgentSetting -Raw -Force
        McpServers = Get-M365AdminAgentTool -Name McpServers -Force
    }
    Copilot = [ordered]@{
        PinPolicy = Get-M365AdminCopilotPinPolicy -Force
        SettingsPage = Invoke-M365AdminRestMethod -Path '/admin/api/copilotsettings/settings' -Method Get
        Settings = Get-M365AdminCopilotSetting -Name All -Force
        SettingsRaw = Get-M365AdminCopilotSetting -Raw -Force
    }
}

$results | ConvertTo-Json -Depth 40 | Set-Content -Path $OutputPath -Encoding utf8
$results | ConvertTo-Json -Depth 12