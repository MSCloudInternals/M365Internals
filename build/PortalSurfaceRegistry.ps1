Set-StrictMode -Version 1.0

function ConvertTo-PortalSurfaceOrderedData {
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
                $ordered[$key] = ConvertTo-PortalSurfaceOrderedData -InputObject $InputObject[$key]
            }

            return $ordered
        }

        if ($InputObject -is [pscustomobject]) {
            $ordered = [ordered]@{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $ordered[$property.Name] = ConvertTo-PortalSurfaceOrderedData -InputObject $property.Value
            }

            return $ordered
        }

        if (($InputObject -is [System.Collections.IEnumerable]) -and -not ($InputObject -is [string])) {
            $items = @()
            foreach ($item in $InputObject) {
                $items += ,(ConvertTo-PortalSurfaceOrderedData -InputObject $item)
            }

            return ,$items
        }

        return $InputObject
    }
}

function Test-PortalSurfaceProperty {
    param(
        [Parameter()]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $false
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject.Contains($Name)
    }

    return $InputObject.PSObject.Properties.Name -contains $Name
}

function Get-PortalSurfacePropertyValue {
    param(
        [Parameter()]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Test-PortalSurfaceProperty -InputObject $InputObject -Name $Name)) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject[$Name]
    }

    return $InputObject.$Name
}

function Get-PortalSurfaceRegistryPath {
    param(
        [Parameter()]
        [string]$RepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        $RepositoryRoot = Split-Path -Parent $PSScriptRoot
    }

    return Join-Path $RepositoryRoot 'build\metadata\portal-surface-registry.json'
}

function Import-PortalSurfaceRegistry {
    param(
        [Parameter()]
        [string]$RepositoryRoot,

        [Parameter()]
        [string]$RegistryPath
    )

    if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
        $RegistryPath = Get-PortalSurfaceRegistryPath -RepositoryRoot $RepositoryRoot
    }

    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        throw "Portal surface registry was not found at '$RegistryPath'."
    }

    return (Get-Content -LiteralPath $RegistryPath -Raw).TrimStart([char]0xFEFF) | ConvertFrom-Json -Depth 100
}

function New-PortalSurfaceValidationIssue {
    param(
        [Parameter(Mandatory)]
        [string]$Code,

        [Parameter(Mandatory)]
        [string]$Location,

        [Parameter(Mandatory)]
        [string]$Message
    )

    return [pscustomobject]@{
        Code     = $Code
        Location = $Location
        Message  = $Message
    }
}

function Add-PortalSurfaceValidationIssue {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Issues,

        [Parameter(Mandatory)]
        [string]$Code,

        [Parameter(Mandatory)]
        [string]$Location,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $Issues.Add((New-PortalSurfaceValidationIssue -Code $Code -Location $Location -Message $Message)) | Out-Null
}

function Get-PortalSurfaceKnownPlaceholderNames {
    $placeholderValues = Get-PortalSurfacePlaceholderValues -TenantId '11111111-1111-1111-1111-111111111111'
    return [string[]]@($placeholderValues.Keys)
}

function Get-PortalSurfaceTemplatePlaceholders {
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    $placeholders = [System.Collections.Generic.List[string]]::new()

    function Add-PortalSurfaceStringPlaceholders {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$Value
        )

        foreach ($match in [regex]::Matches($Value, '\{([^{}]+)\}')) {
            $placeholders.Add([string]$match.Groups[1].Value) | Out-Null
        }
    }

    function Visit-PortalSurfacePlaceholderNode {
        param(
            [Parameter(ValueFromPipeline)]
            $Node
        )

        process {
            if ($null -eq $Node) {
                return
            }

            if ($Node -is [string]) {
                Add-PortalSurfaceStringPlaceholders -Value $Node
                return
            }

            if ($Node -is [System.Collections.IDictionary]) {
                foreach ($key in $Node.Keys) {
                    Visit-PortalSurfacePlaceholderNode -Node $Node[$key]
                }
                return
            }

            if ($Node -is [pscustomobject]) {
                foreach ($property in $Node.PSObject.Properties) {
                    Visit-PortalSurfacePlaceholderNode -Node $property.Value
                }
                return
            }

            if (($Node -is [System.Collections.IEnumerable]) -and -not ($Node -is [string])) {
                foreach ($item in $Node) {
                    Visit-PortalSurfacePlaceholderNode -Node $item
                }
            }
        }
    }

    Visit-PortalSurfacePlaceholderNode -Node $InputObject
    return [string[]]@($placeholders.ToArray() | Select-Object -Unique)
}

function Get-PortalSurfaceRequestAllowedPlaceholders {
    param(
        [Parameter(Mandatory)]
        $Request,

        [Parameter(Mandatory)]
        [string[]]$BasePlaceholderNames
    )

    $allowedPlaceholders = @($BasePlaceholderNames)
    $placeholderName = $null

    if ($Request.PSObject.Properties.Name -contains 'ExpansionPlaceholderName') {
        $placeholderName = [string]$Request.ExpansionPlaceholderName
    }

    if ([string]::IsNullOrWhiteSpace($placeholderName) -and ($Request.PSObject.Properties.Name -contains 'ExpansionValuesKey')) {
        $placeholderName = [string]$Request.ExpansionValuesKey
    }

    if (-not [string]::IsNullOrWhiteSpace($placeholderName)) {
        $allowedPlaceholders += $placeholderName
        $allowedPlaceholders += ('Encoded{0}' -f $placeholderName)
    }

    return [string[]]@($allowedPlaceholders | Select-Object -Unique)
}

