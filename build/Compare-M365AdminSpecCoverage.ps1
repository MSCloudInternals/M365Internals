param(
    [Parameter()]
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,

    [Parameter()]
    [string]$SpecRoot,

    [Parameter()]
    [string]$OutputDirectory = (Join-Path (Join-Path $RepositoryRoot 'TestResults') 'Artifacts'),

    [Parameter()]
    [switch]$PassThru
)

Set-StrictMode -Version 1.0

function New-M365AdminSpecOperationRecord {
    param(
        [Parameter(Mandatory)]
        [string]$File,

        [Parameter(Mandatory)]
        [string]$PathTemplate,

        [Parameter(Mandatory)]
        [ValidateSet('Get', 'Post', 'Put', 'Patch', 'Delete')]
        [string]$Method,

        [Parameter()]
        [string]$OperationId,

        [Parameter()]
        [string[]]$Tags,

        [Parameter()]
        [string]$CanonicalPath,

        [Parameter()]
        [bool]$PendingSchema
    )

    $effectivePathTemplate = if ([string]::IsNullOrWhiteSpace($CanonicalPath)) {
        $PathTemplate
    }
    else {
        $CanonicalPath
    }

    return [pscustomobject]@{
        File = $File
        PathTemplate = $PathTemplate
        EffectivePathTemplate = $effectivePathTemplate
        Method = $Method
        OperationId = $OperationId
        Tags = @($Tags)
        CanonicalPath = if ([string]::IsNullOrWhiteSpace($CanonicalPath)) { $null } else { $CanonicalPath }
        PendingSchema = $PendingSchema
    }
}

function Get-M365AdminSpecOperations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SpecRoot
    )

    if (-not (Test-Path -LiteralPath $SpecRoot)) {
        throw "Spec root '$SpecRoot' does not exist."
    }

    $operations = [System.Collections.Generic.List[object]]::new()
    $specFiles = @(
        Get-ChildItem -LiteralPath $SpecRoot -Filter *.yml -File |
            Where-Object Name -notin @('openapi.yml', 'common.yml') |
            Sort-Object Name
    )

    foreach ($file in $specFiles) {
        $lines = @(Get-Content -LiteralPath $file.FullName)
        $currentPath = $null
        $currentMethod = $null
        $currentOperationId = $null
        $currentTags = @()
        $currentCanonicalPath = $null
        $currentBlockLines = New-Object System.Collections.Generic.List[string]

        function Add-CurrentOperation {
            if ([string]::IsNullOrWhiteSpace($currentPath) -or [string]::IsNullOrWhiteSpace($currentMethod)) {
                return
            }

            $blockText = @($currentBlockLines.ToArray()) -join [Environment]::NewLine
            $operations.Add((New-M365AdminSpecOperationRecord -File $file.Name -PathTemplate $currentPath -Method $currentMethod -OperationId $currentOperationId -Tags $currentTags -CanonicalPath $currentCanonicalPath -PendingSchema ([bool]($blockText -match 'Exact schema pending|schema pending|pending schema')))) | Out-Null
        }

        foreach ($line in $lines) {
            $pathMatch = [regex]::Match($line, '^\s{2}(?<path>/[^:]+):\s*$')
            if ($pathMatch.Success) {
                Add-CurrentOperation
                $currentPath = [string]$pathMatch.Groups['path'].Value
                $currentMethod = $null
                $currentOperationId = $null
                $currentTags = @()
                $currentCanonicalPath = $null
                $currentBlockLines = New-Object System.Collections.Generic.List[string]
                continue
            }

            $methodMatch = [regex]::Match($line, '^\s{4}(?<method>get|post|put|patch|delete):\s*$')
            if ($methodMatch.Success) {
                Add-CurrentOperation
                $currentMethod = $null
                $currentOperationId = $null
                $currentTags = @()
                $currentCanonicalPath = $null
                $currentBlockLines = New-Object System.Collections.Generic.List[string]
                $currentMethod = ([string]$methodMatch.Groups['method'].Value).Substring(0, 1).ToUpperInvariant() + ([string]$methodMatch.Groups['method'].Value).Substring(1).ToLowerInvariant()
                $currentBlockLines.Add($line) | Out-Null
                continue
            }

            if ([string]::IsNullOrWhiteSpace($currentMethod)) {
                continue
            }

            $currentBlockLines.Add($line) | Out-Null

            $operationIdMatch = [regex]::Match($line, '^\s{6}operationId:\s*(?<value>.+?)\s*$')
            if ($operationIdMatch.Success) {
                $currentOperationId = [string]$operationIdMatch.Groups['value'].Value.Trim()
                continue
            }

            $tagsMatch = [regex]::Match($line, '^\s{6}tags:\s*\[(?<value>.*?)\]\s*$')
            if ($tagsMatch.Success) {
                $currentTags = @(
                    [string]$tagsMatch.Groups['value'].Value -split ',' |
                        ForEach-Object { $_.Trim() } |
                        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                )
                continue
            }

            $canonicalPathMatch = [regex]::Match($line, '^\s{8}canonicalPath:\s*(?<value>/\S+)\s*$')
            if ($canonicalPathMatch.Success) {
                $currentCanonicalPath = [string]$canonicalPathMatch.Groups['value'].Value.Trim()
            }
        }

        Add-CurrentOperation
    }

    return @($operations.ToArray() | Sort-Object File, EffectivePathTemplate, Method, OperationId)
}

function Get-M365AdminSpecCoverageCmdletInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $modulePath = Join-Path $RepositoryRoot 'M365Internals\M365Internals.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
    $module = Get-Module M365Internals -ErrorAction Stop

    return @(
        $module.ExportedCommands.Values |
            Where-Object CommandType -eq 'Function' |
            Sort-Object Name |
            ForEach-Object {
                $nameValues = @()
                if ($_.Parameters.ContainsKey('Name')) {
                    foreach ($attribute in @($_.Parameters['Name'].Attributes)) {
                        if ($attribute -is [System.Management.Automation.ValidateSetAttribute]) {
                            $nameValues += @($attribute.ValidValues)
                        }
                    }
                }

                [pscustomobject]@{
                    Cmdlet = $_.Name
                    Verb = ($_.Name -split '-', 2)[0]
                    NameValues = @($nameValues | Select-Object -Unique)
                    HasForce = $_.Parameters.ContainsKey('Force')
                    HasRaw = $_.Parameters.ContainsKey('Raw')
                    HasRawJson = $_.Parameters.ContainsKey('RawJson')
                }
            }
    )
}

function Get-M365AdminSpecCoverageRegistryOperations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    . (Join-Path $RepositoryRoot 'build\PortalSurfaceRegistry.ps1')
    $registry = Import-PortalSurfaceRegistry -RepositoryRoot $RepositoryRoot

    $operations = [System.Collections.Generic.List[object]]::new()

    foreach ($plan in @($registry.PlaywrightPlans)) {
        foreach ($group in @($plan.Groups)) {
            foreach ($request in @($group.Requests)) {
                $operations.Add([pscustomobject]@{
                    Source = 'PlaywrightPlan'
                    PlanId = [string]$plan.Id
                    GroupName = [string]$group.Name
                    RequestName = [string]$request.Name
                    Method = if ($request.PSObject.Properties.Name -contains 'Method') { [string]$request.Method } else { 'Get' }
                    PathTemplate = [string]$request.PathTemplate
                }) | Out-Null
            }
        }
    }

    foreach ($surface in @($registry.InteractiveSurfaces)) {
        if (-not ($surface.PSObject.Properties.Name -contains 'PathTemplate')) {
            continue
        }

        $operations.Add([pscustomobject]@{
            Source = 'InteractiveSurface'
            PlanId = 'interactive'
            GroupName = 'InteractiveSurfaces'
            RequestName = [string]$surface.Name
            Method = if ($surface.PSObject.Properties.Name -contains 'Method') { [string]$surface.Method } else { 'Get' }
            PathTemplate = [string]$surface.PathTemplate
        }) | Out-Null
    }

    if ($registry.PSObject.Properties.Name -contains 'WriteProbePlans') {
        foreach ($plan in @($registry.WriteProbePlans)) {
            foreach ($request in @($plan.Requests)) {
                $methods = if ($request.PSObject.Properties.Name -contains 'Methods') {
                    @($request.Methods)
                }
                elseif ($request.PSObject.Properties.Name -contains 'Method') {
                    @($request.Method)
                }
                else {
                    @()
                }

                foreach ($method in $methods) {
                    $operations.Add([pscustomobject]@{
                        Source = 'WriteProbePlan'
                        PlanId = [string]$plan.Id
                        GroupName = [string]$request.Name
                        RequestName = [string]$request.Name
                        Method = [string]$method
                        PathTemplate = [string]$request.PathTemplate
                    }) | Out-Null
                }
            }
        }
    }

    return @($operations.ToArray() | Sort-Object PathTemplate, Method, RequestName)
}

