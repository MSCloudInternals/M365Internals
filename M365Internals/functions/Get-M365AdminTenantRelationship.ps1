function Get-M365AdminTenantRelationship {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center tenant relationship data.

    .DESCRIPTION
        Reads multi-tenant organization and related relationship payloads from the admin center
        tenant relationships endpoints.

    .PARAMETER Name
        The tenant relationship payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminTenantRelationship -Name Tenants

        Retrieves the multi-tenant organization tenant list.

    .OUTPUTS
        Object
        Returns the selected tenant relationship payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('MultiTenantOrganization', 'OrganizationRelationships', 'RemovedTenants', 'Tenants', 'UserSyncAppOutboundDetails')]
        [string]$Name = 'MultiTenantOrganization',

        [Parameter()]
        [switch]$Force
    )

    process {
        $path = switch ($Name) {
            'MultiTenantOrganization' { '/admin/api/tenantRelationships/multiTenantOrganization' }
            'OrganizationRelationships' { '/admin/api/tenantRelationships/orgRelationships' }
            'RemovedTenants' { '/admin/api/tenantRelationships/multiTenantOrganization/removedTenants' }
            'Tenants' { '/admin/api/tenantRelationships/multiTenantOrganization/tenants' }
            'UserSyncAppOutboundDetails' { '/admin/api/tenantRelationships/userSyncApps/outboundDetails' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminTenantRelationship:$Name" -Force:$Force
    }
}