function Test-PortalSurfacePlaceholders {
    param(
        [Parameter(Mandatory)]
        $InputObject,

        [Parameter(Mandatory)]
        [string[]]$AllowedPlaceholders,

        [Parameter(Mandatory)]
        [string]$Location,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Issues
    )

    foreach ($placeholder in @(Get-PortalSurfaceTemplatePlaceholders -InputObject $InputObject)) {
        if ($AllowedPlaceholders -notcontains $placeholder) {
            Add-PortalSurfaceValidationIssue -Issues $Issues -Code 'UnknownPlaceholder' -Location $Location -Message ("The placeholder '{0}' is not defined for this registry entry." -f $placeholder)
        }
    }
}

function Test-PortalSurfaceRegistry {
    param(
        [Parameter()]
        $Registry,

        [Parameter()]
        [string]$RepositoryRoot,

        [Parameter()]
        [string]$RegistryPath,

        [Parameter()]
        [switch]$ErrorOnIssue
    )

    if ($null -eq $Registry) {
        $Registry = Import-PortalSurfaceRegistry -RepositoryRoot $RepositoryRoot -RegistryPath $RegistryPath
    }

    $issues = [System.Collections.Generic.List[object]]::new()
    $globalPlaceholderNames = @(Get-PortalSurfaceKnownPlaceholderNames)
    $headerProfileNames = @($Registry.HeaderProfiles.PSObject.Properties.Name)
    $playwrightPlanIds = @($Registry.PlaywrightPlans | ForEach-Object { [string]$_.Id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $writeProbePlans = if ($Registry.PSObject.Properties.Name -contains 'WriteProbePlans') { @($Registry.WriteProbePlans) } else { @() }
    $writeProbePlanIds = @($writeProbePlans | ForEach-Object { [string]$_.Id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $allReferencedPlanIds = @($playwrightPlanIds + $writeProbePlanIds | Select-Object -Unique)
    $allowedInteractionActions = @('Wait', 'WaitForText', 'WaitForSelector', 'ClickText', 'ClickRole', 'ClickSelector')

    foreach ($duplicatePrefix in @($Registry.TrackedPrefixes | Group-Object | Where-Object { $_.Count -gt 1 })) {
        Add-PortalSurfaceValidationIssue -Issues $issues -Code 'DuplicateTrackedPrefix' -Location 'TrackedPrefixes' -Message ("The tracked prefix '{0}' appears more than once." -f $duplicatePrefix.Name)
    }

    foreach ($prefix in @($Registry.TrackedPrefixes)) {
        if (-not ([string]$prefix).StartsWith('/')) {
            Add-PortalSurfaceValidationIssue -Issues $issues -Code 'InvalidTrackedPrefix' -Location 'TrackedPrefixes' -Message ("The tracked prefix '{0}' must start with '/'." -f $prefix)
        }
    }

    foreach ($headerProfile in $Registry.HeaderProfiles.PSObject.Properties) {
        Test-PortalSurfacePlaceholders -InputObject $headerProfile.Value -AllowedPlaceholders $globalPlaceholderNames -Location ("HeaderProfiles/{0}" -f $headerProfile.Name) -Issues $issues
    }

    foreach ($duplicatePlanId in @($playwrightPlanIds | Group-Object | Where-Object { $_.Count -gt 1 })) {
        Add-PortalSurfaceValidationIssue -Issues $issues -Code 'DuplicatePlaywrightPlanId' -Location 'PlaywrightPlans' -Message ("The Playwright plan id '{0}' appears more than once." -f $duplicatePlanId.Name)
    }

    foreach ($duplicatePlanId in @($writeProbePlanIds | Group-Object | Where-Object { $_.Count -gt 1 })) {
        Add-PortalSurfaceValidationIssue -Issues $issues -Code 'DuplicateWriteProbePlanId' -Location 'WriteProbePlans' -Message ("The write probe plan id '{0}' appears more than once." -f $duplicatePlanId.Name)
    }

    foreach ($mapping in @($Registry.CmdletMappingOverrides)) {
        Test-PortalSurfacePlaceholders -InputObject $mapping -AllowedPlaceholders $globalPlaceholderNames -Location ("CmdletMappingOverrides/{0}" -f [string]$mapping.Cmdlet) -Issues $issues
    }

    foreach ($surface in @($Registry.InteractiveSurfaces)) {
        foreach ($planId in @($surface.PlanIds)) {
            if ($allReferencedPlanIds -notcontains $planId) {
                Add-PortalSurfaceValidationIssue -Issues $issues -Code 'UnknownPlanReference' -Location ("InteractiveSurfaces/{0}" -f [string]$surface.Id) -Message ("The referenced plan id '{0}' does not exist." -f $planId)
            }
        }

        Test-PortalSurfacePlaceholders -InputObject $surface -AllowedPlaceholders $globalPlaceholderNames -Location ("InteractiveSurfaces/{0}" -f [string]$surface.Id) -Issues $issues
    }

    foreach ($plan in @($Registry.PlaywrightPlans)) {
        foreach ($duplicateGroup in @($plan.Groups.Name | Group-Object | Where-Object { $_.Count -gt 1 })) {
            Add-PortalSurfaceValidationIssue -Issues $issues -Code 'DuplicateGroupName' -Location ("PlaywrightPlans/{0}" -f [string]$plan.Id) -Message ("The group '{0}' appears more than once in plan '{1}'." -f $duplicateGroup.Name, [string]$plan.Id)
        }

        foreach ($group in @($plan.Groups)) {
            $seenTemplateKeys = New-Object System.Collections.Generic.HashSet[string]
            foreach ($request in @($group.Requests)) {
                $requestLocation = "PlaywrightPlans/$($plan.Id)/$($group.Name)/$($request.Name)"
                $allowedPlaceholders = Get-PortalSurfaceRequestAllowedPlaceholders -Request $request -BasePlaceholderNames $globalPlaceholderNames
                $requestMethod = if ($request.PSObject.Properties.Name -contains 'Method') { ([string]$request.Method).ToUpperInvariant() } else { 'GET' }
                $requestHeaderProfile = if ($request.PSObject.Properties.Name -contains 'HeaderProfile') { [string]$request.HeaderProfile } else { '' }

                if (($request.PSObject.Properties.Name -contains 'HeaderProfile') -and (-not [string]::IsNullOrWhiteSpace([string]$request.HeaderProfile)) -and ($headerProfileNames -notcontains [string]$request.HeaderProfile)) {
                    Add-PortalSurfaceValidationIssue -Issues $issues -Code 'UnknownHeaderProfile' -Location $requestLocation -Message ("The header profile '{0}' does not exist." -f [string]$request.HeaderProfile)
                }

                Test-PortalSurfacePlaceholders -InputObject $request -AllowedPlaceholders $allowedPlaceholders -Location $requestLocation -Issues $issues

                $templateKey = '{0}|{1}|{2}|{3}' -f $requestMethod, [string]$request.PathTemplate, $requestHeaderProfile, (@($request.MatchBodyIncludes) -join '&&')
                if (-not $seenTemplateKeys.Add($templateKey)) {
                    Add-PortalSurfaceValidationIssue -Issues $issues -Code 'DuplicateRequestTemplate' -Location $requestLocation -Message ("The request template '{0} {1}' is duplicated within plan group '{2}'." -f $requestMethod, [string]$request.PathTemplate, [string]$group.Name)
                }
            }
        }
    }

    $seenDiscoveryNames = New-Object System.Collections.Generic.HashSet[string]
    $seenDiscoveryRoutes = New-Object System.Collections.Generic.HashSet[string]
    foreach ($route in @($Registry.DiscoveryRoutes)) {
        $routeLocation = "DiscoveryRoutes/$([string]$route.Name)"
        if (-not $seenDiscoveryNames.Add([string]$route.Name)) {
            Add-PortalSurfaceValidationIssue -Issues $issues -Code 'DuplicateDiscoveryRouteName' -Location $routeLocation -Message ("The discovery route name '{0}' appears more than once." -f [string]$route.Name)
        }

        if (-not $seenDiscoveryRoutes.Add([string]$route.Route)) {
            Add-PortalSurfaceValidationIssue -Issues $issues -Code 'DuplicateDiscoveryRoute' -Location $routeLocation -Message ("The discovery route '{0}' appears more than once." -f [string]$route.Route)
        }

        foreach ($planId in @($route.PlanIds)) {
            if ($playwrightPlanIds -notcontains $planId) {
                Add-PortalSurfaceValidationIssue -Issues $issues -Code 'UnknownPlanReference' -Location $routeLocation -Message ("The discovery route references unknown Playwright plan id '{0}'." -f $planId)
            }
        }

        if ([string]::IsNullOrWhiteSpace([string]$route.DisplayName)) {
            Add-PortalSurfaceValidationIssue -Issues $issues -Code 'MissingDiscoveryDisplayName' -Location $routeLocation -Message 'Each discovery route must declare a DisplayName.'
        }

        if ([string]::IsNullOrWhiteSpace([string]$route.TopLevelPage)) {
            Add-PortalSurfaceValidationIssue -Issues $issues -Code 'MissingTopLevelPage' -Location $routeLocation -Message 'Each discovery route must declare the intended TopLevelPage.'
        }

        if ([string]::IsNullOrWhiteSpace([string]$route.Workload)) {
            Add-PortalSurfaceValidationIssue -Issues $issues -Code 'MissingDiscoveryWorkload' -Location $routeLocation -Message 'Each discovery route must declare a Workload hint.'
        }

        if ((-not ([string]$route.Route).StartsWith('#/')) -and (-not ([string]$route.Route).StartsWith('https://admin.cloud.microsoft/'))) {
            Add-PortalSurfaceValidationIssue -Issues $issues -Code 'InvalidDiscoveryRoute' -Location $routeLocation -Message ("The discovery route '{0}' must be a portal hash route or full admin.cloud.microsoft URL." -f [string]$route.Route)
        }

        Test-PortalSurfacePlaceholders -InputObject $route -AllowedPlaceholders $globalPlaceholderNames -Location $routeLocation -Issues $issues

        $actionIndex = 0
        $routeInteractions = if ($route.PSObject.Properties.Name -contains 'Interactions') { @($route.Interactions) } else { @() }
        foreach ($action in $routeInteractions) {
            $actionIndex++
            $actionLocation = "$routeLocation/Interactions[$actionIndex]"

            if ($allowedInteractionActions -notcontains [string]$action.Action) {
                Add-PortalSurfaceValidationIssue -Issues $issues -Code 'UnknownInteractionAction' -Location $actionLocation -Message ("The interaction action '{0}' is not supported." -f [string]$action.Action)
                continue
            }

            switch ([string]$action.Action) {
                'ClickText' {
                    if ([string]::IsNullOrWhiteSpace([string]$action.Text)) {
                        Add-PortalSurfaceValidationIssue -Issues $issues -Code 'InvalidInteraction' -Location $actionLocation -Message 'ClickText interactions must declare a Text value.'
                    }
                }
                'ClickRole' {
                    if ([string]::IsNullOrWhiteSpace([string]$action.Role) -or [string]::IsNullOrWhiteSpace([string]$action.Name)) {
                        Add-PortalSurfaceValidationIssue -Issues $issues -Code 'InvalidInteraction' -Location $actionLocation -Message 'ClickRole interactions must declare both Role and Name.'
                    }
                }
                'ClickSelector' {
                    if ([string]::IsNullOrWhiteSpace([string]$action.Selector)) {
                        Add-PortalSurfaceValidationIssue -Issues $issues -Code 'InvalidInteraction' -Location $actionLocation -Message 'ClickSelector interactions must declare a Selector.'
                    }
                }
                'WaitForText' {
                    if ([string]::IsNullOrWhiteSpace([string]$action.Text)) {
                        Add-PortalSurfaceValidationIssue -Issues $issues -Code 'InvalidInteraction' -Location $actionLocation -Message 'WaitForText interactions must declare a Text value.'
                    }
                }
                'WaitForSelector' {
                    if ([string]::IsNullOrWhiteSpace([string]$action.Selector)) {
                        Add-PortalSurfaceValidationIssue -Issues $issues -Code 'InvalidInteraction' -Location $actionLocation -Message 'WaitForSelector interactions must declare a Selector.'
                    }
                }
            }

            Test-PortalSurfacePlaceholders -InputObject $action -AllowedPlaceholders $globalPlaceholderNames -Location $actionLocation -Issues $issues
        }
    }

    foreach ($plan in $writeProbePlans) {
        $seenProbeKeys = New-Object System.Collections.Generic.HashSet[string]
        foreach ($request in @($plan.Requests)) {
            $requestLocation = "WriteProbePlans/$($plan.Id)/$($request.Name)"
            $allowedPlaceholders = Get-PortalSurfaceRequestAllowedPlaceholders -Request $request -BasePlaceholderNames $globalPlaceholderNames
            $requestBodySource = if ($request.PSObject.Properties.Name -contains 'BodySource') { [string]$request.BodySource } else { '' }
            $requestBodyWrapperProperty = if ($request.PSObject.Properties.Name -contains 'BodyWrapperProperty') { [string]$request.BodyWrapperProperty } else { '' }

            if (($request.PSObject.Properties.Name -contains 'HeaderProfile') -and (-not [string]::IsNullOrWhiteSpace([string]$request.HeaderProfile)) -and ($headerProfileNames -notcontains [string]$request.HeaderProfile)) {
                Add-PortalSurfaceValidationIssue -Issues $issues -Code 'UnknownHeaderProfile' -Location $requestLocation -Message ("The header profile '{0}' does not exist." -f [string]$request.HeaderProfile)
            }

            if ((-not ($request.PSObject.Properties.Name -contains 'Method')) -and (-not ($request.PSObject.Properties.Name -contains 'Methods'))) {
                Add-PortalSurfaceValidationIssue -Issues $issues -Code 'MissingProbeMethod' -Location $requestLocation -Message 'Each write probe request must declare Method or Methods.'
            }

            if (($request.PSObject.Properties.Name -contains 'BodyWrapperProperty') -and [string]::IsNullOrWhiteSpace([string]$request.BodySource)) {
                Add-PortalSurfaceValidationIssue -Issues $issues -Code 'InvalidBodyWrapper' -Location $requestLocation -Message 'BodyWrapperProperty requires BodySource to be set.'
            }

            Test-PortalSurfacePlaceholders -InputObject $request -AllowedPlaceholders $allowedPlaceholders -Location $requestLocation -Issues $issues

            $methodList = if ($request.PSObject.Properties.Name -contains 'Methods') { @($request.Methods) } elseif ($request.PSObject.Properties.Name -contains 'Method') { @([string]$request.Method) } else { @() }
            $templateKey = '{0}|{1}|{2}|{3}' -f (@($methodList | ForEach-Object { [string]$_ } | Sort-Object) -join ','), [string]$request.PathTemplate, $requestBodySource, $requestBodyWrapperProperty
            if (-not $seenProbeKeys.Add($templateKey)) {
                Add-PortalSurfaceValidationIssue -Issues $issues -Code 'DuplicateWriteProbeTemplate' -Location $requestLocation -Message ("The write probe template '{0}' is duplicated within write probe plan '{1}'." -f [string]$request.PathTemplate, [string]$plan.Id)
            }
        }
    }

    if ($ErrorOnIssue -and $issues.Count -gt 0) {
        $issueSummary = @($issues | ForEach-Object { '[{0}] {1}: {2}' -f $_.Code, $_.Location, $_.Message }) -join [Environment]::NewLine
        throw ("Portal surface registry validation failed.{0}{1}" -f [Environment]::NewLine, $issueSummary)
    }

    return @($issues.ToArray())
}

function Assert-PortalSurfaceRegistry {
    param(
        [Parameter(Mandatory)]
        $Registry,

        [Parameter()]
        [string]$RepositoryRoot,

        [Parameter()]
        [string]$RegistryPath
    )

    $null = Test-PortalSurfaceRegistry -Registry $Registry -RepositoryRoot $RepositoryRoot -RegistryPath $RegistryPath -ErrorOnIssue
}

function Get-PortalSurfaceRegistry {
    param(
        [Parameter()]
        [string]$RepositoryRoot,

        [Parameter()]
        [string]$RegistryPath
    )

    $registry = Import-PortalSurfaceRegistry -RepositoryRoot $RepositoryRoot -RegistryPath $RegistryPath
    Assert-PortalSurfaceRegistry -Registry $registry -RepositoryRoot $RepositoryRoot -RegistryPath $RegistryPath
    return $registry
}

function Get-PortalSurfacePlaceholderValues {
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [hashtable]$PlaceholderValues
    )

    $nowUtc = (Get-Date).ToUniversalTime()
    $windowStartUtc = $nowUtc.AddDays(-31)
    $defaultDlpPolicyFilter = [uri]::EscapeDataString("Identity eq 'Default DLP policy - Protect sensitive M365 Copilot interactions'")
    $complianceRecommendationFilter = [uri]::EscapeDataString("PurviewAIScenario eq 'P4AIAdhocQuery14' and HostNames eq '' and SensitiveInfoTypes eq 'None'")
    $defaultReleaseRuleFilter = [uri]::EscapeDataString('FFN eq 55336b82-a18d-4dd6-b5f6-9e5095c314a6 and IsDefault eq true')
    $mecReleaseFilter = [uri]::EscapeDataString("ServicingChannel eq 'MEC'")
    $sacReleaseFilter = [uri]::EscapeDataString("ServicingChannel eq 'SAC'")
    $monthlyReleaseFilter = [uri]::EscapeDataString("ServicingChannel eq 'Monthly'")
    $resolvedTenantId = [string]$TenantId

    $values = [ordered]@{
        TenantId = $resolvedTenantId
        EncodedTenantId = if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) { '' } else { [uri]::EscapeDataString($resolvedTenantId) }
        TenantAnchorMailbox = if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) { '' } else { 'TID:{0}' -f $resolvedTenantId }
        WindowStartUtc = $windowStartUtc.ToString('o')
        EncodedWindowStartUtc = [uri]::EscapeDataString($windowStartUtc.ToString('o'))
        NowUtc = $nowUtc.ToString('o')
        EncodedNowUtc = [uri]::EscapeDataString($nowUtc.ToString('o'))
        DefaultDlpPolicyFilter = $defaultDlpPolicyFilter
        ComplianceRecommendationFilter = $complianceRecommendationFilter
        DefaultReleaseRuleFilter = $defaultReleaseRuleFilter
        MecReleaseFilter = $mecReleaseFilter
        SacReleaseFilter = $sacReleaseFilter
        MonthlyReleaseFilter = $monthlyReleaseFilter
    }

    if ($PlaceholderValues) {
        foreach ($entry in @($PlaceholderValues.GetEnumerator())) {
            $values[$entry.Key] = $entry.Value
        }
    }

    return $values
}

function Resolve-PortalSurfaceTemplateValue {
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$PlaceholderValues
    )

    process {
        if ($null -eq $InputObject) {
            return $null
        }

        if ($InputObject -is [string]) {
            $resolved = [string]$InputObject
            foreach ($entry in @($PlaceholderValues.GetEnumerator() | Sort-Object { $_.Key.Length } -Descending)) {
                $resolved = $resolved.Replace(("{{{0}}}" -f $entry.Key), [string]$entry.Value)
            }

            return $resolved
        }

        if ($InputObject -is [System.Collections.IDictionary]) {
            $resolved = [ordered]@{}
            foreach ($key in $InputObject.Keys) {
                $resolved[$key] = Resolve-PortalSurfaceTemplateValue -InputObject $InputObject[$key] -PlaceholderValues $PlaceholderValues
            }

            return $resolved
        }

        if ($InputObject -is [pscustomobject]) {
            $resolved = [ordered]@{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $resolved[$property.Name] = Resolve-PortalSurfaceTemplateValue -InputObject $property.Value -PlaceholderValues $PlaceholderValues
            }

            return $resolved
        }

        if (($InputObject -is [System.Collections.IEnumerable]) -and -not ($InputObject -is [string])) {
            $items = @()
            foreach ($item in $InputObject) {
                $items += ,(Resolve-PortalSurfaceTemplateValue -InputObject $item -PlaceholderValues $PlaceholderValues)
            }

            return ,$items
        }

        return $InputObject
    }
}

