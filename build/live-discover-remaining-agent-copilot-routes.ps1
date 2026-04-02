param ()

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
$logPath = Join-Path $artifactRoot 'live-admin-write-expansion-log.md'
$resultPath = Join-Path $artifactRoot 'remaining-route-probes.json'

$null = New-Item -Path $artifactRoot -ItemType Directory -Force
. (Join-Path $PSScriptRoot 'PortalSurfaceRegistry.ps1')

function Add-RunLog {
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )

    Add-Content -Path $logPath -Value $Message
}

function Get-ModuleVariableValue {
    param (
        [Parameter(Mandatory)]
        [string]$Name
    )

    $module = Get-Module M365Internals -ErrorAction Stop
    return $module.SessionState.PSVariable.GetValue($Name)
}

function Invoke-PortalProbe {
    param (
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('Get', 'Post', 'Put', 'Patch', 'Delete')]
        [string]$Method,

        [Parameter()]
        [hashtable]$Headers,

        [Parameter()]
        $Body,

        [Parameter()]
        [string]$ContentType = 'application/json'
    )

    $session = Get-ModuleVariableValue -Name 'm365PortalSession'
    $portalHeaders = Get-ModuleVariableValue -Name 'm365PortalHeaders'
    $resolvedHeaders = @{}
    foreach ($headerEntry in @($portalHeaders.GetEnumerator())) {
        $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
    }

    if ($Headers) {
        foreach ($headerEntry in @($Headers.GetEnumerator())) {
            $resolvedHeaders[$headerEntry.Key] = $headerEntry.Value
        }
    }

    $uri = if ($Path.StartsWith('/')) {
        'https://admin.cloud.microsoft{0}' -f $Path
    }
    else {
        $Path
    }

    $invokeParams = @{
        Uri                = $uri
        Method             = $Method
        WebSession         = $session
        Headers            = $resolvedHeaders
        SkipHttpErrorCheck = $true
        ErrorAction        = 'Stop'
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $invokeParams.ContentType = $ContentType
        if (($Body -isnot [string]) -and $ContentType -match 'json') {
            $invokeParams.Body = $Body | ConvertTo-Json -Depth 30 -Compress
        }
        else {
            $invokeParams.Body = $Body
        }
    }

    $response = Invoke-WebRequest @invokeParams
    $content = [string]$response.Content
    $contentPreview = if ($content.Length -gt 400) { $content.Substring(0, 400) } else { $content }

    return [pscustomobject]@{
        Label          = $Label
        Path           = $Path
        Method         = $Method
        StatusCode     = [int]$response.StatusCode
        IsSuccess      = ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300)
        BodySupplied   = $PSBoundParameters.ContainsKey('Body')
        BodyPreview    = if ($PSBoundParameters.ContainsKey('Body')) { [string]$invokeParams.Body } else { $null }
        ContentPreview = $contentPreview
    }
}

Import-Module (Join-Path $PSScriptRoot '..\M365Internals\M365Internals.psd1') -Force
Connect-M365PortalBySSO -Visible | Out-Null

$sharedSettings = Get-M365AdminAgent -Name SharedSettings -Force
$requestSettings = Get-M365AdminAgent -Name RequestSettings -Force
$mcpServers = Get-M365AdminAgentTool -Name McpServers -Force
$copilotSettings = Invoke-M365AdminRestMethod -Path '/admin/api/copilotsettings/settings' -Method Get
$securityCopilotAuth = Get-M365AdminCopilotSetting -Name SecurityCopilotAuth -Force
$copilotChatBillingPolicy = Get-M365AdminCopilotSetting -Name CopilotChatBillingPolicy -Force
$billingPolicies = Get-M365AdminCopilotBillingUsage -Name BillingPolicies -Force

$probeBodySources = @{
    AgentSharedSettingsFull = $sharedSettings
    AgentSharedSettingsSettings = $sharedSettings.settings
    AgentRequestSettingsSettings = $requestSettings.settings
    EmptyObject = @{}
    CopilotSettingsFull = $copilotSettings
    SecurityCopilotAuthValue = $securityCopilotAuth
    SecurityCopilotAuthWrapper = @{ value = $securityCopilotAuth }
}
$writeProbePlan = New-PortalSurfaceWriteProbePlan -RepositoryRoot (Join-Path $PSScriptRoot '..') -PlanIds 'agent-copilot-write-probes'
$probeRequests = @(
    foreach ($request in @($writeProbePlan.Requests)) {
        $body = $null
        if ($request.PSObject.Properties.Name -contains 'BodySource') {
            $bodySource = [string]$request.BodySource
            if (-not $probeBodySources.ContainsKey($bodySource)) {
                throw "The write probe body source '$bodySource' is not defined in live-discover-remaining-agent-copilot-routes.ps1."
            }

            $body = $probeBodySources[$bodySource]
            if (($request.PSObject.Properties.Name -contains 'BodyWrapperProperty') -and (-not [string]::IsNullOrWhiteSpace([string]$request.BodyWrapperProperty))) {
                $body = @{
                    ([string]$request.BodyWrapperProperty) = $body
                }
            }
        }

        [pscustomobject]@{
            Label = [string]$request.Name
            Path = [string]$request.Path
            Method = [string]$request.Method
            Body = $body
            Headers = if ($request.PSObject.Properties.Name -contains 'Headers') { $request.Headers } else { $null }
            ContentType = if ($request.PSObject.Properties.Name -contains 'ContentType') { [string]$request.ContentType } else { 'application/json' }
        }
    }
)

$probeResults = foreach ($probe in $probeRequests) {
    try {
        $result = Invoke-PortalProbe -Label $probe.Label -Path $probe.Path -Method $probe.Method -Headers $probe.Headers -Body $probe.Body -ContentType $probe.ContentType
        Add-RunLog ("- Probe {0}: {1} {2} -> {3}" -f $probe.Label, $probe.Method.ToUpperInvariant(), $probe.Path, $result.StatusCode)
        if (-not [string]::IsNullOrWhiteSpace($result.ContentPreview)) {
            Add-RunLog ("  Response preview: {0}" -f $result.ContentPreview)
        }
        $result
    }
    catch {
        $errorResult = [pscustomobject]@{
            Label          = $probe.Label
            Path           = $probe.Path
            Method         = $probe.Method
            StatusCode     = $null
            IsSuccess      = $false
            BodySupplied   = ($null -ne $probe.Body)
            BodyPreview    = if ($null -ne $probe.Body) { ($probe.Body | ConvertTo-Json -Depth 10 -Compress) } else { $null }
            ContentPreview = $_.Exception.Message
        }

        Add-RunLog ("- Probe {0}: {1} {2} -> error" -f $probe.Label, $probe.Method.ToUpperInvariant(), $probe.Path)
        Add-RunLog ("  Response preview: {0}" -f $_.Exception.Message)
        $errorResult
    }
}

$summary = [pscustomobject]@{
    AgentSharedSettings = $sharedSettings
    AgentRequestSettings = $requestSettings
    AgentMcpServers = $mcpServers
    CopilotSettings = $copilotSettings
    SecurityCopilotAuth = $securityCopilotAuth
    CopilotChatBillingPolicy = $copilotChatBillingPolicy
    BillingPolicies = $billingPolicies
    ProbeResults = @($probeResults)
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -Path $resultPath
$summary | ConvertTo-Json -Depth 20
