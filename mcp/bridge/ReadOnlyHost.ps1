#requires -Version 7.5
param(
    [string]$ModulePath = (Join-Path $PSScriptRoot '../../M365Internals/M365Internals.psd1')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$definitions = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot '../tools.json') -Raw | ConvertFrom-Json -AsHashtable)
$connected = $false
$authAttempted = $false
$revoked = $false

function Send-Response {
    param([string]$Id, [bool]$Ok, $Data, [string]$Code)
    $response = @{ id = $Id; ok = $Ok }
    if ($Ok) { $response.data = $Data } else { $response.error = $Code }
    $json = ConvertTo-Json -InputObject $response -Depth 12 -Compress
    if ([Text.Encoding]::UTF8.GetByteCount($json + "`n") -gt 256 * 1024) {
        $json = ConvertTo-Json -InputObject @{ id = $Id; ok = $false; error = 'invalid_response' } -Compress
    }
    [Console]::Out.WriteLine($json)
    [Console]::Out.Flush()
}

function ConvertTo-BoundedValue {
    param($Value, [int]$Depth, [hashtable]$State)
    $State.Nodes++
    if ($State.Nodes -ge 2048 -or $Depth -gt 4) {
        $State.Truncated = $true
        return $null
    }
    if ($null -eq $Value -or $Value -is [bool] -or $Value -is [ValueType]) { return $Value }
    if ($Value -is [string]) {
        if ($Value.Length -gt 500) { $State.Truncated = $true; return $Value.Substring(0, 500) }
        return $Value
    }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Depth -eq 4) { $State.Truncated = $true; return $null }
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) {
            if ($result.Count -ge 50 -or $State.Nodes -ge 2047) { $State.Truncated = $true; break }
            if ($key.Length -gt 80) { $State.Truncated = $true; continue }
            if ($key -match '(?i)^(password|secret|credential|credentials|authorization|cookie|cookies|ajaxsessionkey|privatekey|connectionstring)$|token$|secret$|password$') {
                $State.Truncated = $true
                continue
            }
            $result[$key] = ConvertTo-BoundedValue -Value $Value[$key] -Depth ($Depth + 1) -State $State
        }
        return $result
    }
    if ($Value -is [array]) {
        if ($Depth -eq 4) { $State.Truncated = $true; return $null }
        $result = [Collections.Generic.List[object]]::new()
        foreach ($item in $Value) {
            if ($result.Count -ge 50 -or $State.Nodes -ge 2047) { $State.Truncated = $true; break }
            $result.Add((ConvertTo-BoundedValue -Value $item -Depth ($Depth + 1) -State $State))
        }
        return ,$result.ToArray()
    }
    throw 'invalid_response'
}