function Get-PortalSurfacePlanRecords {
    param(
        [Parameter(Mandatory)]
        $Registry,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$PlanIds
    )

    $plans = @($Registry.PlaywrightPlans)
    if ($PlanIds.Count -eq 0) {
        return $plans
    }

    return @($plans | Where-Object { $_.Id -in $PlanIds })
}

function Get-PortalSurfaceWriteProbePlanRecords {
    param(
        [Parameter(Mandatory)]
        $Registry,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$PlanIds
    )

    $plans = if ($Registry.PSObject.Properties.Name -contains 'WriteProbePlans') { @($Registry.WriteProbePlans) } else { @() }
    if ($PlanIds.Count -eq 0) {
        return $plans
    }

    return @($plans | Where-Object { $_.Id -in $PlanIds })
}

function Get-PortalSurfaceTrackedRequestPrefixes {
    param(
        [Parameter()]
        [string]$RepositoryRoot,

        [Parameter()]
        [string]$RegistryPath
    )

    $registry = Get-PortalSurfaceRegistry -RepositoryRoot $RepositoryRoot -RegistryPath $RegistryPath
    $prefixes = [System.Collections.Generic.List[string]]::new()
    $seenPrefixes = New-Object System.Collections.Generic.HashSet[string]

    foreach ($prefix in @($registry.TrackedPrefixes)) {
        if ($seenPrefixes.Add([string]$prefix)) {
            $prefixes.Add([string]$prefix) | Out-Null
        }
    }

    return @($prefixes.ToArray())
}

