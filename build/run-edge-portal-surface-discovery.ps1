param (
    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [string]$DiscoveryPlanPath,

    [Parameter()]
    [string[]]$PlanId = @('settings-browser', 'agent-copilot-browser'),

    [Parameter()]
    [string]$SnapshotPath,

    [Parameter()]
    [string]$DiffPath,

    [Parameter()]
    [string]$HistoryDirectory,

    [Parameter()]
    [string]$SpecPath = (Join-Path $PSScriptRoot 'capture-portal-surface-discovery.spec.js')
)

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $artifactRoot 'browser-portal-surface-discovery.json'
}

if ([string]::IsNullOrWhiteSpace($DiscoveryPlanPath)) {
    $DiscoveryPlanPath = Join-Path $artifactRoot 'portal-surface-discovery-plan.json'
}

if ([string]::IsNullOrWhiteSpace($SnapshotPath)) {
    $SnapshotPath = Join-Path $artifactRoot 'portal-surface-discovery-snapshot.json'
}

if ([string]::IsNullOrWhiteSpace($DiffPath)) {
    $DiffPath = Join-Path $artifactRoot 'portal-surface-discovery-diff.json'
}

if ([string]::IsNullOrWhiteSpace($HistoryDirectory)) {
    $HistoryDirectory = Join-Path $artifactRoot 'portal-surface-discovery-history'
}

$storageStatePath = Join-Path $artifactRoot 'playwright-portal-surface-discovery-storage-state.json'
$metadataPath = Join-Path $artifactRoot 'playwright-portal-surface-discovery-metadata.json'
$previousPlanPath = $env:M365_BROWSER_CAPTURE_PLAN

. (Join-Path $PSScriptRoot 'PortalSurfaceRegistry.ps1')

function ConvertTo-PortalSurfaceDiscoverySnapshot {
    param(
        [Parameter(Mandatory)]
        $DiscoveryResult
    )

    $routeSummaries = [System.Collections.Generic.List[object]]::new()
    $observedRequests = [System.Collections.Generic.List[object]]::new()

    foreach ($routeResult in @($DiscoveryResult.routeResults)) {
        $routeMetadata = if ($routeResult.PSObject.Properties.Name -contains 'metadata' -and $null -ne $routeResult.metadata) {
            ConvertTo-PortalSurfaceOrderedData -InputObject $routeResult.metadata
        }
        else {
            [ordered]@{}
        }

        $routeSummaries.Add([ordered]@{
            Name = [string]$routeResult.name
            Route = [string]$routeResult.route
            Metadata = $routeMetadata
            UniqueObservedRequestCount = [int]$routeResult.uniqueObservedRequestCount
            UnexpectedRequestCount = [int]$routeResult.unexpectedRequestCount
            InteractionResults = if ($routeResult.PSObject.Properties.Name -contains 'interactionResults') { @(ConvertTo-PortalSurfaceOrderedData -InputObject $routeResult.interactionResults) } else { @() }
        }) | Out-Null

        foreach ($request in @($routeResult.observedRequests)) {
            $observedRequests.Add([ordered]@{
                RouteName = [string]$routeResult.name
                Route = [string]$routeResult.route
                DisplayName = if ($routeMetadata.Contains('DisplayName')) { [string]$routeMetadata.DisplayName } else { [string]$routeResult.name }
                TopLevelPage = if ($routeMetadata.Contains('TopLevelPage')) { [string]$routeMetadata.TopLevelPage } else { '' }
                Workload = if ($routeMetadata.Contains('Workload')) { [string]$routeMetadata.Workload } else { '' }
                TenantOptionality = if ($routeMetadata.Contains('TenantOptionality')) { [string]$routeMetadata.TenantOptionality } else { 'Unknown' }
                RoleRequirementHints = if ($routeMetadata.Contains('RoleRequirementHints')) { [string[]]@($routeMetadata.RoleRequirementHints) } else { @() }
                LicenseRequirementHints = if ($routeMetadata.Contains('LicenseRequirementHints')) { [string[]]@($routeMetadata.LicenseRequirementHints) } else { @() }
                Method = [string]$request.method
                Path = [string]$request.path
                BodyHash = if ($request.PSObject.Properties.Name -contains 'bodyHash') { [string]$request.bodyHash } else { '' }
            }) | Out-Null
        }
    }

    $sortedObservedRequests = @(
        $observedRequests.ToArray() |
            Sort-Object RouteName, Method, Path, BodyHash -Unique
    )

    return [ordered]@{
        SnapshotTakenAt = (Get-Date).ToUniversalTime().ToString('o')
        SourceDiscoveredAt = [string]$DiscoveryResult.discoveredAt
        TenantId = [string]$DiscoveryResult.tenantId
        PlanIds = if ($DiscoveryResult.PSObject.Properties.Name -contains 'planIds') { [string[]]@($DiscoveryResult.planIds) } else { @() }
        TrackedPrefixes = if ($DiscoveryResult.PSObject.Properties.Name -contains 'trackedPrefixes') { [string[]]@($DiscoveryResult.trackedPrefixes) } else { @() }
        RouteSummaries = @($routeSummaries.ToArray() | Sort-Object Name)
        ObservedRequests = $sortedObservedRequests
    }
}

