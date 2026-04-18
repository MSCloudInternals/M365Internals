function New-M365AdminResultBundle {
    <#
    .SYNOPSIS
        Builds a stable grouped output object for admin-center bundle results.

    .DESCRIPTION
        Creates a typed bundle object that exposes grouped leaf results, the available item
        names, and an optional raw payload bundle for callers that need the unshaped data.

    .PARAMETER TypeName
        The specific PowerShell type name to add to the grouped result.

    .PARAMETER Category
        The functional category represented by the bundle.

    .PARAMETER Items
        The shaped child results keyed by item name.

    .PARAMETER RawData
        The raw child payload bundle keyed by item name.

    .EXAMPLE
        New-M365AdminResultBundle -TypeName 'M365Admin.AppSetting' -Category 'App settings' -Items $items -RawData $rawBundle

        Creates the grouped default result for a multi-item settings surface.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates in-memory bundle objects only and does not change external state.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$TypeName,

        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Items,

        [Parameter()]
        [AllowNull()]
        $RawData
    )

    process {
        $properties = [ordered]@{
            Category       = $Category
            AvailableItems = @($Items.Keys)
        }

        foreach ($entry in @($Items.GetEnumerator())) {
            $properties[$entry.Key] = $entry.Value
        }

        if ($PSBoundParameters.ContainsKey('RawData')) {
            $properties.RawData = $RawData
        }

        $result = [pscustomobject]$properties
        $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.BundleResult'
        return Add-M365TypeName -InputObject $result -TypeName $TypeName
    }
}