while ($null -ne ($line = [Console]::In.ReadLine())) {
    $id = ''
    try {
        if ($line.Length -gt 8192) { throw 'invalid_request' }
        try { $request = ConvertFrom-Json -InputObject $line -AsHashtable -ErrorAction Stop }
        catch { throw 'invalid_request' }
        if ($request -isnot [System.Collections.IDictionary] -or $request.Count -ne 3 -or
            -not $request.Contains('id') -or -not $request.Contains('operation') -or -not $request.Contains('args') -or
            $request.id -isnot [string] -or $request.id -cnotmatch '^[0-9]{1,16}\z' -or
            $request.operation -isnot [string]) { throw 'invalid_request' }
        $id = $request.id
        $definition = @($definitions | Where-Object { $_.operation -ceq $request.operation })
        if ($definition.Count -ne 1) { throw 'operation_not_allowed' }
        $definition = $definition[0]
        $arguments = $request.args
        if ($arguments -isnot [System.Collections.IDictionary]) { throw 'invalid_arguments' }
        $section = $null
        $path = $definition.path
        if ($definition.sections) {
            if ($arguments.Count -ne 1 -or -not $arguments.Contains('section') -or $arguments.section -isnot [string] -or
                $arguments.section -cnotin @($definition.sections.Keys)) { throw 'invalid_arguments' }
            $section = $arguments.section
            $path = $definition.sections[$section]
        } elseif ($definition.domain) {
            if ($arguments.Count -ne 1 -or -not $arguments.Contains('domain') -or $arguments.domain -isnot [string] -or
                $arguments.domain -cnotmatch '^(?=.{1,253}\z)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\z') {
                throw 'invalid_arguments'
            }
            $path = '{0}?domainName={1}' -f $path, [uri]::EscapeDataString($arguments.domain)
        } elseif ($arguments.Count -ne 0) { throw 'invalid_arguments' }
        if ($path -cnotmatch '^/admin/api/[A-Za-z0-9/]+(?:\?domainName=[A-Za-z0-9.-]+)?\z') { throw 'operation_not_allowed' }
        if ($revoked) { throw 'not_connected' }

        if (-not $authAttempted) {
            $authAttempted = $true
            if ($env:M365_MCP_AUTH -eq 'software-passkey') {
                try {
                    $keyFile = $env:M365_MCP_PASSKEY_FILE
                    if ([string]::IsNullOrWhiteSpace($keyFile) -or -not [IO.Path]::IsPathFullyQualified($keyFile) -or
                        -not (Test-Path -LiteralPath $keyFile -PathType Leaf)) { throw 'invalid_passkey_path' }
                    $module = Import-Module $ModulePath -PassThru -ErrorAction Stop
                    & $module {
                        param($KeyFile)
                        Connect-M365PortalBySoftwarePasskey -KeyFilePath $KeyFile -ErrorAction Stop *> $null
                    } $keyFile
                    $connected = $true
                } catch {
                    [Console]::Error.WriteLine('Sign-in failed. Restart the server to try again.')
                }
            }
        }
        if (-not $connected) { throw 'not_connected' }

        try {
            # Reuse portal authentication, but bypass caches, bootstrap retries and redirects.
            $response = & $module {
                param($Path)
                Update-M365PortalConnectionSettings
                $headers = @{}
                foreach ($entry in $script:m365PortalHeaders.GetEnumerator()) {
                    $headers[$entry.Key] = $entry.Value
                }
                if ($Path -in @('/admin/api/tenant/datalocationandcommitments', '/admin/api/tenant/localdatalocation')) {
                    foreach ($entry in (Get-M365PortalContextHeaders -Context DataLocation).GetEnumerator()) {
                        $headers[$entry.Key] = $entry.Value
                    }
                }
                Invoke-WebRequest -Uri ('https://admin.cloud.microsoft' + $Path) -Method Get `
                    -WebSession $script:m365PortalSession -Headers $headers `
                    -MaximumRedirection 0 -TimeoutSec 45 -ErrorAction Stop
            } $path
        } catch {
            $exception = $_.Exception
            $status = $null
            while ($exception) {
                if ($exception.PSObject.Properties['Response'] -and $exception.Response) {
                    $status = [int]$exception.Response.StatusCode
                    break
                }
                $exception = $exception.InnerException
            }
            if ($status -in @(401, 403)) {
                $connected = $false
                $revoked = $true
                throw 'not_connected'
            }
            if ($status -eq 404) { throw 'not_found' }
            throw 'upstream_failed'
        }
        if ([int]$response.StatusCode -ne 200 -or
            [string]$response.Headers['Content-Type'] -notmatch '(?i)^application/(?:[a-z0-9.+-]+\+)?json(?:;|$)' -or
            $response.Content -isnot [string] -or [Text.Encoding]::UTF8.GetByteCount($response.Content) -gt 1024 * 1024 -or
            [string]::IsNullOrWhiteSpace($response.Content)) { throw 'invalid_response' }
        try { $payload = ConvertFrom-Json -InputObject $response.Content -AsHashtable -NoEnumerate -DateKind String -Depth 20 }
        catch { throw 'invalid_response' }
        if ($payload -is [System.Collections.IDictionary] -and
            @($payload.Keys | Where-Object { $_ -imatch '^(error|errors|errorCode)$' }).Count -gt 0) { throw 'upstream_failed' }
        $state = @{ Nodes = 0; Truncated = $false }
        $data = ConvertTo-BoundedValue -Value $payload -Depth 0 -State $state
        Send-Response -Id $id -Ok $true -Data @{
            surface = $request.operation
            section = $section
            status = $(if ($null -eq $payload) { 'unavailable' } else { 'ok' })
            truncated = $state.Truncated
            data = $data
        }
    } catch {
        $code = $_.Exception.Message
        if ($code -cnotin @('invalid_request', 'invalid_arguments', 'operation_not_allowed', 'not_connected', 'not_found', 'invalid_response', 'upstream_failed')) {
            $code = 'operation_failed'
        }
        Send-Response -Id $id -Ok $false -Code $code
    }
}