function Get-PortalSurfaceResolvedHeaderProfiles {
    param(
        [Parameter(Mandatory)]
        $Registry,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$PlaceholderValues
    )

    $profiles = @{}
    foreach ($profile in $Registry.HeaderProfiles.PSObject.Properties) {
        $profiles[$profile.Name] = Resolve-PortalSurfaceTemplateValue -InputObject $profile.Value -PlaceholderValues $PlaceholderValues
    }

    return $profiles
}

function Get-PortalSurfaceResolvedRequestHeaders {
    param(
        [Parameter(Mandatory)]
        $Request,

        [Parameter(Mandatory)]
        [hashtable]$ResolvedProfiles,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$PlaceholderValues
    )

    $resolvedHeaders = [ordered]@{}
    $headerProfile = [string](Get-PortalSurfacePropertyValue -InputObject $Request -Name 'HeaderProfile')
    if (-not [string]::IsNullOrWhiteSpace($headerProfile)) {
        if (-not $ResolvedProfiles.ContainsKey($headerProfile)) {
            throw "The header profile '$headerProfile' was not found in the portal surface registry."
        }

        foreach ($entry in @($ResolvedProfiles[$headerProfile].GetEnumerator())) {
            $resolvedHeaders[$entry.Key] = $entry.Value
        }
    }

    if ((Test-PortalSurfaceProperty -InputObject $Request -Name 'Headers') -and $null -ne (Get-PortalSurfacePropertyValue -InputObject $Request -Name 'Headers')) {
        $explicitHeaders = Resolve-PortalSurfaceTemplateValue -InputObject (Get-PortalSurfacePropertyValue -InputObject $Request -Name 'Headers') -PlaceholderValues $PlaceholderValues
        foreach ($entry in @($explicitHeaders.GetEnumerator())) {
            $resolvedHeaders[$entry.Key] = $entry.Value
        }
    }

    return $resolvedHeaders
}

