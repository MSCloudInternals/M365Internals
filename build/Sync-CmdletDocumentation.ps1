[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 1.0

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

$repoRoot = (Resolve-Path -Path $RepositoryRoot).Path
$moduleRoot = Join-Path $repoRoot 'M365Internals'
$functionsPath = Join-Path $moduleRoot 'functions'
$internalFunctionsPath = Join-Path (Join-Path $moduleRoot 'internal') 'functions'
$internalScriptsPath = Join-Path (Join-Path $moduleRoot 'internal') 'scripts'
$rootReadmePath = Join-Path $repoRoot 'README.md'
$moduleReadmePath = Join-Path $moduleRoot 'README.md'
$manifestPath = Join-Path $moduleRoot 'M365Internals.psd1'
$mappingSeedPath = Join-Path (Join-Path $repoRoot 'M365Ray') 'CmdletApiMapping.json'
$mappingPaths = @(
    $mappingSeedPath,
    (Join-Path (Join-Path $repoRoot 'M365Ray Firefox') 'CmdletApiMapping.json')
)
$trackedPrefixPaths = @(
    (Join-Path (Join-Path $repoRoot 'M365Ray') 'TrackedRequestPrefixes.json'),
    (Join-Path (Join-Path $repoRoot 'M365Ray Firefox') 'TrackedRequestPrefixes.json')
)
$surfaceRegistryHelperPath = Join-Path $PSScriptRoot 'PortalSurfaceRegistry.ps1'

$script:SyncTenantId = '11111111-1111-1111-1111-111111111111'
$script:SyncSubscriptionId = '22222222-2222-2222-2222-222222222222'
$script:SyncTraceEntries = [System.Collections.Generic.List[object]]::new()
$script:SyncTraceContext = $null
$script:InternalPlaceholderMap = [ordered]@{
    $script:SyncTenantId = 'TenantId'
    $script:SyncSubscriptionId = 'SubscriptionId'
}

. $surfaceRegistryHelperPath

foreach ($file in Get-ChildItem -Path $internalFunctionsPath -Filter '*.ps1' -Recurse) {
    . $file.FullName
}

foreach ($file in Get-ChildItem -Path (Join-Path $moduleRoot 'functions') -Filter '*.ps1' -Recurse) {
    . $file.FullName
}

foreach ($file in Get-ChildItem -Path $internalScriptsPath -Filter '*.ps1' -Recurse) {
    . $file.FullName
}

function Write-TextFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content
    )

    $encoding = Get-TargetFileEncoding -Path $Path

    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-TargetFileEncoding {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -Path $Path) {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        if (($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)) {
            return [System.Text.UTF8Encoding]::new($true)
        }
    }

    $extension = [System.IO.Path]::GetExtension($Path)
    if ($extension -in @('.ps1', '.psd1', '.psm1', '.ps1xml')) {
        return [System.Text.UTF8Encoding]::new($true)
    }

    return [System.Text.UTF8Encoding]::new($false)
}

function Copy-OrderedMap {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$InputObject
    )

    $copy = [ordered]@{}
    foreach ($key in $InputObject.Keys) {
        $copy[$key] = $InputObject[$key]
    }

    return $copy
}

function ConvertTo-OrderedData {
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return $null
        }

        if ($InputObject -is [System.Collections.IDictionary]) {
            $ordered = [ordered]@{}
            foreach ($key in $InputObject.Keys) {
                $ordered[$key] = ConvertTo-OrderedData -InputObject $InputObject[$key]
            }

            return $ordered
        }

        if ($InputObject -is [pscustomobject]) {
            $ordered = [ordered]@{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $ordered[$property.Name] = ConvertTo-OrderedData -InputObject $property.Value
            }

            return $ordered
        }

        if (($InputObject -is [System.Collections.IEnumerable]) -and -not ($InputObject -is [string])) {
            $items = @()
            foreach ($item in $InputObject) {
                $items += ,(ConvertTo-OrderedData -InputObject $item)
            }

            return ,$items
        }

        return $InputObject
    }
}

function Get-Newline {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    if ($Content.Contains("`r`n")) {
        return "`r`n"
    }

    return "`n"
}

function Get-CmdletSynopsis {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $match = [regex]::Match($Content, '(?ms)\.SYNOPSIS\s*(.+?)(?=\r?\n\s*\.[A-Z]+|\r?\n\s*\r?\n)')
    if (-not $match.Success) {
        return ''
    }

    return (($match.Groups[1].Value -replace '\r?\n\s*', ' ') -replace '\s{2,}', ' ').Trim()
}

function Get-PublicCmdletMetadata {
    $metadata = foreach ($file in Get-ChildItem -Path $functionsPath -Filter '*.ps1' | Sort-Object Name) {
        $content = Get-Content -Path $file.FullName -Raw
        $nameMatch = [regex]::Match($content, 'function\s+([A-Za-z0-9-]+)\s*\{')
        if (-not $nameMatch.Success) {
            Write-Warning "Skipping '$($file.Name)' because the function name could not be determined."
            continue
        }

        [pscustomobject]@{
            Name     = $nameMatch.Groups[1].Value
            Synopsis = Get-CmdletSynopsis -Content $content
            FilePath = $file.FullName
        }
    }

    return @($metadata | Sort-Object Name)
}

