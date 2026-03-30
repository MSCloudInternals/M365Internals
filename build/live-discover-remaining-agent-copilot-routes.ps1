param ()

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
$logPath = Join-Path $artifactRoot 'live-admin-write-expansion-log.md'
$resultPath = Join-Path $artifactRoot 'remaining-route-probes.json'

$null = New-Item -Path $artifactRoot -ItemType Directory -Force

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

$probeRequests = @(
    [pscustomobject]@{ Label = 'AgentSharedSettings-Patch-Full'; Path = '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings'; Method = 'Patch'; Body = $sharedSettings },
    [pscustomobject]@{ Label = 'AgentSharedSettings-Patch-SettingsOnly'; Path = '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings'; Method = 'Patch'; Body = $sharedSettings.settings },
    [pscustomobject]@{ Label = 'AgentSharedSettings-Patch-SettingsWrapper'; Path = '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings'; Method = 'Patch'; Body = @{ settings = $sharedSettings.settings } },
    [pscustomobject]@{ Label = 'AgentSharedSettings-Post-SettingsWrapper'; Path = '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings'; Method = 'Post'; Body = @{ settings = $sharedSettings.settings } },
    [pscustomobject]@{ Label = 'AgentSharedSettings-Put-SettingsWrapper'; Path = '/fd/addins/api/v2/settings?keys=IsTenantEligibleForEntireOrgEmail,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AreMicrosoftCertified3PAppsAllowed,MetaOSCopilotExtensibilitySettings'; Method = 'Put'; Body = @{ settings = $sharedSettings.settings } },
    [pscustomobject]@{ Label = 'AgentRequestSettings-Patch-SettingsWrapper'; Path = '/fd/addins/api/v2/settings?keys=MetaOSCopilotExtensibilitySettings,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AdminRoles,AllowOrgWideSharing'; Method = 'Patch'; Body = @{ settings = $requestSettings.settings } },
    [pscustomobject]@{ Label = 'AgentRequestSettings-Post-SettingsWrapper'; Path = '/fd/addins/api/v2/settings?keys=MetaOSCopilotExtensibilitySettings,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AdminRoles,AllowOrgWideSharing'; Method = 'Post'; Body = @{ settings = $requestSettings.settings } },
    [pscustomobject]@{ Label = 'AgentRequestSettings-Put-SettingsWrapper'; Path = '/fd/addins/api/v2/settings?keys=MetaOSCopilotExtensibilitySettings,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AdminRoles,AllowOrgWideSharing'; Method = 'Put'; Body = @{ settings = $requestSettings.settings } },
    [pscustomobject]@{ Label = 'AgentMcpServers-Post-Empty'; Path = '/admin/api/agentssettings/mcpservers'; Method = 'Post'; Body = @{} },
    [pscustomobject]@{ Label = 'AgentMcpServers-Put-Empty'; Path = '/admin/api/agentssettings/mcpservers'; Method = 'Put'; Body = @{} },
    [pscustomobject]@{ Label = 'AgentMcpServers-Patch-Empty'; Path = '/admin/api/agentssettings/mcpservers'; Method = 'Patch'; Body = @{} },
    [pscustomobject]@{ Label = 'CopilotSettings-Post-Full'; Path = '/admin/api/copilotsettings/settings'; Method = 'Post'; Body = $copilotSettings },
    [pscustomobject]@{ Label = 'CopilotSettings-Put-Full'; Path = '/admin/api/copilotsettings/settings'; Method = 'Put'; Body = $copilotSettings },
    [pscustomobject]@{ Label = 'CopilotSettings-Patch-Full'; Path = '/admin/api/copilotsettings/settings'; Method = 'Patch'; Body = $copilotSettings },
    [pscustomobject]@{ Label = 'CopilotDismissed-Post-Empty'; Path = '/admin/api/copilotsettings/settings/dismissed'; Method = 'Post'; Body = @{} },
    [pscustomobject]@{ Label = 'CopilotDismissed-Put-Empty'; Path = '/admin/api/copilotsettings/settings/dismissed'; Method = 'Put'; Body = @{} },
    [pscustomobject]@{ Label = 'CopilotDismissed-Patch-Empty'; Path = '/admin/api/copilotsettings/settings/dismissed'; Method = 'Patch'; Body = @{} },
    [pscustomobject]@{ Label = 'SecurityCopilotAuth-Post-Unversioned-Bool'; Path = '/admin/api/copilotsettings/securitycopilot/auth'; Method = 'Post'; Body = $securityCopilotAuth },
    [pscustomobject]@{ Label = 'SecurityCopilotAuth-Put-Unversioned-Bool'; Path = '/admin/api/copilotsettings/securitycopilot/auth'; Method = 'Put'; Body = $securityCopilotAuth },
    [pscustomobject]@{ Label = 'SecurityCopilotAuth-Patch-Unversioned-Bool'; Path = '/admin/api/copilotsettings/securitycopilot/auth'; Method = 'Patch'; Body = $securityCopilotAuth },
    [pscustomobject]@{ Label = 'SecurityCopilotAuth-Post-Versioned-Bool'; Path = '/admin/api/copilotsettings/securitycopilot/auth?api-version=1.0'; Method = 'Post'; Body = $securityCopilotAuth },
    [pscustomobject]@{ Label = 'SecurityCopilotAuth-Put-Versioned-Bool'; Path = '/admin/api/copilotsettings/securitycopilot/auth?api-version=1.0'; Method = 'Put'; Body = $securityCopilotAuth },
    [pscustomobject]@{ Label = 'SecurityCopilotAuth-Patch-Versioned-Bool'; Path = '/admin/api/copilotsettings/securitycopilot/auth?api-version=1.0'; Method = 'Patch'; Body = $securityCopilotAuth },
    [pscustomobject]@{ Label = 'SecurityCopilotAuth-Post-Versioned-Wrapper'; Path = '/admin/api/copilotsettings/securitycopilot/auth?api-version=1.0'; Method = 'Post'; Body = @{ value = $securityCopilotAuth } },
    [pscustomobject]@{ Label = 'BillingPolicies-Post-Empty'; Path = '/_api/v2.1/billingPolicies'; Method = 'Post'; Body = @{} },
    [pscustomobject]@{ Label = 'BillingPolicies-Put-Empty'; Path = '/_api/v2.1/billingPolicies'; Method = 'Put'; Body = @{} },
    [pscustomobject]@{ Label = 'BillingPolicies-Patch-Empty'; Path = '/_api/v2.1/billingPolicies'; Method = 'Patch'; Body = @{} },
    [pscustomobject]@{ Label = 'BillingPoliciesFeature-Post-Empty'; Path = '/_api/v2.1/billingPolicies?feature=M365CopilotChat'; Method = 'Post'; Body = @{} },
    [pscustomobject]@{ Label = 'BillingPoliciesFeature-Put-Empty'; Path = '/_api/v2.1/billingPolicies?feature=M365CopilotChat'; Method = 'Put'; Body = @{} },
    [pscustomobject]@{ Label = 'BillingPoliciesFeature-Patch-Empty'; Path = '/_api/v2.1/billingPolicies?feature=M365CopilotChat'; Method = 'Patch'; Body = @{} }
)

$probeResults = foreach ($probe in $probeRequests) {
    try {
        $result = Invoke-PortalProbe -Label $probe.Label -Path $probe.Path -Method $probe.Method -Body $probe.Body
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
            BodySupplied   = $true
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