function Expand-PortalSurfaceBrowserRequest {
    param(
        [Parameter(Mandatory)]
        $Request,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$BasePlaceholderValues,

        [Parameter()]
        [hashtable]$ExpansionValues
    )

    $expansionKey = if (Test-PortalSurfaceProperty -InputObject $Request -Name 'ExpansionValuesKey') { [string](Get-PortalSurfacePropertyValue -InputObject $Request -Name 'ExpansionValuesKey') } else { $null }
    $placeholderName = if (Test-PortalSurfaceProperty -InputObject $Request -Name 'ExpansionPlaceholderName') { [string](Get-PortalSurfacePropertyValue -InputObject $Request -Name 'ExpansionPlaceholderName') } else { $null }

    if ([string]::IsNullOrWhiteSpace($expansionKey)) {
        return @(Resolve-PortalSurfaceTemplateValue -InputObject $Request -PlaceholderValues $BasePlaceholderValues)
    }

    $values = if ($ExpansionValues -and $ExpansionValues.ContainsKey($expansionKey)) {
        @($ExpansionValues[$expansionKey])
    }
    else {
        @()
    }

    if ($values.Count -eq 0) {
        return @()
    }

    $expandedRequests = @()
    foreach ($value in $values) {
        $placeholderValues = [ordered]@{}
        foreach ($entry in @($BasePlaceholderValues.GetEnumerator())) {
            $placeholderValues[$entry.Key] = $entry.Value
        }

        $resolvedValue = [string]$value
        $resolvedPlaceholderName = if ([string]::IsNullOrWhiteSpace($placeholderName)) { $expansionKey } else { $placeholderName }
        $placeholderValues[$resolvedPlaceholderName] = $resolvedValue
        $placeholderValues[('Encoded{0}' -f $resolvedPlaceholderName)] = [uri]::EscapeDataString($resolvedValue)

        $expandedRequests += ,(Resolve-PortalSurfaceTemplateValue -InputObject $Request -PlaceholderValues $placeholderValues)
    }

    return $expandedRequests
}