function Get-ExistingReadmeCmdletDescriptions {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $descriptions = @{}
    foreach ($line in $Lines) {
        if ($line -match '^\|\s*Cmdlet\s*\|') {
            continue
        }

        if ($line -match '^\|\s*[-: ]+\|\s*[-: ]+\|$') {
            continue
        }

        $match = [regex]::Match($line, '^\|\s*(?<Cmdlet>[^|]+?)\s*\|\s*(?<Description>.+?)\s*\|$')
        if (-not $match.Success) {
            continue
        }

        $cmdletName = $match.Groups['Cmdlet'].Value.Trim()
        $description = $match.Groups['Description'].Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($cmdletName)) {
            $descriptions[$cmdletName] = $description
        }
    }

    return $descriptions
}

function Get-ReadmeCmdletGroups {
    param(
        [Parameter(Mandatory)]
        [object[]]$Cmdlets
    )

    $groupDefinitions = @(Get-M365AdminCommandCatalogGroupDefinitions | Sort-Object Order)
    $groupMap = @{}

    foreach ($groupDefinition in $groupDefinitions) {
        $groupMap[$groupDefinition.Name] = [System.Collections.Generic.List[object]]::new()
    }

    foreach ($cmdlet in $Cmdlets | Sort-Object Name) {
        $groupName = Get-M365AdminCommandCatalogGroupName -CmdletName $cmdlet.Name
        if (-not $groupMap.ContainsKey($groupName)) {
            $groupMap[$groupName] = [System.Collections.Generic.List[object]]::new()
        }

        $groupMap[$groupName].Add($cmdlet) | Out-Null
    }

    $orderedGroups = [System.Collections.Generic.List[object]]::new()
    foreach ($groupDefinition in $groupDefinitions) {
        if (-not $groupMap.ContainsKey($groupDefinition.Name) -or $groupMap[$groupDefinition.Name].Count -eq 0) {
            continue
        }

        $orderedGroups.Add([pscustomobject]@{
            Name = $groupDefinition.Name
            Title = $groupDefinition.Title
            Description = $groupDefinition.Description
            Cmdlets = @($groupMap[$groupDefinition.Name] | Sort-Object Name)
        }) | Out-Null
    }

    return @($orderedGroups)
}

function Update-ReadmeCmdletTable {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object[]]$Cmdlets
    )

    $content = Get-Content -Path $Path -Raw
    $newLine = Get-Newline -Content $content
    $trimmedContent = $content.TrimEnd("`r", "`n")
    $lines = [regex]::Split($trimmedContent, '\r?\n')
    $startIndex = [Array]::IndexOf($lines, '## Available Cmdlets')
    if ($startIndex -lt 0) {
        Write-Warning "Could not find an 'Available Cmdlets' section in '$Path'."
        return $false
    }

    $endIndex = $lines.Count
    for ($index = $startIndex + 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^##\s') {
            $endIndex = $index
            break
        }
    }

    $existingSectionLines = if ($endIndex -gt ($startIndex + 1)) {
        $lines[($startIndex + 1)..($endIndex - 1)]
    }
    else {
        @()
    }
    $existingDescriptions = Get-ExistingReadmeCmdletDescriptions -Lines $existingSectionLines

    $sectionLines = @(
        '## Available Cmdlets'
        ''
    )

    foreach ($group in Get-ReadmeCmdletGroups -Cmdlets $Cmdlets) {
        $sectionLines += "### $($group.Title)"
        $sectionLines += ''
        if (-not [string]::IsNullOrWhiteSpace($group.Description)) {
            $sectionLines += $group.Description
            $sectionLines += ''
        }
        $sectionLines += '| Cmdlet | Description |'
        $sectionLines += '| --- | --- |'

        foreach ($cmdlet in $group.Cmdlets) {
            $description = if ($existingDescriptions.ContainsKey($cmdlet.Name) -and -not [string]::IsNullOrWhiteSpace($existingDescriptions[$cmdlet.Name])) {
                $existingDescriptions[$cmdlet.Name]
            }
            elseif ([string]::IsNullOrWhiteSpace($cmdlet.Synopsis)) {
                'TODO: Add description'
            }
            else {
                $cmdlet.Synopsis
            }

            $sectionLines += ('| {0} | {1} |' -f $cmdlet.Name, $description)
        }

        $sectionLines += ''
    }

    $updatedLines = @()
    if ($startIndex -gt 0) {
        $updatedLines += $lines[0..($startIndex - 1)]
    }
    $updatedLines += $sectionLines
    if ($endIndex -lt $lines.Count) {
        $updatedLines += $lines[$endIndex..($lines.Count - 1)]
    }

    $updatedContent = ($updatedLines -join $newLine)
    if ($content.EndsWith("`r`n") -or $content.EndsWith("`n")) {
        $updatedContent += $newLine
    }
    if ($updatedContent -ceq $content) {
        return $false
    }

    Write-TextFile -Path $Path -Content $updatedContent

    return $true
}

function Update-FunctionsToExport {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object[]]$Cmdlets
    )

    $content = Get-Content -Path $Path -Raw
    $newLine = Get-Newline -Content $content
    $items = @($Cmdlets.Name | Sort-Object)
    $exportLines = @('    FunctionsToExport = @(')
    for ($index = 0; $index -lt $items.Count; $index++) {
        $suffix = if ($index -lt ($items.Count - 1)) { ',' } else { '' }
        $exportLines += "        '$($items[$index])'$suffix"
    }
    $exportLines += '    )'
    $newExportBlock = $exportLines -join $newLine

    $pattern = '(?ms)^\s*FunctionsToExport\s*=\s*@\(.+?\)\s*\r?\n\r?\n(\s*PrivateData\s*=\s*@\{)'
    $replacement = $newExportBlock + $newLine + $newLine + '$1'
    $updatedContent = [regex]::Replace($content, $pattern, $replacement, 1)
    if ($updatedContent -ceq $content) {
        return $false
    }

    Write-TextFile -Path $Path -Content $updatedContent

    return $true
}

