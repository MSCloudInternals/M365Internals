param ()

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
$logPath = Join-Path $artifactRoot 'live-admin-write-expansion-log.md'
$resultPath = Join-Path $artifactRoot 'settings-write-route-probes.json'

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

function Get-ResolvedTenantId {
    $connection = Get-ModuleVariableValue -Name 'm365PortalConnection'
    if ($null -eq $connection -or [string]::IsNullOrWhiteSpace([string]$connection.TenantId)) {
        throw 'The active M365 admin portal session does not expose a tenant ID.'
    }

    return [string]$connection.TenantId
}

function ConvertTo-ContentPreview {
    param (
        [AllowNull()]
        $Value,

        [int]$MaximumLength = 400
    )

    if ($null -eq $Value) {
        return $null
    }

    $content = if ($Value -is [string]) {
        $Value
    }
    else {
        $Value | ConvertTo-Json -Depth 20 -Compress
    }

    if ($content.Length -le $MaximumLength) {
        return $content
    }

    return $content.Substring(0, $MaximumLength)
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
            $invokeParams.Body = $Body | ConvertTo-Json -Depth 50 -Compress
        }
        else {
            $invokeParams.Body = $Body
        }
    }

    $response = Invoke-WebRequest @invokeParams
    $content = [string]$response.Content

    return [pscustomobject]@{
        Label          = $Label
        Path           = $Path
        Method         = $Method
        StatusCode     = [int]$response.StatusCode
        IsSuccess      = ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300)
        BodySupplied   = $PSBoundParameters.ContainsKey('Body')
        BodyPreview    = if ($PSBoundParameters.ContainsKey('Body')) { ConvertTo-ContentPreview -Value $Body } else { $null }
        ContentPreview = ConvertTo-ContentPreview -Value $content
    }
}

function Invoke-SettingsWriteProbe {
    param (
        [Parameter(Mandatory)]
        [pscustomobject]$Candidate
    )

    $currentProbe = Invoke-PortalProbe -Label ("{0}-Get" -f $Candidate.Name) -Path $Candidate.Path -Method 'Get' -Headers $Candidate.Headers
    $currentPayload = $null
    $currentError = $null

    if ($currentProbe.IsSuccess) {
        try {
            $currentPayload = Invoke-M365AdminRestMethod -Path $Candidate.Path -Method Get -Headers $Candidate.Headers
        }
        catch {
            $currentError = $_.Exception.Message
        }
    }
    else {
        $currentError = 'Current payload retrieval failed.'
    }

    $probeResults = @()
    if ($null -ne $currentPayload) {
        foreach ($method in @($Candidate.Methods)) {
            $label = '{0}-{1}-FullPayload' -f $Candidate.Name, $method
            try {
                $result = Invoke-PortalProbe -Label $label -Path $Candidate.Path -Method $method -Headers $Candidate.Headers -Body $currentPayload
                Add-RunLog ("- Probe {0}: {1} {2} -> {3}" -f $result.Label, $result.Method.ToUpperInvariant(), $result.Path, $result.StatusCode)
                if (-not [string]::IsNullOrWhiteSpace([string]$result.ContentPreview)) {
                    Add-RunLog ("  Response preview: {0}" -f $result.ContentPreview)
                }
                $probeResults += $result
            }
            catch {
                $result = [pscustomobject]@{
                    Label          = $label
                    Path           = $Candidate.Path
                    Method         = $method
                    StatusCode     = $null
                    IsSuccess      = $false
                    BodySupplied   = $true
                    BodyPreview    = ConvertTo-ContentPreview -Value $currentPayload
                    ContentPreview = $_.Exception.Message
                }
                Add-RunLog ("- Probe {0}: {1} {2} -> error" -f $result.Label, $result.Method.ToUpperInvariant(), $result.Path)
                Add-RunLog ("  Response preview: {0}" -f $result.ContentPreview)
                $probeResults += $result
            }
        }
    }
    else {
        Add-RunLog ("- Skipped write probes for {0}: current payload was unavailable. {1}" -f $Candidate.Name, $currentError)
    }

    [pscustomobject]@{
        Name           = $Candidate.Name
        Path           = $Candidate.Path
        Headers        = $Candidate.Headers
        CurrentProbe   = $currentProbe
        CurrentError   = $currentError
        CurrentPayload = $currentPayload
        ProbeResults   = $probeResults
    }
}

$tenantId = Get-ResolvedTenantId

$candidateDefinitions = @(
    [pscustomobject]@{ Name = 'CompanyHelpDesk'; Path = '/admin/api/Settings/company/helpdesk'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'CompanyProfile'; Path = '/admin/api/Settings/company/profile'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'CompanyReleaseTrack'; Path = '/admin/api/Settings/company/releasetrack'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'CompanySendFromAddress'; Path = '/admin/api/Settings/company/sendfromaddress'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'CompanyTheme'; Path = '/admin/api/Settings/company/theme/v2'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'CompanyTile'; Path = '/admin/api/Settings/company/tile'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'ContentUnderstandingSetting'; Path = '/admin/api/contentunderstanding/setting'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecurityActivityBasedTimeout'; Path = '/admin/api/settings/security/activitybasedtimeout'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecurityBingDataCollection'; Path = '/admin/api/settings/security/bingdatacollection'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecurityDataAccess'; Path = '/admin/api/settings/security/dataaccess'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecurityGuestUserPolicy'; Path = '/admin/api/Settings/security/guestUserPolicy'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecurityMultiFactorAuth'; Path = '/admin/api/settings/security/multifactorauth'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecurityO365GuestUser'; Path = '/admin/api/settings/security/o365guestuser'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecurityPasswordPolicy'; Path = '/admin/api/Settings/security/passwordpolicy'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecurityPrivacyPolicy'; Path = '/admin/api/Settings/security/privacypolicy'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecurityTenantLockbox'; Path = '/admin/api/Settings/security/tenantLockbox'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecurityDefaults'; Path = '/admin/api/identitysecurity/securitydefaults'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecuritySettings'; Path = '/admin/api/securitysettings/settings'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SecuritySettingsOptIn'; Path = '/admin/api/securitysettings/optIn'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'PeopleNamePronunciation'; Path = ('/fd/peopleadminservice/{0}/settings/namePronunciation' -f $tenantId); Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'PeoplePronouns'; Path = ('/fd/peopleadminservice/{0}/settings/pronouns' -f $tenantId); Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'PeopleProfileCardProperties'; Path = ('/fd/peopleadminservice/{0}/profilecard/properties' -f $tenantId); Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'SelfServicePurchaseProducts'; Path = '/admin/api/selfServicePurchasePolicy/products'; Methods = @('Post', 'Put', 'Patch'); Headers = $null },
    [pscustomobject]@{ Name = 'TenantReportsPrivacyEnabled'; Path = '/admin/api/tenant/isReportsPrivacyEnabled'; Methods = @('Post', 'Put', 'Patch'); Headers = $null }
)

$results = foreach ($candidate in $candidateDefinitions) {
    Invoke-SettingsWriteProbe -Candidate $candidate
}

$summary = [pscustomobject]@{
    ProbedAt = (Get-Date).ToUniversalTime().ToString('o')
    Results  = $results
}

$summary | ConvertTo-Json -Depth 30 | Set-Content -Path $resultPath
$summary | ConvertTo-Json -Depth 10