function New-PortalSurfaceBrowserCapturePlan {
    param(
        [Parameter()]
        [string]$RepositoryRoot,

        [Parameter()]
        [string]$RegistryPath,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$PlanIds,

        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [hashtable]$DefaultHeaders,

        [Parameter()]
        [hashtable]$PlaceholderValues,

        [Parameter()]
        [hashtable]$ExpansionValues
    )

    $registry = Get-PortalSurfaceRegistry -RepositoryRoot $RepositoryRoot -RegistryPath $RegistryPath
    $plans = Get-PortalSurfacePlanRecords -Registry $registry -PlanIds $PlanIds
    $resolvedPlaceholderValues = Get-PortalSurfacePlaceholderValues -TenantId $TenantId -PlaceholderValues $PlaceholderValues
    $resolvedProfiles = Get-PortalSurfaceResolvedHeaderProfiles -Registry $registry -PlaceholderValues $resolvedPlaceholderValues
    $defaultHeaderValues = if ($DefaultHeaders) { ConvertTo-PortalSurfaceOrderedData -InputObject $DefaultHeaders } else { [ordered]@{} }

    $browserPlan = [ordered]@{
        GeneratedAt = (Get-Date).ToUniversalTime().ToString('o')
        TenantId = $TenantId
        PlanIds = @($plans.Id)
        DefaultHeaders = $defaultHeaderValues
        Requests = [ordered]@{}
    }

    foreach ($plan in $plans) {
        foreach ($group in @($plan.Groups)) {
            if (-not $browserPlan.Requests.Contains($group.Name)) {
                $browserPlan.Requests[$group.Name] = @()
            }

            foreach ($requestDefinition in @($group.Requests)) {
                foreach ($expandedRequest in @(Expand-PortalSurfaceBrowserRequest -Request $requestDefinition -BasePlaceholderValues $resolvedPlaceholderValues -ExpansionValues $ExpansionValues)) {
                    $requestRecord = [ordered]@{
                        Name = [string](Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'Name')
                        Path = [string](Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'PathTemplate')
                        Method = if (Test-PortalSurfaceProperty -InputObject $expandedRequest -Name 'Method') { [string](Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'Method') } else { 'Get' }
                        TimeoutMs = if (Test-PortalSurfaceProperty -InputObject $expandedRequest -Name 'TimeoutMs') { [int](Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'TimeoutMs') } else { 20000 }
                    }

                    if (Test-PortalSurfaceProperty -InputObject $expandedRequest -Name 'Body') {
                        $requestRecord.Body = ConvertTo-PortalSurfaceOrderedData -InputObject (Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'Body')
                    }

                    $headers = Get-PortalSurfaceResolvedRequestHeaders -Request $expandedRequest -ResolvedProfiles $resolvedProfiles -PlaceholderValues $resolvedPlaceholderValues
                    if ($headers.Count -gt 0) {
                        $requestRecord.Headers = ConvertTo-PortalSurfaceOrderedData -InputObject $headers
                    }

                    $browserPlan.Requests[$group.Name] += $requestRecord
                }
            }
        }
    }

    return $browserPlan
}

