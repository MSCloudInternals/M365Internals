$script:m365PortalHeaders = @{ AjaxSessionKey = 'synthetic-session-only' }
$script:m365PortalSession = $null

function Connect-M365PortalBySoftwarePasskey {
    param([string]$KeyFilePath, $ErrorAction)
    if ($env:M365_MCP_FIXTURE -eq 'auth-failure') { throw 'synthetic credential detail must not escape' }
    $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
}

function Update-M365PortalConnectionSettings {
    if (-not $script:m365PortalSession) { throw 'no synthetic session' }
}

function Get-M365PortalContextHeaders {
    param([string]$Context)
    return @{ 'x-adminapp-request' = '/Settings/OrganizationProfile/:/Settings/L1/DataLocation' }
}

class FixtureHttpException : System.Exception {
    [object]$Response
    FixtureHttpException([int]$Status) : base('synthetic sensitive upstream exception') {
        $this.Response = [pscustomobject]@{ StatusCode = $Status }
    }
}

function Invoke-WebRequest {
    param($Uri, $Method, $WebSession, $Headers, $MaximumRedirection, $TimeoutSec, $ErrorAction)
    if ($Method -cne 'Get' -or $MaximumRedirection -ne 0 -or $TimeoutSec -ne 45 -or
        -not $WebSession -or $Headers.AjaxSessionKey -ne 'synthetic-session-only') {
        throw 'unsafe synthetic request'
    }
    $fixture = $env:M365_MCP_FIXTURE
    if ($fixture -match '^http-(\d+)$') { throw [FixtureHttpException]::new([int]$Matches[1]) }
    if ($fixture -eq 'exception') { throw 'synthetic private upstream exception' }
    if ($fixture -eq 'slow') { Start-Sleep -Seconds 120 }
    $payload = [ordered]@{
        enabled = $true
        name = 'Synthetic tenant configuration'
        observed = '2026-01-01T00:00:00Z'
        uri = $Uri
        method = $Method
        context = $Headers['x-adminapp-request']
        items = @([ordered]@{ name = 'Synthetic item'; enabled = $false })
    }
    $contentType = 'application/json; charset=utf-8'
    $status = 200
    $content = switch ($fixture) {
        'empty-array' { '[]' }
        'empty-object' { '{}' }
        'null' { 'null' }
        'false' { 'false' }
        'zero' { '0' }
        'html' { $contentType = 'text/html'; '<html>synthetic login</html>' }
        'html-json' { '<html>synthetic login</html>' }
        'malformed' { '{' }
        'error-payload' { '{"error":{"message":"synthetic private exception"}}' }
        'blank' { '' }
        'status-201' { $status = 201; '{}' }
        'too-large' { '"' + ('x' * (1024 * 1024)) + '"' }
        'large-page' {
            ConvertTo-Json -InputObject @(1..55 | ForEach-Object { @{ name = "Synthetic $_" } }) -Compress
        }
        'large-object' {
            $object = [ordered]@{}
            1..55 | ForEach-Object { $object["field$_"] = $_ }
            ConvertTo-Json -InputObject $object -Compress
        }
        'long-text' { ConvertTo-Json -InputObject @{ text = 'x' * 501 } -Compress }
        'deep' { '{"a":{"b":{"c":{"d":{"e":"hidden"}}}}}' }
        'redaction' {
            '{"enabled":true,"PasswordValidityPeriod":90,"accessToken":"private","nested":{"cookie":"private","name":"safe"},"clientSecret":"private","privateKey":"private"}'
        }
        'node-budget' {
            ConvertTo-Json -InputObject @(1..50 | ForEach-Object { ,@(1..50 | ForEach-Object { 1 }) }) -Depth 8 -Compress
        }
        'oversized-frame' {
            ConvertTo-Json -InputObject @(1..50 | ForEach-Object { ,@(1..20 | ForEach-Object { 'x' * 500 }) }) -Depth 8 -Compress
        }
        default { ConvertTo-Json -InputObject $payload -Depth 8 -Compress }
    }
    return [pscustomobject]@{
        StatusCode = $status
        Headers = @{ 'Content-Type' = $contentType }
        Content = $content
    }
}

Export-ModuleMember -Function *