function Get-ValidateSetValues {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ParameterMetadata]$ParameterMetadata
    )

    foreach ($attribute in $ParameterMetadata.Attributes) {
        if ($attribute -is [System.Management.Automation.ValidateSetAttribute]) {
            return @($attribute.ValidValues)
        }
    }

    return @()
}

function Get-SampleParameterValue {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ParameterMetadata]$ParameterMetadata
    )

    $validateSetValues = Get-ValidateSetValues -ParameterMetadata $ParameterMetadata
    if ($validateSetValues.Count -gt 0) {
        if ($ParameterMetadata.ParameterType -eq [switch]) {
            return $true
        }

        $value = $validateSetValues[0]
        if ($ParameterMetadata.ParameterType -eq [int]) {
            return [int]$value
        }

        return $value
    }

    switch ($ParameterMetadata.Name) {
        'CardCategory' { return 'Overview' }
        'Culture' { return 'en-US' }
        'DomainName' { return 'contoso.com' }
        'TokenAudience' { return 'https://graph.microsoft.com' }
    }

    if ($ParameterMetadata.ParameterType -eq [string]) {
        return 'SampleValue'
    }

    if ($ParameterMetadata.ParameterType -eq [int]) {
        return 1
    }

    if ($ParameterMetadata.ParameterType -eq [long]) {
        return [long]1
    }

    if ($ParameterMetadata.ParameterType -eq [bool]) {
        return $true
    }

    if ($ParameterMetadata.ParameterType -eq [switch]) {
        return $true
    }

    if ($ParameterMetadata.ParameterType -eq [hashtable]) {
        return @{ Enabled = $true }
    }

    if ($ParameterMetadata.ParameterType -eq [string[]]) {
        return @('SampleValue')
    }

    if ($ParameterMetadata.ParameterType -eq [datetime]) {
        return [datetime]'2026-01-01T00:00:00Z'
    }

    return 'SampleValue'
}

function Get-RepresentativeInvocations {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.CommandInfo]$CommandInfo
    )

    $commonNames = @(
        'Debug', 'ErrorAction', 'ErrorVariable', 'Force', 'InformationAction', 'InformationVariable',
        'OutBuffer', 'OutVariable', 'PipelineVariable', 'ProgressAction', 'Raw', 'RawJson', 'Verbose',
        'WarningAction', 'WarningVariable', 'WhatIf', 'Confirm', 'PassThru'
    )

    $invocations = [System.Collections.Generic.List[hashtable]]::new()

    if ($CommandInfo.Parameters.ContainsKey('Name')) {
        $nameValues = Get-ValidateSetValues -ParameterMetadata $CommandInfo.Parameters['Name']
        if ($nameValues.Count -gt 0) {
            foreach ($nameValue in $nameValues) {
                $parameters = [ordered]@{ Name = $nameValue }
                foreach ($parameterSet in $CommandInfo.ParameterSets) {
                    if (-not ($parameterSet.Parameters | Where-Object Name -EQ 'Name')) {
                        continue
                    }

                    foreach ($parameter in $parameterSet.Parameters | Where-Object IsMandatory) {
                        if ($parameter.Name -in $commonNames) {
                            continue
                        }

                        if (-not $parameters.Contains($parameter.Name)) {
                            $parameters[$parameter.Name] = Get-SampleParameterValue -ParameterMetadata $CommandInfo.Parameters[$parameter.Name]
                        }
                    }
                }

                if ($CommandInfo.Parameters.ContainsKey('Force')) {
                    $parameters['Force'] = $true
                }

                $invocations.Add((Copy-OrderedMap -InputObject $parameters))
            }
        }

        return @($invocations)
    }

    $defaultParameterSetName = $CommandInfo.DefaultParameterSet
    if ([string]::IsNullOrWhiteSpace($defaultParameterSetName)) {
        $defaultSet = $CommandInfo.ParameterSets | Where-Object IsDefault | Select-Object -First 1
        if ($null -ne $defaultSet) {
            $defaultParameterSetName = $defaultSet.Name
        }
    }

    foreach ($parameterSet in $CommandInfo.ParameterSets) {
        if ($parameterSet.Name -eq '__AllParameterSets') {
            continue
        }

        $parameters = [ordered]@{}
        if ($parameterSet.Name -ne $defaultParameterSetName) {
            $selector = $parameterSet.Parameters |
                Where-Object {
                    ($_.ParameterType -eq [switch]) -and
                    ($_.Name -notin $commonNames) -and
                    (($_.Name -eq $parameterSet.Name) -or (-not $_.IsMandatory))
                } |
                Select-Object -First 1
            if ($null -ne $selector) {
                $parameters[$selector.Name] = $true
            }
        }

        foreach ($parameter in $parameterSet.Parameters | Where-Object IsMandatory) {
            if ($parameter.Name -in $commonNames) {
                continue
            }

            if (-not $parameters.Contains($parameter.Name)) {
                $parameters[$parameter.Name] = Get-SampleParameterValue -ParameterMetadata $CommandInfo.Parameters[$parameter.Name]
            }
        }

        if ($CommandInfo.Parameters.ContainsKey('Force')) {
            $parameters['Force'] = $true
        }

        $invocations.Add((Copy-OrderedMap -InputObject $parameters))
    }

    if ($invocations.Count -eq 0) {
        $parameters = [ordered]@{}
        if ($CommandInfo.Parameters.ContainsKey('Force')) {
            $parameters['Force'] = $true
        }

        $invocations.Add((Copy-OrderedMap -InputObject $parameters))
    }

    return @($invocations)
}