function Get-PortalSurfaceKnownRequests {
    param(
        [Parameter(Mandatory)]
        $Registry,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$PlanIds
    )

    $plans = Get-PortalSurfacePlanRecords -Registry $Registry -PlanIds $PlanIds
    $knownRequests = [System.Collections.Generic.List[object]]::new()

    foreach ($plan in $plans) {
        foreach ($group in @($plan.Groups)) {
            foreach ($request in @($group.Requests)) {
                $knownRequest = [ordered]@{
                    PlanId = $plan.Id
                    GroupName = $group.Name
                    Name = [string](Get-PortalSurfacePropertyValue -InputObject $request -Name 'Name')
                    PathTemplate = [string](Get-PortalSurfacePropertyValue -InputObject $request -Name 'PathTemplate')
                    Method = if (Test-PortalSurfaceProperty -InputObject $request -Name 'Method') { [string](Get-PortalSurfacePropertyValue -InputObject $request -Name 'Method') } else { 'Get' }
                }

                if ((Test-PortalSurfaceProperty -InputObject $request -Name 'MatchBodyIncludes') -and $null -ne (Get-PortalSurfacePropertyValue -InputObject $request -Name 'MatchBodyIncludes')) {
                    $knownRequest.MatchBodyIncludes = @((Get-PortalSurfacePropertyValue -InputObject $request -Name 'MatchBodyIncludes'))
                }

                $knownRequests.Add($knownRequest) | Out-Null
            }
        }
    }

    foreach ($surface in @($Registry.InteractiveSurfaces)) {
        if (($PlanIds.Count -gt 0) -and ($surface.PlanIds.Count -gt 0) -and (-not (@($surface.PlanIds) | Where-Object { $_ -in $PlanIds }))) {
            continue
        }

        if (Test-PortalSurfaceProperty -InputObject $surface -Name 'PathTemplate') {
            $knownRequest = [ordered]@{
                PlanId = 'interactive'
                GroupName = 'InteractiveSurfaces'
                Name = [string](Get-PortalSurfacePropertyValue -InputObject $surface -Name 'Name')
                PathTemplate = [string](Get-PortalSurfacePropertyValue -InputObject $surface -Name 'PathTemplate')
                Method = if (Test-PortalSurfaceProperty -InputObject $surface -Name 'Method') { [string](Get-PortalSurfacePropertyValue -InputObject $surface -Name 'Method') } else { 'Get' }
            }
            $knownRequests.Add($knownRequest) | Out-Null
        }
    }

    return @($knownRequests.ToArray())
}

function New-PortalSurfaceDiscoveryPlan {
    param(
        [Parameter()]
        [string]$RepositoryRoot,

        [Parameter()]
        [string]$RegistryPath,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$PlanIds,

        [Parameter()]
        [string]$TenantId
    )

    $registry = Get-PortalSurfaceRegistry -RepositoryRoot $RepositoryRoot -RegistryPath $RegistryPath
    $knownRequests = Get-PortalSurfaceKnownRequests -Registry $registry -PlanIds $PlanIds
    $routes = [System.Collections.Generic.List[object]]::new()

    foreach ($route in @($registry.DiscoveryRoutes)) {
        if (($PlanIds.Count -gt 0) -and ($route.PlanIds.Count -gt 0) -and (-not (@($route.PlanIds) | Where-Object { $_ -in $PlanIds }))) {
            continue
        }

        $routeRecord = [ordered]@{
            Name = [string](Get-PortalSurfacePropertyValue -InputObject $route -Name 'Name')
            Route = [string](Get-PortalSurfacePropertyValue -InputObject $route -Name 'Route')
            WaitMs = if (Test-PortalSurfaceProperty -InputObject $route -Name 'WaitMs') { [int](Get-PortalSurfacePropertyValue -InputObject $route -Name 'WaitMs') } else { 8000 }
            Metadata = [ordered]@{
                DisplayName = if (Test-PortalSurfaceProperty -InputObject $route -Name 'DisplayName') { [string](Get-PortalSurfacePropertyValue -InputObject $route -Name 'DisplayName') } else { [string](Get-PortalSurfacePropertyValue -InputObject $route -Name 'Name') }
                TopLevelPage = if (Test-PortalSurfaceProperty -InputObject $route -Name 'TopLevelPage') { [string](Get-PortalSurfacePropertyValue -InputObject $route -Name 'TopLevelPage') } else { [string](Get-PortalSurfacePropertyValue -InputObject $route -Name 'Name') }
                Workload = if (Test-PortalSurfaceProperty -InputObject $route -Name 'Workload') { [string](Get-PortalSurfacePropertyValue -InputObject $route -Name 'Workload') } else { 'Unknown' }
                TenantOptionality = if (Test-PortalSurfaceProperty -InputObject $route -Name 'TenantOptionality') { [string](Get-PortalSurfacePropertyValue -InputObject $route -Name 'TenantOptionality') } else { 'Unknown' }
                RoleRequirementHints = if (Test-PortalSurfaceProperty -InputObject $route -Name 'RoleRequirementHints') { [string[]]@(Get-PortalSurfacePropertyValue -InputObject $route -Name 'RoleRequirementHints') } else { @() }
                LicenseRequirementHints = if (Test-PortalSurfaceProperty -InputObject $route -Name 'LicenseRequirementHints') { [string[]]@(Get-PortalSurfacePropertyValue -InputObject $route -Name 'LicenseRequirementHints') } else { @() }
            }
        }

        if (Test-PortalSurfaceProperty -InputObject $route -Name 'Notes') {
            $routeRecord.Metadata.Notes = [string](Get-PortalSurfacePropertyValue -InputObject $route -Name 'Notes')
        }

        if ((Test-PortalSurfaceProperty -InputObject $route -Name 'Interactions') -and $null -ne (Get-PortalSurfacePropertyValue -InputObject $route -Name 'Interactions')) {
            $routeRecord.Interactions = @(ConvertTo-PortalSurfaceOrderedData -InputObject (Get-PortalSurfacePropertyValue -InputObject $route -Name 'Interactions'))
        }
        else {
            $routeRecord.Interactions = @()
        }

        $routes.Add($routeRecord) | Out-Null
    }

    return [ordered]@{
        GeneratedAt = (Get-Date).ToUniversalTime().ToString('o')
        TenantId = $TenantId
        PlanIds = @($PlanIds)
        TrackedPrefixes = @($registry.TrackedPrefixes)
        Routes = @($routes.ToArray())
        KnownRequests = @($knownRequests)
    }
}

