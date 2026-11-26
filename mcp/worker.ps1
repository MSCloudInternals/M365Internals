# The worker accepts a fixed local protocol over its private stdin.
$ErrorActionPreference = 'Stop'
$ProgressPreference = $WarningPreference = $VerbosePreference = $DebugPreference = 'SilentlyContinue'
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$service = $env:MSCI_WORKER_SERVICE
$modulePath = $env:MSCI_WORKER_MODULE
$binding = $null
$portalModule = $null
$cursors = @{}
$allowedReads = if ($service -ceq 'purview') {
    @('device_health', 'audit_history', 'ediscovery_cases')
}
elseif ($service -ceq 'm365') {
    @('domains', 'current_user')
}
else { exit 1 }

function Get-PortalContext {
    & $portalModule {
        param($Product)
        if ($Product -ceq 'purview') {
            $session = $script:purviewPortalSession
            $connection = $script:purviewPortalConnection
            $revision = $script:purviewConnectionRevision
            $cookieUris = @(
                'https://purview.microsoft.com/api/Auth/getToken'
                'https://purview.microsoft.com/apiproxy/cpm/v1.0/ApplicationUserContext'
                'https://purview.microsoft.com/apiproxy/mtp/ndr/dlpmachines/count'
                'https://purview.microsoft.com/apiproxy/adtsch/AuditLogSearch'
                'https://purview.microsoft.com/apiproxy/aedmcc/ediscovery/v1/purviewcases'
            )
            $cookieNames = @('sccauth')
        }
        else {
            $session = $script:m365PortalSession
            $connection = $script:m365PortalConnection
            $revision = $null
            $cookieUris = @(
                'https://admin.cloud.microsoft/adminportal'
                'https://admin.cloud.microsoft/admin/api/users/currentUser'
                'https://admin.cloud.microsoft/admin/api/coordinatedbootstrap/shellinfo'
                'https://admin.cloud.microsoft/admin/api/Domains/List'
            )
            $cookieNames = @('RootAuthToken', 'SPAAuthCookie', 'OIDCAuthCookie')
        }
        if ($null -eq $session -or $null -eq $connection) { return $null }
        $authValues = foreach ($cookieUri in $cookieUris) {
            $cookies = $session.Cookies.GetCookies([uri]$cookieUri)
            foreach ($name in $cookieNames) {
                if ([string]::IsNullOrWhiteSpace($cookies[$name].Value)) { return $null }
                $cookies[$name].Value
            }
        }
        $fingerprint = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes(($authValues -join [char]0))
            ))
        @{
            Session = $session
            Revision = $revision
            Tenant = [string]$connection.TenantId
            Fingerprint = $fingerprint
        }
    } $service
}

function Test-SamePortal($Expected, $Actual) {
    $null -ne $Expected -and $null -ne $Actual -and
        [object]::ReferenceEquals($Expected.Session, $Actual.Session) -and
        [object]::ReferenceEquals($Expected.Revision, $Actual.Revision) -and
        $Expected.Tenant -eq $Actual.Tenant -and $Expected.Fingerprint -ceq $Actual.Fingerprint
}

function Test-PortalIdentity {
    if ($service -ceq 'purview') {
        Get-PurviewConnection -VerifyIdentity 3>$null 4>$null 5>$null 6>$null
    }
    else {
        Test-M365PortalIdentity 3>$null 4>$null 5>$null 6>$null
    }
}

function Get-Status {
    $connected = $null -ne $binding -and (Test-SamePortal $binding (Get-PortalContext))
    @{
        connected = $connected
        accountVerification = if ($connected) { 'Verified' } else { 'Unknown' }
        resourceTenantVerification = if ($connected) { 'Verified' } else { 'Unknown' }
    }
}

