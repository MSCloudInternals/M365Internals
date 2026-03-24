function New-M365AdminUnavailableResult {
    <#
    .SYNOPSIS
        Creates a standardized unavailable-result object for public admin cmdlets.

    .DESCRIPTION
        Returns a consistent object shape for tenant-specific, optional, or otherwise
        unavailable admin-center results so callers can inspect availability without
        parsing free-form error text.

    .PARAMETER Name
        The section or result name that was unavailable.

    .PARAMETER Description
        A user-friendly description of why the result is unavailable.

    .PARAMETER Status
        The high-level availability state. Defaults to Unavailable.

    .PARAMETER Reason
        A short reason code such as TenantSpecific, Optional, or Transient.

    .PARAMETER ErrorMessage
        Optional raw error message associated with the unavailable result.

    .EXAMPLE
        New-M365AdminUnavailableResult -Name Qnas -Description 'This tenant returns 404.'

        Creates a standardized unavailable result object.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory result object only.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter()]
        [string]$Status = 'Unavailable',

        [Parameter()]
        [string]$Reason = 'TenantSpecific',

        [Parameter()]
        [string]$ErrorMessage
    )

    process {
        $result = [pscustomobject]@{
            Name        = $Name
            DataBacked  = $false
            Status      = $Status
            Reason      = $Reason
            Description = $Description
            Error       = $ErrorMessage
        }

        return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.UnavailableResult'
    }
}