function New-PortalSurfaceWriteProbePlan {
    param(
        [Parameter()]
        [string]$RepositoryRoot,

        [Parameter()]
        [string]$RegistryPath,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$PlanIds,

        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [hashtable]$PlaceholderValues,

        [Parameter()]
        [hashtable]$ExpansionValues
    )

    $registry = Get-PortalSurfaceRegistry -RepositoryRoot $RepositoryRoot -RegistryPath $RegistryPath
    $plans = Get-PortalSurfaceWriteProbePlanRecords -Registry $registry -PlanIds $PlanIds
    $resolvedPlaceholderValues = Get-PortalSurfacePlaceholderValues -TenantId $TenantId -PlaceholderValues $PlaceholderValues
    $resolvedProfiles = Get-PortalSurfaceResolvedHeaderProfiles -Registry $registry -PlaceholderValues $resolvedPlaceholderValues
    $requests = [System.Collections.Generic.List[object]]::new()

    foreach ($plan in $plans) {
        foreach ($requestDefinition in @($plan.Requests)) {
            foreach ($expandedRequest in @(Expand-PortalSurfaceBrowserRequest -Request $requestDefinition -BasePlaceholderValues $resolvedPlaceholderValues -ExpansionValues $ExpansionValues)) {
                $requestRecord = [ordered]@{
                    Name = [string](Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'Name')
                    Path = [string](Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'PathTemplate')
                }

                if (Test-PortalSurfaceProperty -InputObject $expandedRequest -Name 'Methods') {
                    $requestRecord.Methods = [string[]]@(Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'Methods')
                }
                elseif (Test-PortalSurfaceProperty -InputObject $expandedRequest -Name 'Method') {
                    $requestRecord.Method = [string](Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'Method')
                }

                if (Test-PortalSurfaceProperty -InputObject $expandedRequest -Name 'BodySource') {
                    $requestRecord.BodySource = [string](Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'BodySource')
                }

                if (Test-PortalSurfaceProperty -InputObject $expandedRequest -Name 'BodyWrapperProperty') {
                    $requestRecord.BodyWrapperProperty = [string](Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'BodyWrapperProperty')
                }

                if (Test-PortalSurfaceProperty -InputObject $expandedRequest -Name 'ContentType') {
                    $requestRecord.ContentType = [string](Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'ContentType')
                }

                if (Test-PortalSurfaceProperty -InputObject $expandedRequest -Name 'Notes') {
                    $requestRecord.Notes = [string](Get-PortalSurfacePropertyValue -InputObject $expandedRequest -Name 'Notes')
                }

                $headers = Get-PortalSurfaceResolvedRequestHeaders -Request $expandedRequest -ResolvedProfiles $resolvedProfiles -PlaceholderValues $resolvedPlaceholderValues
                if ($headers.Count -gt 0) {
                    $requestRecord.Headers = ConvertTo-PortalSurfaceOrderedData -InputObject $headers
                }

                $requests.Add((ConvertTo-PortalSurfaceOrderedData -InputObject $requestRecord)) | Out-Null
            }
        }
    }

    return [ordered]@{
        GeneratedAt = (Get-Date).ToUniversalTime().ToString('o')
        TenantId = $TenantId
        PlanIds = @($plans.Id)
        Requests = @($requests.ToArray())
    }
}

function Convert-PortalSurfaceRegistryToCmdletApiMappings {
    param(
        [Parameter()]
        [string]$RepositoryRoot,

        [Parameter()]
        [string]$RegistryPath
    )

    $registry = Get-PortalSurfaceRegistry -RepositoryRoot $RepositoryRoot -RegistryPath $RegistryPath
    $mappings = foreach ($mapping in @($registry.CmdletMappingOverrides)) {
        $entry = [ordered]@{
            Cmdlet = [string]$mapping.Cmdlet
            ApiUri = [string]$mapping.ApiUri
        }

        if ($mapping.PSObject.Properties.Name -contains 'Method') {
            $entry.Method = [string]$mapping.Method
        }

        if ($mapping.PSObject.Properties.Name -contains 'Parameters' -and $null -ne $mapping.Parameters) {
            $entry.Parameters = ConvertTo-PortalSurfaceOrderedData -InputObject $mapping.Parameters
        }

        if ($mapping.PSObject.Properties.Name -contains 'SwitchParameters' -and $null -ne $mapping.SwitchParameters) {
            $entry.SwitchParameters = [string[]]@($mapping.SwitchParameters)
        }

        if ($mapping.PSObject.Properties.Name -contains 'MatchBodyIncludes' -and $null -ne $mapping.MatchBodyIncludes) {
            $entry.MatchBodyIncludes = [string[]]@($mapping.MatchBodyIncludes)
        }

        ConvertTo-PortalSurfaceOrderedData -InputObject $entry
    }

    return @($mappings)
}