function Connect-Portal {
    if ($null -ne $portalModule) { throw 'invalid_request' }
    if (-not [IO.Path]::IsPathFullyQualified($modulePath)) { throw 'configuration_error' }
    $script:portalModule = Import-Module -Name $modulePath -PassThru 3>$null 4>$null 5>$null 6>$null
    $params = @{}
    $tenant = $env:MSCI_WORKER_TENANT
    if ($tenant) {
        $id = [guid]::Empty
        if (-not [guid]::TryParse($tenant, [ref]$id) -or $id -eq [guid]::Empty) { throw 'configuration_error' }
        $params.TenantId = $id.ToString()
    }
    $mode = $env:MSCI_WORKER_AUTH
    try {
        if ($service -ceq 'm365' -and $mode -ceq 'passkey') {
            $key = $env:MSCI_WORKER_PASSKEY
            if (-not [IO.Path]::IsPathFullyQualified($key)) { throw 'configuration_error' }
            $null = Connect-M365PortalBySoftwarePasskey -KeyFilePath $key @params 3>$null 4>$null 5>$null 6>$null
        }
        else {
            if ($env:MSCI_WORKER_PROFILE) { $params.ProfilePath = $env:MSCI_WORKER_PROFILE }
            if ($env:MSCI_WORKER_BROWSER) { $params.BrowserPath = $env:MSCI_WORKER_BROWSER }
            $params.TimeoutSeconds = 60
            if ($service -ceq 'purview' -and $mode -ceq 'browser') {
                $null = Connect-PurviewPortal @params 3>$null 4>$null 5>$null 6>$null
            }
            elseif ($service -ceq 'm365' -and $mode -ceq 'sso') {
                $null = Connect-M365PortalBySSO @params 3>$null 4>$null 5>$null 6>$null
            }
            elseif ($service -ceq 'm365' -and $mode -ceq 'browser') {
                $null = Connect-M365PortalByBrowser @params 3>$null 4>$null 5>$null 6>$null
            }
            else { throw 'configuration_error' }
        }
    }
    catch {
        if ($_.Exception.Message -ceq 'configuration_error') { throw }
        throw 'connection_failed'
    }
    $context = Get-PortalContext
    $identity = Test-PortalIdentity
    if ($identity.AccountVerification -cne 'Verified' -or $identity.ResourceTenantVerification -cne 'Verified' -or
        -not (Test-SamePortal $context (Get-PortalContext)) -or ($tenant -and $context.Tenant -ne $params.TenantId)) {
        throw 'identity_unverified'
    }
    $script:binding = $context
    Get-Status
}

function Get-Text($Value, [int]$Limit = 200) {
    if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)) { return $null }
    $plain = $Value -replace '\p{C}', ' '
    $plain.Substring(0, [Math]::Min($plain.Length, $Limit))
}

function Get-Number($Value) {
    if ($Value -is [int] -or $Value -is [long]) {
        if ($Value -ge 0 -and $Value -le [int]::MaxValue) { return [int]$Value }
    }
    throw 'response_invalid'
}

function Get-Limit($Arguments, [int]$Maximum) {
    if (-not $Arguments.Contains('limit')) { return $Maximum }
    $value = $Arguments.limit
    if (($value -isnot [int] -and $value -isnot [long]) -or $value -lt 1 -or $value -gt $Maximum) { throw 'invalid_request' }
    return [int]$value
}

function Assert-Keys($Arguments, [string[]]$Allowed = @()) {
    foreach ($key in $Arguments.Keys) {
        if ($key -cnotin $Allowed) { throw 'invalid_request' }
    }
}

function Get-AuditHistory($Arguments) {
    Assert-Keys $Arguments @('limit', 'cursor')
    $now = [datetime]::UtcNow
    foreach ($key in @($cursors.Keys)) {
        if ($cursors[$key].Expires -le $now) { $cursors.Remove($key) }
    }
    $incoming = $Arguments.cursor
    if ($Arguments.Contains('cursor')) {
        if ($incoming -isnot [string] -or $incoming -cnotmatch '\A[a-f0-9]{32}\z' -or $Arguments.Contains('limit')) {
            throw 'invalid_request'
        }
        if (-not $cursors.ContainsKey($incoming)) { throw 'cursor_expired' }
        $entry = $cursors[$incoming]
        $page = Get-PurviewAuditSearchResult -PageSize $entry.Size -ContinuationToken $entry.Token
        $size = $entry.Size
        $cursors.Remove($incoming)
    }
    else {
        $size = Get-Limit $Arguments 25
        $page = Get-PurviewAuditSearchResult -PageSize $size
    }
    $next = $null
    if ($page.HasMorePages) {
        if ($page.ContinuationToken -isnot [string] -or [string]::IsNullOrWhiteSpace($page.ContinuationToken)) { throw 'response_invalid' }
        if ($cursors.Count -ge 64) {
            $oldest = $cursors.GetEnumerator() | Sort-Object { $_.Value.Expires } | Select-Object -First 1
            $cursors.Remove($oldest.Key)
        }
        $next = [guid]::NewGuid().ToString('N')
        $cursors[$next] = @{ Token = $page.ContinuationToken; Size = $size; Expires = $now.AddMinutes(10) }
    }
    @{
        items = @($page.Records | Select-Object -First $size | ForEach-Object {
                @{
                    id = Get-Text ($_.jobId ?? $_.requestId ?? $_.id ?? $_.searchId) 128
                    name = Get-Text ($_.searchName ?? $_.name)
                    status = Get-Text ($_.status ?? $_.searchStatus) 80
                    created = if ($_.createdTimeUtc -is [datetime]) { $_.createdTimeUtc.ToString('o') } else { Get-Text $_.createdTimeUtc 64 }
                }
            })
        nextCursor = $next
    }
}