function Get-StubPayload {
    return [pscustomobject]@{
        value = @(
            [pscustomobject]@{
                subscriptionId = $script:SyncSubscriptionId
                displayName    = 'Contoso'
                id             = 'sample-id'
                name           = 'Contoso'
            }
        )
        Enabled       = $true
        Count         = 1
        ObjectId      = $script:SyncTenantId
        UserInfo      = [pscustomobject]@{ ObjectId = $script:SyncTenantId }
        '@odata.count' = 1
    }
}

function Add-SyncTraceEntry {
    param(
        [string]$Path,
        [string]$Uri,
        [string]$Method = 'Get',
        $Body,
        [hashtable]$Headers,
        [switch]$RawResponse
    )

    $resolvedUri = if (-not [string]::IsNullOrWhiteSpace($Uri)) {
        $Uri
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Path)) {
        if ($Path -match '^https?://') {
            $Path
        }
        else {
            "https://admin.cloud.microsoft$Path"
        }
    }
    else {
        $null
    }

    if (($null -ne $script:SyncTraceContext) -and -not [string]::IsNullOrWhiteSpace($resolvedUri)) {
        $script:SyncTraceEntries.Add([pscustomobject]@{
            Cmdlet     = $script:SyncTraceContext.Cmdlet
            Parameters = Copy-OrderedMap -InputObject $script:SyncTraceContext.Parameters
            Uri        = $resolvedUri
            Method     = $Method.ToUpperInvariant()
            Body       = $Body
            Headers    = $Headers
        }) | Out-Null
    }

    $payload = Get-StubPayload
    if ($RawResponse) {
        return [pscustomobject]@{ Content = ($payload | ConvertTo-Json -Depth 20) }
    }

    return $payload
}

