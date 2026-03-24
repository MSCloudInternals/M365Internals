function Add-M365TypeName {
    <#
    .SYNOPSIS
        Adds a PowerShell type name to an object.

    .DESCRIPTION
        Inserts a custom type name at the top of the object's PSTypeNames collection so
        public cmdlets can opt into stable formatting and output contracts without wrapping
        the original payload in an additional envelope object.

    .PARAMETER InputObject
        The object to annotate with the provided type name.

    .PARAMETER TypeName
        The PowerShell type name to insert.

    .EXAMPLE
        Add-M365TypeName -InputObject $result -TypeName 'M365Admin.Sample'

        Adds the custom type name to the object and returns it.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$TypeName
    )

    process {
        if ($null -eq $InputObject) {
            return $null
        }

        if ($InputObject.PSObject.TypeNames[0] -ne $TypeName) {
            $InputObject.PSObject.TypeNames.Insert(0, $TypeName)
        }

        return $InputObject
    }
}