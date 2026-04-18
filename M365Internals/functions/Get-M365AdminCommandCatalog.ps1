function Get-M365AdminCommandCatalog {
    <#
    .SYNOPSIS
        Retrieves the functional command catalog for M365Internals.

    .DESCRIPTION
        Enumerates the public commands exported by M365Internals, groups them by functional
        area, and returns a flattened catalog that helps admins discover the right cmdlet family
        before release. The raw view returns grouped catalog sections.

    .PARAMETER Group
        Filters the catalog to a single functional group.

    .PARAMETER CmdletName
        Filters the catalog to cmdlets whose names match the provided value.

    .PARAMETER Raw
        Returns the grouped catalog sections instead of the flattened entry list.

    .PARAMETER RawJson
        Returns the grouped catalog sections as formatted JSON.

    .EXAMPLE
        Get-M365AdminCommandCatalog

        Returns the flattened command catalog grouped by functional area.

    .EXAMPLE
        Get-M365AdminCommandCatalog -Group OrgSettingsAndWorkloads -Raw

        Returns the grouped Org Settings & Workloads catalog section.

    .OUTPUTS
        Object
        Returns either the flattened command catalog entries or the grouped catalog sections.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'Authentication', 'AgentsAndCopilot', 'OrgSettingsAndWorkloads', 'SearchReportsAndInsights', 'TenantUsersAndRelationships', 'PlatformAndUtilities', 'WriteOperations', 'AdvancedAccess')]
        [string]$Group = 'All',

        [Parameter()]
        [string]$CmdletName,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $module = Get-Module M365Internals
        if ($null -eq $module) {
            throw 'The M365Internals module must be imported before the command catalog can be generated.'
        }

        $groupDefinitions = @(Get-M365AdminCommandCatalogGroupDefinitions)
        $groupLookup = @{}
        foreach ($definition in $groupDefinitions) {
            $groupLookup[$definition.Name] = $definition
        }

        $entries = foreach ($command in @($module.ExportedCommands.Values | Where-Object CommandType -eq 'Function')) {
            $groupName = Get-M365AdminCommandCatalogGroupName -CmdletName $command.Name
            $groupDefinition = $groupLookup[$groupName]
            $help = Get-Help -Name $command.Name -ErrorAction SilentlyContinue

            $entry = [pscustomobject]@{
                Group = $groupDefinition.Title
                GroupKey = $groupName
                Cmdlet = $command.Name
                Kind = ($command.Name -split '-', 2)[0]
                Synopsis = if ($null -ne $help -and -not [string]::IsNullOrWhiteSpace($help.Synopsis)) { $help.Synopsis.Trim() } else { '' }
                DefaultParameterSet = $command.DefaultParameterSet
                SupportsForce = $command.Parameters.ContainsKey('Force')
                SupportsRawOutput = ($command.Parameters.ContainsKey('Raw') -and $command.Parameters.ContainsKey('RawJson'))
            }

            $entry = Add-M365TypeName -InputObject $entry -TypeName 'M365Admin.CommandCatalog.Entry'
            $entry
        }

        if ($Group -ne 'All') {
            $entries = @($entries | Where-Object GroupKey -eq $Group)
        }

        if (-not [string]::IsNullOrWhiteSpace($CmdletName)) {
            $entries = @($entries | Where-Object Cmdlet -like $CmdletName)
        }

        $orderedEntries = foreach ($groupDefinition in @($groupDefinitions | Sort-Object Order)) {
            foreach ($entry in @($entries | Where-Object GroupKey -eq $groupDefinition.Name | Sort-Object Cmdlet)) {
                $entry
            }
        }

        $rawGroups = foreach ($groupDefinition in @($groupDefinitions | Sort-Object Order)) {
            $groupEntries = @($orderedEntries | Where-Object GroupKey -eq $groupDefinition.Name)
            if ($groupEntries.Count -eq 0) {
                continue
            }

            $groupResult = [pscustomobject]@{
                Group = $groupDefinition.Title
                GroupKey = $groupDefinition.Name
                Description = $groupDefinition.Description
                CmdletCount = $groupEntries.Count
                Cmdlets = $groupEntries
            }

            $groupResult = Add-M365TypeName -InputObject $groupResult -TypeName 'M365Admin.CommandCatalog.Group'
            $groupResult
        }

        return Resolve-M365AdminOutput -DefaultValue @($orderedEntries) -RawValue @($rawGroups) -Raw:$Raw -RawJson:$RawJson
    }
}