function Compare-PortalSurfaceDiscoverySnapshots {
    param(
        [Parameter(Mandatory)]
        $CurrentSnapshot,

        [Parameter()]
        $PreviousSnapshot
    )

    if ($null -eq $PreviousSnapshot) {
        return [ordered]@{
            ComparedAt = (Get-Date).ToUniversalTime().ToString('o')
            Status = 'InitialSnapshot'
            PreviousSnapshotTakenAt = $null
            CurrentSnapshotTakenAt = [string]$CurrentSnapshot.SnapshotTakenAt
            AddedRequests = @($CurrentSnapshot.ObservedRequests)
            RemovedRequests = @()
            ChangedRoutes = @()
        }
    }

    $currentByKey = @{}
    foreach ($request in @($CurrentSnapshot.ObservedRequests)) {
        $currentByKey["$($request.RouteName)|$($request.Method)|$($request.Path)|$($request.BodyHash)"] = $request
    }

    $previousByKey = @{}
    foreach ($request in @($PreviousSnapshot.ObservedRequests)) {
        $previousByKey["$($request.RouteName)|$($request.Method)|$($request.Path)|$($request.BodyHash)"] = $request
    }

    $addedRequests = @(
        foreach ($key in @($currentByKey.Keys | Sort-Object)) {
            if (-not $previousByKey.ContainsKey($key)) {
                $currentByKey[$key]
            }
        }
    )

    $removedRequests = @(
        foreach ($key in @($previousByKey.Keys | Sort-Object)) {
            if (-not $currentByKey.ContainsKey($key)) {
                $previousByKey[$key]
            }
        }
    )

    $routeChangeMap = @{}
    foreach ($summary in @($CurrentSnapshot.RouteSummaries)) {
        $routeChangeMap[[string]$summary.Name] = [ordered]@{
            Name = [string]$summary.Name
            Route = [string]$summary.Route
            Metadata = ConvertTo-PortalSurfaceOrderedData -InputObject $summary.Metadata
            CurrentUniqueObservedRequestCount = [int]$summary.UniqueObservedRequestCount
            PreviousUniqueObservedRequestCount = 0
            CurrentUnexpectedRequestCount = [int]$summary.UnexpectedRequestCount
            PreviousUnexpectedRequestCount = 0
            AddedRequestCount = 0
            RemovedRequestCount = 0
        }
    }

    foreach ($summary in @($PreviousSnapshot.RouteSummaries)) {
        $routeName = [string]$summary.Name
        if (-not $routeChangeMap.ContainsKey($routeName)) {
            $routeChangeMap[$routeName] = [ordered]@{
                Name = $routeName
                Route = [string]$summary.Route
                Metadata = ConvertTo-PortalSurfaceOrderedData -InputObject $summary.Metadata
                CurrentUniqueObservedRequestCount = 0
                PreviousUniqueObservedRequestCount = [int]$summary.UniqueObservedRequestCount
                CurrentUnexpectedRequestCount = 0
                PreviousUnexpectedRequestCount = [int]$summary.UnexpectedRequestCount
                AddedRequestCount = 0
                RemovedRequestCount = 0
            }
            continue
        }

        $routeChangeMap[$routeName].PreviousUniqueObservedRequestCount = [int]$summary.UniqueObservedRequestCount
        $routeChangeMap[$routeName].PreviousUnexpectedRequestCount = [int]$summary.UnexpectedRequestCount
    }

    foreach ($request in $addedRequests) {
        if ($routeChangeMap.ContainsKey([string]$request.RouteName)) {
            $routeChangeMap[[string]$request.RouteName].AddedRequestCount++
        }
    }

    foreach ($request in $removedRequests) {
        if ($routeChangeMap.ContainsKey([string]$request.RouteName)) {
            $routeChangeMap[[string]$request.RouteName].RemovedRequestCount++
        }
    }

    $changedRoutes = @(
        foreach ($routeChange in @($routeChangeMap.Values | Sort-Object Name)) {
            if (
                ($routeChange.CurrentUniqueObservedRequestCount -ne $routeChange.PreviousUniqueObservedRequestCount) -or
                ($routeChange.CurrentUnexpectedRequestCount -ne $routeChange.PreviousUnexpectedRequestCount) -or
                ($routeChange.AddedRequestCount -gt 0) -or
                ($routeChange.RemovedRequestCount -gt 0)
            ) {
                $routeChange
            }
        }
    )

    return [ordered]@{
        ComparedAt = (Get-Date).ToUniversalTime().ToString('o')
        Status = 'Compared'
        PreviousSnapshotTakenAt = [string]$PreviousSnapshot.SnapshotTakenAt
        CurrentSnapshotTakenAt = [string]$CurrentSnapshot.SnapshotTakenAt
        AddedRequests = $addedRequests
        RemovedRequests = $removedRequests
        ChangedRoutes = $changedRoutes
    }
}