function Get-M365AdminSpecCoverageRepositoryFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter()]
        [string[]]$ExcludedRoots
    )

    $normalizedExcludedRoots = @(
        foreach ($root in @($ExcludedRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            try {
                (Resolve-Path -LiteralPath $root -ErrorAction Stop).Path
            }
            catch {
                $root
            }
        }
    )

    return @(
        Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -Include *.ps1,*.psm1,*.psd1,*.json,*.md |
            Where-Object {
                $filePath = $_.FullName
                foreach ($excludedRoot in $normalizedExcludedRoots) {
                    if ($filePath.StartsWith($excludedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                        return $false
                    }
                }

                return $true
            }
    )
}

function Find-M365AdminSpecCoverageCodeMatches {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$PathTemplates,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$RepositoryFiles
    )

    $matches = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($pathTemplate in @($PathTemplates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        foreach ($result in @(
            Select-String -Path $RepositoryFiles.FullName -Pattern $pathTemplate -SimpleMatch -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Path -Unique
        )) {
            $relativePath = $result
            if ($relativePath.StartsWith($RepositoryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relativePath = $relativePath.Substring($RepositoryRoot.Length).TrimStart('\')
            }

            $matches.Add($relativePath) | Out-Null
        }
    }

    return @($matches | Sort-Object)
}

function Compare-M365AdminSpecCoverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$SpecRoot,

        [Parameter()]
        [string]$OutputDirectory
    )

    $resolvedRepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
    $resolvedSpecRoot = (Resolve-Path -LiteralPath $SpecRoot).Path
    $resolvedOutputDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        Join-Path (Join-Path $resolvedRepositoryRoot 'TestResults') 'Artifacts'
    }
    else {
        $OutputDirectory
    }

    $specOperations = @(Get-M365AdminSpecOperations -SpecRoot $resolvedSpecRoot)
    $registryOperations = @(Get-M365AdminSpecCoverageRegistryOperations -RepositoryRoot $resolvedRepositoryRoot)
    $cmdletInventory = @(Get-M365AdminSpecCoverageCmdletInventory -RepositoryRoot $resolvedRepositoryRoot)
    $repositoryFiles = @(Get-M365AdminSpecCoverageRepositoryFiles -RepositoryRoot $resolvedRepositoryRoot -ExcludedRoots @(
            $resolvedSpecRoot
            $resolvedOutputDirectory
            (Join-Path $resolvedRepositoryRoot 'TestResults\Artifacts')
        ))

    $registryExactLookup = @{}
    foreach ($registryOperation in $registryOperations) {
        $key = '{0}|{1}' -f $registryOperation.Method.ToUpperInvariant(), $registryOperation.PathTemplate
        if (-not $registryExactLookup.ContainsKey($key)) {
            $registryExactLookup[$key] = [System.Collections.Generic.List[object]]::new()
        }

        $registryExactLookup[$key].Add($registryOperation) | Out-Null
    }

    $details = [System.Collections.Generic.List[object]]::new()

    foreach ($specOperation in $specOperations) {
        $effectiveKey = '{0}|{1}' -f $specOperation.Method.ToUpperInvariant(), $specOperation.EffectivePathTemplate
        $exactRegistryMatches = if ($registryExactLookup.ContainsKey($effectiveKey)) {
            @($registryExactLookup[$effectiveKey].ToArray())
        }
        else {
            @()
        }

        $pathRegistryMatches = @(
            $registryOperations |
                Where-Object PathTemplate -eq $specOperation.EffectivePathTemplate
        )

        $codeMatches = @(Find-M365AdminSpecCoverageCodeMatches -PathTemplates @($specOperation.PathTemplate, $specOperation.EffectivePathTemplate) -RepositoryRoot $resolvedRepositoryRoot -RepositoryFiles $repositoryFiles)

        $coverageStatus = if ($exactRegistryMatches.Count -gt 0) {
            'CoveredByRegistry'
        }
        elseif ($pathRegistryMatches.Count -gt 0) {
            'MethodDrift'
        }
        elseif ($codeMatches.Count -gt 0) {
            'CoveredByCodeOnly'
        }
        else {
            'MissingFromRegistryAndCode'
        }

        $details.Add([pscustomobject]@{
            File = $specOperation.File
            Method = $specOperation.Method
            PathTemplate = $specOperation.PathTemplate
            EffectivePathTemplate = $specOperation.EffectivePathTemplate
            CanonicalPath = $specOperation.CanonicalPath
            OperationId = $specOperation.OperationId
            Tags = @($specOperation.Tags)
            PendingSchema = [bool]$specOperation.PendingSchema
            CoverageStatus = $coverageStatus
            RegistrySources = @($exactRegistryMatches | ForEach-Object { '{0}:{1}:{2}' -f $_.Source, $_.RequestName, $_.Method } | Select-Object -Unique)
            RegistryPathMethods = @($pathRegistryMatches | Select-Object -ExpandProperty Method -Unique)
            CodeFiles = $codeMatches
        }) | Out-Null
    }

    $detailArray = @($details.ToArray() | Sort-Object File, EffectivePathTemplate, Method, OperationId)
    $highConfidenceMissing = @(
        $detailArray |
            Where-Object {
                ($_.CoverageStatus -eq 'MissingFromRegistryAndCode') -and
                (-not $_.PendingSchema)
            }
    )

    $summary = [pscustomobject]@{
        ComparedAt = (Get-Date).ToUniversalTime().ToString('o')
        RepositoryRoot = $resolvedRepositoryRoot
        SpecRoot = $resolvedSpecRoot
        SpecOperationCount = $detailArray.Count
        RegistryOperationCount = $registryOperations.Count
        CmdletCount = $cmdletInventory.Count
        CoverageCounts = @(
            $detailArray |
                Group-Object CoverageStatus |
                Sort-Object Name |
                ForEach-Object {
                    [pscustomobject]@{
                        CoverageStatus = $_.Name
                        Count = $_.Count
                    }
                }
        )
        HighConfidenceMissingCount = $highConfidenceMissing.Count
        HighConfidenceMissingByFile = @(
            $highConfidenceMissing |
                Group-Object File |
                Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
                ForEach-Object {
                    [pscustomobject]@{
                        File = $_.Name
                        Count = $_.Count
                    }
                }
        )
    }

    $result = [pscustomobject]@{
        Summary = $summary
        SpecOperations = $specOperations
        RegistryOperations = $registryOperations
        CmdletInventory = $cmdletInventory
        Details = $detailArray
        HighConfidenceMissing = $highConfidenceMissing
    }

    if (-not [string]::IsNullOrWhiteSpace($resolvedOutputDirectory)) {
        $null = New-Item -Path $resolvedOutputDirectory -ItemType Directory -Force
        @($summary) | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $resolvedOutputDirectory 'm365-admin-spec-coverage-summary.json') -Encoding utf8
        @($detailArray) | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $resolvedOutputDirectory 'm365-admin-spec-coverage-details.json') -Encoding utf8
        @($highConfidenceMissing) | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $resolvedOutputDirectory 'm365-admin-spec-coverage-high-confidence.json') -Encoding utf8
    }

    return $result
}

if ($MyInvocation.InvocationName -ne '.') {
    if ([string]::IsNullOrWhiteSpace($SpecRoot)) {
        throw 'SpecRoot is required when Compare-M365AdminSpecCoverage.ps1 is invoked as a script.'
    }

    $comparison = Compare-M365AdminSpecCoverage -RepositoryRoot $RepositoryRoot -SpecRoot $SpecRoot -OutputDirectory $OutputDirectory
    if ($PassThru) {
        return $comparison
    }

    $comparison.Summary
}