function Initialize-TraceSandbox {
    function Get-M365AdminPortalData {
        param(
            [string]$Path,
            [string]$Uri,
            [string]$Method = 'Get',
            $Body,
            [hashtable]$Headers,
            [string]$ContentType,
            [string]$CacheKey,
            [switch]$Force
        )

        return Add-SyncTraceEntry -Path $Path -Uri $Uri -Method $Method -Body $Body -Headers $Headers
    }

    function Invoke-M365AdminRestMethod {
        param(
            [string]$Uri,
            [string]$Path,
            [string]$Method = 'Get',
            [string]$ContentType = 'application/json',
            [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
            [hashtable]$Headers,
            $Body
        )

        return Add-SyncTraceEntry -Path $Path -Uri $Uri -Method $Method -Body $Body -Headers $Headers
    }

    function Invoke-M365PortalRequest {
        param(
            [string]$Path,
            [string]$Uri,
            [string]$Method = 'Get',
            [hashtable]$Headers,
            $Body,
            [string]$ContentType,
            [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
            [switch]$RawResponse
        )

        return Add-SyncTraceEntry -Path $Path -Uri $Uri -Method $Method -Body $Body -Headers $Headers -RawResponse:$RawResponse
    }

    function Invoke-M365AdminGraphRequest {
        param(
            [string]$Path,
            [string]$Uri,
            [string]$Method = 'Get',
            [string]$AdminAppRequest,
            [hashtable]$Headers,
            $Body,
            [string]$ContentType,
            [switch]$IncludeAuthorizationHeader,
            [string]$GraphScenario
        )

        return Add-SyncTraceEntry -Path $Path -Uri $Uri -Method $Method -Body $Body -Headers $Headers
    }

    function Get-M365PortalTenantId {
        return $script:SyncTenantId
    }

    function Get-M365PortalContextHeaders {
        param([string]$Context)
        return @{}
    }

    function Update-M365PortalConnectionSettings {
    }

    function Set-M365PortalConnectionSettings {
        param()
        return [pscustomobject]@{}
    }

    function Clear-M365Cache {
        param()
    }

    function Set-M365Cache {
        param()
        return $null
    }

    function Get-M365Cache {
        param()
        return $null
    }

    function Merge-M365AdminSettingsPayload {
        param(
            $CurrentSettings,
            [hashtable]$Settings
        )

        return $Settings
    }

    function Resolve-M365AdminOutput {
        param(
            $DefaultValue,
            $RawValue,
            [switch]$Raw,
            [switch]$RawJson
        )

        if ($Raw.IsPresent -and $PSBoundParameters.ContainsKey('RawValue')) {
            return $RawValue
        }

        if ($RawJson.IsPresent) {
            $value = if ($PSBoundParameters.ContainsKey('RawValue')) { $RawValue } else { $DefaultValue }
            return $value | ConvertTo-Json -Depth 20
        }

        return $DefaultValue
    }

    function Add-M365TypeName {
        param($InputObject, [string]$TypeName)
        return $InputObject
    }

    function Add-SecuritySettingTypeName {
        param($InputObject, [string]$SectionName)
        return $InputObject
    }

    function Add-SearchSettingTypeName {
        param($InputObject, [string]$SectionName)
        return $InputObject
    }

    function ConvertTo-EdgeDeviceSummary {
        param($DeviceResult)
        return [pscustomobject]@{ Total = 1 }
    }

    function Get-CacheToken {
        param($Value)
        if ([string]::IsNullOrWhiteSpace([string]$Value)) {
            return 'none'
        }

        return (([string]$Value) -replace '[^A-Za-z0-9-]', '_')
    }

    function New-M365AdminUnavailableResult {
        param(
            [string]$Name,
            [string]$Description,
            [string]$Reason,
            [string]$ErrorMessage,
            [string]$SuggestedAction
        )

        return [pscustomobject]@{
            Name           = $Name
            Description    = $Description
            Reason         = $Reason
            ErrorMessage   = $ErrorMessage
            SuggestedAction = $SuggestedAction
        }
    }

    function New-M365AdminUnavailableResultFromError {
        param(
            [string]$Name,
            [string]$Area,
            [string]$DefaultDescription,
            [string]$ErrorMessage
        )

        return [pscustomobject]@{
            Name         = $Name
            Area         = $Area
            Description  = $DefaultDescription
            ErrorMessage = $ErrorMessage
        }
    }
}

function Get-QueryPairs {
    param(
        [Parameter(Mandatory)]
        [string]$UriText
    )

    $queryIndex = $UriText.IndexOf('?')
    if ($queryIndex -lt 0) {
        return @()
    }

    $queryText = $UriText.Substring($queryIndex + 1)
    $fragmentIndex = $queryText.IndexOf('#')
    if ($fragmentIndex -ge 0) {
        $queryText = $queryText.Substring(0, $fragmentIndex)
    }

    $pairs = foreach ($segment in $queryText.Split('&', [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $parts = $segment.Split('=', 2)
        [pscustomobject]@{
            Name     = [uri]::UnescapeDataString($parts[0])
            RawName  = $parts[0]
            RawValue = if ($parts.Count -gt 1) { $parts[1] } else { '' }
            Value    = if ($parts.Count -gt 1) { [uri]::UnescapeDataString($parts[1]) } else { '' }
        }
    }

    return @($pairs)
}

function Set-QueryPlaceholder {
    param(
        [Parameter(Mandatory)]
        [string]$UriText,

        [Parameter(Mandatory)]
        [string]$QueryName,

        [Parameter(Mandatory)]
        [string]$Placeholder
    )

    $queryIndex = $UriText.IndexOf('?')
    if ($queryIndex -lt 0) {
        return $UriText
    }

    $base = $UriText.Substring(0, $queryIndex)
    $queryText = $UriText.Substring($queryIndex + 1)
    $fragment = ''
    $fragmentIndex = $queryText.IndexOf('#')
    if ($fragmentIndex -ge 0) {
        $fragment = $queryText.Substring($fragmentIndex)
        $queryText = $queryText.Substring(0, $fragmentIndex)
    }

    $didReplace = $false
    $segments = foreach ($segment in $queryText.Split('&', [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $parts = $segment.Split('=', 2)
        $decodedName = [uri]::UnescapeDataString($parts[0])
        if (-not $didReplace -and $decodedName -eq $QueryName) {
            $didReplace = $true
            "$($parts[0])=$Placeholder"
        }
        else {
            $segment
        }
    }

    return $base + '?' + ($segments -join '&') + $fragment
}

function ConvertTo-NormalizedNameToken {
    param([string]$Value)

    return (($Value -replace '[^A-Za-z0-9]', '').ToLowerInvariant())
}

function ConvertTo-PlaceholderName {
    param([string]$Name)

    $tokens = [regex]::Matches($Name, '[A-Za-z0-9]+') | ForEach-Object Value
    if ($tokens.Count -eq 0) {
        return 'Value'
    }

    return (($tokens | ForEach-Object {
        if ($_.Length -eq 1) {
            $_.ToUpperInvariant()
        }
        else {
            $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1)
        }
    }) -join '')
}

function Test-QueryParameterMatch {
    param(
        [string]$ParameterName,
        [string]$QueryName
    )

    $parameterToken = ConvertTo-NormalizedNameToken -Value $ParameterName
    $queryToken = ConvertTo-NormalizedNameToken -Value $QueryName
    return ($parameterToken -eq $queryToken) -or ($queryToken.StartsWith($parameterToken)) -or ($parameterToken.StartsWith($queryToken))
}

function Test-FixedOnlyParameters {
    param($Parameters)

    if ($null -eq $Parameters) {
        return $false
    }

    $parameterKeys = @($Parameters.Keys)
    if ($parameterKeys.Count -eq 0) {
        return $false
    }

    foreach ($key in $parameterKeys) {
        if (-not ([string]$Parameters[$key]).StartsWith('fixed:')) {
            return $false
        }
    }

    return $true
}

function Set-InternalQueryPlaceholders {
    param(
        [Parameter(Mandatory)]
        [string]$UriText,

        $Parameters
    )

    $publicQueryNames = @()
    if ($null -ne $Parameters) {
        foreach ($key in $Parameters.Keys) {
            $source = [string]$Parameters[$key]
            if ($source.StartsWith('query:')) {
                $publicQueryNames += $source.Substring(6)
            }
        }
    }

    foreach ($pair in Get-QueryPairs -UriText $UriText) {
        if ($pair.Name -in $publicQueryNames) {
            continue
        }

        $placeholderName = $null
        if ($pair.Name -match '^(tenantId|subscriptionId|startTime|endTime|fromDate|toDate)$') {
            $placeholderName = ConvertTo-PlaceholderName -Name $pair.Name
        }
        elseif (($pair.Name -match 'time|date') -and ($pair.Value -match '^\d{4}-\d{2}-\d{2}(?:T.*)?$')) {
            $placeholderName = ConvertTo-PlaceholderName -Name $pair.Name
        }
        elseif (($pair.Name -match 'tenant|subscription|id') -and ($pair.Value -match '^[0-9a-fA-F]{8}-[0-9a-fA-F-]{27}$')) {
            $placeholderName = ConvertTo-PlaceholderName -Name $pair.Name
        }

        if (-not [string]::IsNullOrWhiteSpace($placeholderName)) {
            $UriText = Set-QueryPlaceholder -UriText $UriText -QueryName $pair.Name -Placeholder "{$placeholderName}"
        }
    }

    return $UriText
}

function Get-MappingScore {
    param($Mapping)

    $score = 0
    if ($null -ne $Mapping.Parameters) {
        foreach ($key in $Mapping.Parameters.Keys) {
            $source = [string]$Mapping.Parameters[$key]
            if ($source.StartsWith('query:') -or $source.StartsWith('route:') -or $source.StartsWith('body:') -or $source.StartsWith('header:')) {
                $score += 10
            }
            else {
                $score += 2
            }
        }
    }

    if ($null -ne $Mapping.SwitchParameters) {
        $score += @($Mapping.SwitchParameters).Count
    }

    if (($null -eq $Mapping.Parameters) -and ($null -eq $Mapping.SwitchParameters)) {
        return 1
    }

    return $score
}

function Get-MappingKey {
    param($Mapping)

    return '{0}|{1}' -f $Mapping.Cmdlet, $Mapping.ApiUri
}

function Convert-TraceToMapping {
    param(
        [Parameter(Mandatory)]
        $Trace,

        [Parameter(Mandatory)]
        [System.Management.Automation.CommandInfo]$CommandInfo
    )

    $uriText = [string]$Trace.Uri
    $parameters = [ordered]@{}
    $switchParameters = [System.Collections.Generic.List[string]]::new()
    $ignoredParameterNames = @('Force', 'Raw', 'RawJson', 'PassThru')

    foreach ($entry in $Trace.Parameters.GetEnumerator()) {
        $parameterName = [string]$entry.Key
        if ($parameterName -in $ignoredParameterNames) {
            continue
        }

        if (-not $CommandInfo.Parameters.ContainsKey($parameterName)) {
            continue
        }

        $metadata = $CommandInfo.Parameters[$parameterName]
        $value = $entry.Value
        if ($metadata.ParameterType -eq [switch]) {
            if ([bool]$value) {
                $parameters[$parameterName] = 'fixed:true'
                $switchParameters.Add($parameterName) | Out-Null
            }

            continue
        }

        if ($parameterName -eq 'Name') {
            $parameters[$parameterName] = 'fixed:{0}' -f $value
            continue
        }

        if (($value -is [System.Collections.IDictionary]) -or (($value -is [System.Collections.IEnumerable]) -and -not ($value -is [string]))) {
            continue
        }

        $matchedQuery = $null
        foreach ($queryPair in Get-QueryPairs -UriText $uriText) {
            if (Test-QueryParameterMatch -ParameterName $parameterName -QueryName $queryPair.Name) {
                $matchedQuery = $queryPair
                break
            }
        }

        if ($null -ne $matchedQuery) {
            $uriText = Set-QueryPlaceholder -UriText $uriText -QueryName $matchedQuery.Name -Placeholder "{$parameterName}"
            $parameters[$parameterName] = 'query:{0}' -f $matchedQuery.Name
            continue
        }

        $scalarValue = [string]$value
        if (-not [string]::IsNullOrWhiteSpace($scalarValue)) {
            $encodedScalarValue = [uri]::EscapeDataString($scalarValue)
            if ($uriText.Contains($encodedScalarValue)) {
                $uriText = $uriText -replace [regex]::Escape($encodedScalarValue), "{$parameterName}"
                $parameters[$parameterName] = 'route:{0}' -f $parameterName
            }
        }
    }

    foreach ($placeholderEntry in $script:InternalPlaceholderMap.GetEnumerator()) {
        $encodedValue = [uri]::EscapeDataString([string]$placeholderEntry.Key)
        $uriText = $uriText -replace [regex]::Escape($encodedValue), "{$($placeholderEntry.Value)}"
    }
    $uriText = Set-InternalQueryPlaceholders -UriText $uriText -Parameters $parameters

    $mapping = [ordered]@{
        Cmdlet = $Trace.Cmdlet
        ApiUri = $uriText
    }
    if ($Trace.Method -and $Trace.Method -ne 'GET') {
        $mapping.Method = $Trace.Method
    }
    if ($parameters.Count -gt 0) {
        $mapping.Parameters = $parameters
    }
    if ($switchParameters.Count -gt 0) {
        $mapping.SwitchParameters = [string[]]@($switchParameters | Sort-Object -Unique)
    }

    return $mapping
}

function Merge-MappingEntry {
    param(
        $Existing,
        $Generated
    )

    $result = [ordered]@{
        Cmdlet = $Generated.Cmdlet
        ApiUri = $Generated.ApiUri
    }

    if ($Existing.Contains('Method')) {
        $result.Method = $Existing.Method
    }
    elseif ($Generated.Contains('Method')) {
        $result.Method = $Generated.Method
    }

    $generatedParameters = if ($Generated.Contains('Parameters')) { $Generated.Parameters } else { $null }
    $existingParameters = if ($Existing.Contains('Parameters')) { $Existing.Parameters } else { $null }
    $includeGeneratedParameters = $true
    if (($null -eq $existingParameters) -and (Test-FixedOnlyParameters -Parameters $generatedParameters)) {
        $includeGeneratedParameters = $false
    }

    $parameterMap = [ordered]@{}
    if ($null -ne $existingParameters) {
        foreach ($key in $existingParameters.Keys) {
            $parameterMap[$key] = $existingParameters[$key]
        }
    }
    if ($includeGeneratedParameters -and $null -ne $generatedParameters) {
        foreach ($key in $generatedParameters.Keys) {
            $parameterMap[$key] = $generatedParameters[$key]
        }
    }
    if ($parameterMap.Count -gt 0) {
        $result.Parameters = $parameterMap
    }

    $switchParameterValues = @()
    if ($Existing.Contains('SwitchParameters')) {
        $switchParameterValues += @($Existing.SwitchParameters)
    }
    if ($includeGeneratedParameters -and $Generated.Contains('SwitchParameters')) {
        foreach ($switchParameter in @($Generated.SwitchParameters)) {
            if ($switchParameter -notin $switchParameterValues) {
                $switchParameterValues += $switchParameter
            }
        }
    }
    if ($switchParameterValues.Count -gt 0) {
        $result.SwitchParameters = [string[]]@($switchParameterValues)
    }

    if ($Existing.Contains('MatchBodyIncludes')) {
        $result.MatchBodyIncludes = @($Existing.MatchBodyIncludes)
    }

    return $result
}

function Merge-RegistryMappingEntry {
    param(
        [Parameter(Mandatory)]
        $Base,

        [Parameter(Mandatory)]
        $Overlay
    )

    $result = [ordered]@{
        Cmdlet = $Base.Cmdlet
        ApiUri = $Base.ApiUri
    }

    foreach ($propertyName in @('Method', 'Parameters', 'SwitchParameters', 'MatchBodyIncludes')) {
        if ($Overlay.Contains($propertyName)) {
            $result[$propertyName] = ConvertTo-OrderedData -InputObject $Overlay[$propertyName]
        }
        elseif ($Base.Contains($propertyName)) {
            $result[$propertyName] = ConvertTo-OrderedData -InputObject $Base[$propertyName]
        }
    }

    return $result
}

function Get-GeneratedMappings {
    param(
        [Parameter(Mandatory)]
        [object[]]$Cmdlets
    )

    Initialize-TraceSandbox
    $generatedByKey = @{}

    foreach ($cmdlet in $Cmdlets | Where-Object Name -like 'Get-*') {
        $commandInfo = Get-Command -Name $cmdlet.Name -CommandType Function
        foreach ($invocationParameters in Get-RepresentativeInvocations -CommandInfo $commandInfo) {
            $script:SyncTraceContext = [pscustomobject]@{
                Cmdlet     = $commandInfo.Name
                Parameters = Copy-OrderedMap -InputObject $invocationParameters
            }

            $startingIndex = $script:SyncTraceEntries.Count
            try {
                & $commandInfo.Name @invocationParameters | Out-Null
            }
            catch {
            }
            finally {
                $script:SyncTraceContext = $null
            }

            if ($script:SyncTraceEntries.Count -le $startingIndex) {
                continue
            }

            for ($index = $startingIndex; $index -lt $script:SyncTraceEntries.Count; $index++) {
                $mapping = Convert-TraceToMapping -Trace $script:SyncTraceEntries[$index] -CommandInfo $commandInfo
                $mappingKey = Get-MappingKey -Mapping $mapping
                if ($generatedByKey.ContainsKey($mappingKey)) {
                    if ((Get-MappingScore -Mapping $mapping) -gt (Get-MappingScore -Mapping $generatedByKey[$mappingKey])) {
                        $generatedByKey[$mappingKey] = $mapping
                    }
                }
                else {
                    $generatedByKey[$mappingKey] = $mapping
                }
            }
        }
    }

    return $generatedByKey
}

function Update-CmdletApiMappings {
    param(
        [Parameter(Mandatory)]
        [object[]]$Cmdlets
    )

    $generatedByKey = Get-GeneratedMappings -Cmdlets $Cmdlets
    $registryMappings = @(Convert-PortalSurfaceRegistryToCmdletApiMappings -RepositoryRoot $repoRoot)
    $registryByKey = @{}
    foreach ($mapping in $registryMappings) {
        $orderedMapping = ConvertTo-OrderedData -InputObject $mapping
        $registryByKey[(Get-MappingKey -Mapping $orderedMapping)] = $orderedMapping
    }
    $validCmdletNames = @($Cmdlets.Name | Where-Object { $_ -like 'Get-*' })
    $existingMappings = if (Test-Path -Path $mappingSeedPath) {
        @(((Get-Content -Path $mappingSeedPath -Raw).TrimStart([char]0xFEFF) | ConvertFrom-Json))
    }
    else {
        @()
    }

    $existingByKey = @{}
    $existingOrder = [System.Collections.Generic.List[string]]::new()
    $removedCount = 0
    foreach ($mapping in $existingMappings) {
        if ($mapping.Cmdlet -notin $validCmdletNames) {
            $removedCount++
            continue
        }

        $orderedMapping = ConvertTo-OrderedData -InputObject $mapping
        $mappingKey = Get-MappingKey -Mapping $orderedMapping
        if (-not $existingByKey.ContainsKey($mappingKey)) {
            $existingOrder.Add($mappingKey) | Out-Null
        }
        $existingByKey[$mappingKey] = $orderedMapping
    }

    $finalMappings = [System.Collections.Generic.List[object]]::new()
    $handledKeys = New-Object System.Collections.Generic.HashSet[string]
    $newCount = 0
    $updatedCount = 0
    $registryNewCount = 0
    $registryUpdatedCount = 0

    foreach ($mappingKey in $existingOrder) {
        $existing = $existingByKey[$mappingKey]
        if ($generatedByKey.ContainsKey($mappingKey)) {
            $merged = Merge-MappingEntry -Existing $existing -Generated $generatedByKey[$mappingKey]
            $existingJson = (($existing | ConvertTo-Json -Depth 20) -replace '\s+', '')
            $mergedJson = (($merged | ConvertTo-Json -Depth 20) -replace '\s+', '')
            if ($existingJson -cne $mergedJson) {
                $updatedCount++
            }

            $finalMappings.Add($merged) | Out-Null
            $handledKeys.Add($mappingKey) | Out-Null
        }
        else {
            $finalMappings.Add($existing) | Out-Null
        }
    }

    foreach ($mappingKey in @($generatedByKey.Keys | Sort-Object)) {
        if ($handledKeys.Contains($mappingKey)) {
            continue
        }

        $finalMappings.Add($generatedByKey[$mappingKey]) | Out-Null
        $newCount++
    }

    $finalMappingsWithRegistry = [System.Collections.Generic.List[object]]::new()
    $handledRegistryKeys = New-Object System.Collections.Generic.HashSet[string]
    foreach ($mapping in $finalMappings) {
        $mappingKey = Get-MappingKey -Mapping $mapping
        if ($registryByKey.ContainsKey($mappingKey)) {
            $merged = Merge-RegistryMappingEntry -Base $mapping -Overlay $registryByKey[$mappingKey]
            $existingJson = (($mapping | ConvertTo-Json -Depth 20) -replace '\s+', '')
            $mergedJson = (($merged | ConvertTo-Json -Depth 20) -replace '\s+', '')
            if ($existingJson -cne $mergedJson) {
                $registryUpdatedCount++
            }

            $finalMappingsWithRegistry.Add($merged) | Out-Null
            $handledRegistryKeys.Add($mappingKey) | Out-Null
            continue
        }

        $finalMappingsWithRegistry.Add($mapping) | Out-Null
    }

    foreach ($mappingKey in @($registryByKey.Keys | Sort-Object)) {
        if ($handledRegistryKeys.Contains($mappingKey)) {
            continue
        }

        $finalMappingsWithRegistry.Add($registryByKey[$mappingKey]) | Out-Null
        $registryNewCount++
    }

    $jsonContent = ConvertTo-Json -InputObject $finalMappingsWithRegistry.ToArray() -Depth 20
    $comparableJsonContent = ConvertTo-Json -InputObject $finalMappingsWithRegistry.ToArray() -Depth 20 -Compress
    foreach ($path in $mappingPaths) {
        $existingContent = if (Test-Path -Path $path) { Get-Content -Path $path -Raw } else { '' }
        if (-not [string]::IsNullOrWhiteSpace($existingContent)) {
            try {
                $existingComparableJson = ConvertTo-Json -InputObject (ConvertFrom-Json -InputObject $existingContent.TrimStart([char]0xFEFF)) -Depth 20 -Compress
                if ($existingComparableJson -ceq $comparableJsonContent) {
                    continue
                }
            }
            catch {
            }
        }

        if ($existingContent -ceq $jsonContent) {
            continue
        }

        Write-TextFile -Path $path -Content $jsonContent
    }

    Write-Host ("API mappings: {0} total ({1} new, {2} updated, {3} removed)" -f $finalMappingsWithRegistry.Count, ($newCount + $registryNewCount), ($updatedCount + $registryUpdatedCount), $removedCount) -ForegroundColor Green
}

function Update-TrackedRequestPrefixes {
    $trackedPrefixes = @(Get-PortalSurfaceTrackedRequestPrefixes -RepositoryRoot $repoRoot)
    $jsonContent = ConvertTo-Json -InputObject $trackedPrefixes -Depth 5
    $updatedCount = 0

    foreach ($path in $trackedPrefixPaths) {
        $existingContent = if (Test-Path -Path $path) { (Get-Content -Path $path -Raw).TrimStart([char]0xFEFF) } else { '' }
        if ($existingContent -ceq $jsonContent) {
            continue
        }

        Write-TextFile -Path $path -Content $jsonContent
        $updatedCount++
    }

    Write-Host ("Tracked request prefixes: {0} total ({1} file{2} updated)" -f $trackedPrefixes.Count, $updatedCount, $(if ($updatedCount -eq 1) { '' } else { 's' })) -ForegroundColor Green
}

$cmdlets = Get-PublicCmdletMetadata
if ($cmdlets.Count -eq 0) {
    throw "No public cmdlet files were found under '$functionsPath'."
}

Test-PortalSurfaceRegistry -RepositoryRoot $repoRoot -ErrorOnIssue | Out-Null
Write-Host ("Discovered {0} public cmdlets." -f $cmdlets.Count) -ForegroundColor Cyan
$null = Update-ReadmeCmdletTable -Path $rootReadmePath -Cmdlets $cmdlets
$null = Update-ReadmeCmdletTable -Path $moduleReadmePath -Cmdlets $cmdlets
$null = Update-FunctionsToExport -Path $manifestPath -Cmdlets $cmdlets
Update-CmdletApiMappings -Cmdlets $cmdlets
Update-TrackedRequestPrefixes
Write-Host 'Cmdlet documentation synchronization complete.' -ForegroundColor Green