function Write-JsonArtifact {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $InputObject
    )

    $directoryPath = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($directoryPath)) {
        $null = New-Item -Path $directoryPath -ItemType Directory -Force
    }

    $InputObject | ConvertTo-Json -Depth 50 | Set-Content -Path $Path -Encoding utf8
}

try {
    & (Join-Path $PSScriptRoot 'export-playwright-storage-state.ps1') -OutputPath $storageStatePath -MetadataPath $metadataPath | Out-Null

    $metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json
    $discoveryPlan = New-PortalSurfaceDiscoveryPlan -RepositoryRoot (Join-Path $PSScriptRoot '..') -PlanIds $PlanId -TenantId ([string]$metadata.TenantId)
    Write-JsonArtifact -Path $DiscoveryPlanPath -InputObject $discoveryPlan

    $env:M365_BROWSER_CAPTURE_PLAN = $DiscoveryPlanPath
    & (Join-Path $PSScriptRoot 'run-edge-browser-capture.ps1') -SpecPath $SpecPath -OutputPath $OutputPath

    $discoveryResult = Get-Content -Path $OutputPath -Raw | ConvertFrom-Json -Depth 100
    $previousSnapshot = if (Test-Path -LiteralPath $SnapshotPath) {
        (Get-Content -Path $SnapshotPath -Raw).TrimStart([char]0xFEFF) | ConvertFrom-Json -Depth 100
    }
    else {
        $null
    }

    $snapshot = ConvertTo-PortalSurfaceDiscoverySnapshot -DiscoveryResult $discoveryResult
    $diff = Compare-PortalSurfaceDiscoverySnapshots -CurrentSnapshot $snapshot -PreviousSnapshot $previousSnapshot

    Write-JsonArtifact -Path $SnapshotPath -InputObject $snapshot
    Write-JsonArtifact -Path $DiffPath -InputObject $diff

    if (-not [string]::IsNullOrWhiteSpace($HistoryDirectory)) {
        $null = New-Item -Path $HistoryDirectory -ItemType Directory -Force
        $timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        Write-JsonArtifact -Path (Join-Path $HistoryDirectory ("portal-surface-discovery-snapshot-{0}.json" -f $timestamp)) -InputObject $snapshot
        Write-JsonArtifact -Path (Join-Path $HistoryDirectory ("portal-surface-discovery-diff-{0}.json" -f $timestamp)) -InputObject $diff
    }
}
finally {
    Remove-Item -Path $storageStatePath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $metadataPath -Force -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($previousPlanPath)) {
        Remove-Item Env:M365_BROWSER_CAPTURE_PLAN -ErrorAction SilentlyContinue
    }
    else {
        $env:M365_BROWSER_CAPTURE_PLAN = $previousPlanPath
    }
}
