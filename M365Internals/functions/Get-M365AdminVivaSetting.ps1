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
        [ValidateSet('AccountSkus', 'All', 'GlintClient', 'Modules', 'Roles')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        if ($Name -eq 'All') {
            [pscustomobject]@{
                Modules     = Get-M365AdminPortalData -Path '/admin/api/viva/modules' -CacheKey 'M365AdminVivaSetting:Modules' -Headers (Get-M365PortalContextHeaders -Context Viva) -Force:$Force
                Roles       = Get-M365AdminPortalData -Path '/admin/api/viva/roles' -CacheKey 'M365AdminVivaSetting:Roles' -Headers (Get-M365PortalContextHeaders -Context Viva) -Force:$Force
                GlintClient = Get-M365AdminPortalData -Path '/admin/api/viva/glint/lookupClient' -CacheKey 'M365AdminVivaSetting:GlintClient' -Headers (Get-M365PortalContextHeaders -Context Viva) -Force:$Force
                AccountSkus = Get-M365AdminTenantSetting -Name AccountSkus -Force:$Force
            }
            return
        }

        $path = switch ($Name) {
            'AccountSkus' { '/admin/api/tenant/accountSkus' }
            'GlintClient' { '/admin/api/viva/glint/lookupClient' }
            'Modules' { '/admin/api/viva/modules' }
            'Roles' { '/admin/api/viva/roles' }
        }

        $headers = if ($Name -eq 'AccountSkus') { $null } else { Get-M365PortalContextHeaders -Context Viva }
        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminVivaSetting:$Name" -Headers $headers -Force:$Force
    }
}