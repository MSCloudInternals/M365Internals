param (
    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [string]$MetadataPath
)

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $artifactRoot 'playwright-admin-storage-state.json'
}

if ([string]::IsNullOrWhiteSpace($MetadataPath)) {
    $MetadataPath = Join-Path $artifactRoot 'playwright-admin-metadata.json'
}

$null = New-Item -Path (Split-Path -Path $OutputPath -Parent) -ItemType Directory -Force
$null = New-Item -Path (Split-Path -Path $MetadataPath -Parent) -ItemType Directory -Force

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

function Get-SessionCookieRecords {
    param (
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
    )

    $cookieTargets = @(
        'https://admin.cloud.microsoft/'
        'https://admin.microsoft.com/'
        'https://login.microsoftonline.com/'
    )

    $seenCookieKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($target in $cookieTargets) {
        foreach ($cookie in @($WebSession.Cookies.GetCookies($target))) {
            $cookieKey = '{0}|{1}|{2}' -f $cookie.Name, $cookie.Domain, $cookie.Path
            if (-not $seenCookieKeys.Add($cookieKey)) {
                continue
            }

            [pscustomobject]@{
                name = $cookie.Name
                value = $cookie.Value
                domain = $cookie.Domain
                path = if ([string]::IsNullOrWhiteSpace([string]$cookie.Path)) { '/' } else { [string]$cookie.Path }
                expires = if ($cookie.Expires -and $cookie.Expires -ne [datetime]::MinValue) {
                    [math]::Floor(([datetimeoffset]$cookie.Expires).ToUnixTimeSeconds())
                }
                else {
                    -1
                }
                httpOnly = [bool]$cookie.HttpOnly
                secure = [bool]$cookie.Secure
                sameSite = 'Lax'
            }
        }
    }
}

$module = Get-ActiveM365PortalModule
$portalSession = $module.SessionState.PSVariable.GetValue('m365PortalSession')

if ($null -eq $portalSession) {
    throw 'No active M365 admin portal session is loaded in the current PowerShell process. Reuse the authenticated shell, connect first, and rerun this script without spawning a new PowerShell instance.'
}

$tenantId = Get-ResolvedTenantId -Module $module
$cookies = @(Get-SessionCookieRecords -WebSession $portalSession)

if ($cookies.Count -eq 0) {
    throw 'No browser-usable cookies were found in the active M365 admin portal session.'
}

$storageState = [pscustomobject]@{
    cookies = $cookies
    origins = @()
}

$metadata = [pscustomobject]@{
    TenantId = $tenantId
    ExportedAt = (Get-Date).ToUniversalTime().ToString('o')
    CookieCount = $cookies.Count
}

$storageState | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath
$metadata | ConvertTo-Json -Depth 5 | Set-Content -Path $MetadataPath

[pscustomobject]@{
    OutputPath = $OutputPath
    MetadataPath = $MetadataPath
    TenantId = $tenantId
    CookieCount = $cookies.Count
} | ConvertTo-Json -Depth 5