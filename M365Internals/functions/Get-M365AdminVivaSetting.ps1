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
        function Get-VivaSettingResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [string]$Path,

                [Parameter()]
                [hashtable]$ResultHeaders
            )

            $result = Get-M365AdminPortalData -Path $Path -CacheKey "M365AdminVivaSetting:$ResultName" -Headers $ResultHeaders -Force:$Force
            if ($null -ne $result) {
                return $result
            }

            return New-M365AdminUnavailableResult -Name $ResultName -Description 'The Viva endpoint returned no data for this setting in the current tenant.' -Reason 'TenantSpecific'
        }

        if ($Name -eq 'All') {
            $result = [pscustomobject]@{
                Modules     = Get-VivaSettingResult -ResultName 'Modules' -Path '/admin/api/viva/modules' -ResultHeaders (Get-M365PortalContextHeaders -Context Viva)
                Roles       = Get-VivaSettingResult -ResultName 'Roles' -Path '/admin/api/viva/roles' -ResultHeaders (Get-M365PortalContextHeaders -Context Viva)
                GlintClient = Get-VivaSettingResult -ResultName 'GlintClient' -Path '/admin/api/viva/glint/lookupClient' -ResultHeaders (Get-M365PortalContextHeaders -Context Viva)
                AccountSkus = Get-M365AdminTenantSetting -Name AccountSkus -Force:$Force
            }

            return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.VivaSetting'
        }

        $path = switch ($Name) {
            'AccountSkus' { '/admin/api/tenant/accountSkus' }
            'GlintClient' { '/admin/api/viva/glint/lookupClient' }
            'Modules' { '/admin/api/viva/modules' }
            'Roles' { '/admin/api/viva/roles' }
        }

        $headers = if ($Name -eq 'AccountSkus') { $null } else { Get-M365PortalContextHeaders -Context Viva }
        Get-VivaSettingResult -ResultName $Name -Path $path -ResultHeaders $headers
    }
}