function Invoke-PortalRead([string]$Operation, $Arguments) {
    if (-not $binding) { throw 'not_connected' }
    if (-not (Test-SamePortal $binding (Get-PortalContext))) {
        $script:binding = $null
        $cursors.Clear()
        throw 'identity_unverified'
    }
    $result = switch -CaseSensitive ($Operation) {
        'device_health' {
            Assert-Keys $Arguments
            $report = Get-PurviewDeviceHealth
            @{
                updatedLastDay = Get-Number $report.UpdatedLast1DayCount
                lastDay = Get-Number $report.Last1DayCount
                last3Days = Get-Number $report.Last3DayCount
                last7Days = Get-Number $report.Last7DayCount
                last30Days = Get-Number $report.Last30DayCount
            }
        }
        'audit_history' { Get-AuditHistory $Arguments }
        'ediscovery_cases' {
            Assert-Keys $Arguments @('limit', 'caseId')
            $limit = Get-Limit $Arguments 25
            $caseParams = @{}
            if ($Arguments.Contains('caseId')) {
                if ($Arguments.caseId -isnot [string] -or $Arguments.caseId -cnotmatch '\A[A-Za-z0-9_.-]{1,128}\z') { throw 'invalid_request' }
                $caseParams.Id = $Arguments.caseId
            }
            $rows = @(Get-PurviewEDiscoveryCase @caseParams)
            @{
                items = @($rows | Select-Object -First $limit | ForEach-Object {
                        @{ id = Get-Text $_.id 128; name = Get-Text $_.displayName; status = Get-Text $_.status 80; type = Get-Text $_.caseType 80 }
                    })
                truncated = $rows.Count -gt $limit
            }
        }
        'domains' {
            Assert-Keys $Arguments @('limit')
            $limit = Get-Limit $Arguments 50
            # Preserve empty and single-element JSON arrays before PowerShell can unwrap them.
            $response = & $portalModule {
                Invoke-M365PortalRequest -Path '/admin/api/Domains/List' -WebSession $script:m365PortalSession -SkipConnectionRefresh -SkipAutoHeal -RawResponse
            }
            $payload = ConvertFrom-Json -InputObject $response.Content -NoEnumerate -Depth 20
            $rows = if ($payload -is [array]) { ,$payload } elseif ($payload.Domains -is [array]) { ,$payload.Domains } elseif ($payload.value -is [array]) { ,$payload.value } else { throw 'response_invalid' }
            @{
                items = @($rows | Select-Object -First $limit | ForEach-Object { @{name = Get-Text ($_.Name ?? $_.DomainName ?? $_.id) 253 } })
                truncated = @($rows).Count -gt $limit
            }
        }
        'current_user' {
            Assert-Keys $Arguments
            $user = (Get-M365AdminUserSetting -Name CurrentUser -Force -Raw).UserInfo
            if (-not $user) { throw 'response_invalid' }
            @{
                id = Get-Text $user.ObjectId 64
                displayName = Get-Text $user.DisplayName
                principalName = Get-Text $user.UserPrincipalName
            }
        }
    }
    if (-not (Test-SamePortal $binding (Get-PortalContext))) {
        $script:binding = $null
        $cursors.Clear()
        throw 'identity_unverified'
    }
    if ($service -ceq 'purview') {
        $identity = Get-PurviewConnection -Status
        if ($identity.AccountVerification -cne 'Verified' -or $identity.ResourceTenantVerification -cne 'Verified') {
            $identity = Test-PortalIdentity
            if ($identity.AccountVerification -cne 'Verified' -or $identity.ResourceTenantVerification -cne 'Verified' -or
                -not (Test-SamePortal $binding (Get-PortalContext))) {
                $script:binding = $null
                $cursors.Clear()
                throw 'identity_unverified'
            }
        }
    }
    return $result
}

$errors = @('invalid_request', 'configuration_error', 'connection_failed', 'identity_unverified', 'not_connected', 'cursor_expired', 'response_invalid')
while ($null -ne ($line = [Console]::ReadLine())) {
    $id = $null
    try {
        if ($line.Length -gt 16384) { throw 'invalid_request' }
        $request = ConvertFrom-Json -InputObject $line -AsHashtable -Depth 8
        if ($request.id -isnot [string] -or $request.id -cnotmatch '\A[a-f0-9]{32}\z' -or $request.arguments -isnot [System.Collections.IDictionary]) {
            throw 'invalid_request'
        }
        $id = $request.id
        $operation = $request.operation
        $arguments = $request.arguments
        $result = if ($operation -ceq 'status') {
            Assert-Keys $arguments
            Get-Status
        }
        elseif ($operation -ceq 'connect') {
            Assert-Keys $arguments
            Connect-Portal
        }
        elseif ($operation -cin $allowedReads) {
            Invoke-PortalRead $operation $arguments 3>$null 4>$null 5>$null 6>$null
        }
        else { throw 'invalid_request' }
        $response = @{ id = $id; ok = $true; data = $result }
    }
    catch {
        $code = $_.Exception.Message
        if ($code -cnotin $errors) { $code = 'request_failed' }
        $response = @{ id = $id; ok = $false; error = $code }
    }
    $json = ConvertTo-Json -InputObject $response -Depth 12 -Compress
    [Console]::WriteLine($json)
    [Console]::Out.Flush()
}
