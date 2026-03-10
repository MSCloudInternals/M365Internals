function Get-M365AdminVivaSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Viva settings data.

    .DESCRIPTION
        Reads Viva-related payloads from the admin center Viva endpoints captured in the settings
        HAR.

    .PARAMETER Name
        The Viva payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminVivaSetting -Name Modules

        Retrieves the Viva modules payload.

    .OUTPUTS
        Object
        Returns the selected Viva payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('GlintClient', 'Modules', 'Roles')]
        [string]$Name = 'Modules',

        [Parameter()]
        [switch]$Force
    )

    process {
        $path = switch ($Name) {
            'GlintClient' { '/admin/api/viva/glint/lookupClient' }
            'Modules' { '/admin/api/viva/modules' }
            'Roles' { '/admin/api/viva/roles' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminVivaSetting:$Name" -Headers (Get-M365PortalContextHeaders -Context Viva) -Force:$Force
    }
}