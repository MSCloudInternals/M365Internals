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

    .PARAMETER Raw
        Returns the raw tenant relationship payload for the selected view.

    .PARAMETER RawJson
        Returns the raw tenant relationship payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminTenantRelationship -Name Tenants

        Retrieves the multi-tenant organization tenant list.

    .EXAMPLE
        Get-M365AdminTenantRelationship -Name MultiTenantCollaboration

        Retrieves the grouped collaboration view. Tenant-disabled sub-sections are returned as
        standardized unavailable result objects instead of failing the full result.

    .OUTPUTS
        Object
        Returns the selected tenant relationship payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('MultiTenantCollaboration', 'MultiTenantOrganization', 'OrganizationRelationships', 'RemovedTenants', 'Tenants', 'UserSyncAppOutboundDetails')]
        [string]$Name = 'MultiTenantOrganization',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $bypassCache = $Force.IsPresent

        function Get-TenantRelationshipResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [string]$Path
            )

            try {
                Get-M365AdminPortalData -Path $Path -CacheKey "M365AdminTenantRelationship:$ResultName" -Force:$bypassCache
            }
            catch {
                return New-M365AdminUnavailableResult -Name $ResultName -Description 'The tenant relationship endpoint did not return data for this tenant configuration.' -Reason 'TenantSpecific' -ErrorMessage $_.Exception.Message
            }
        }

        if ($Name -eq 'MultiTenantCollaboration') {
            $multiTenantOrganization = Get-TenantRelationshipResult -ResultName 'MultiTenantOrganization' -Path '/admin/api/tenantRelationships/multiTenantOrganization'
            $tenants = Get-TenantRelationshipResult -ResultName 'Tenants' -Path '/admin/api/tenantRelationships/multiTenantOrganization/tenants'
            $removedTenants = Get-TenantRelationshipResult -ResultName 'RemovedTenants' -Path '/admin/api/tenantRelationships/multiTenantOrganization/removedTenants'
            $userSyncAppOutboundDetails = Get-TenantRelationshipResult -ResultName 'UserSyncAppOutboundDetails' -Path '/admin/api/tenantRelationships/userSyncApps/outboundDetails'

            $result = [pscustomobject]@{
                MultiTenantOrganization   = $multiTenantOrganization
                Tenants                   = $tenants
                RemovedTenants            = $removedTenants
                UserSyncAppOutboundDetails = $userSyncAppOutboundDetails
            }

            $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.TenantRelationship.MultiTenantCollaboration'
            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
        }

        $path = switch ($Name) {
            'MultiTenantOrganization' { '/admin/api/tenantRelationships/multiTenantOrganization' }
            'OrganizationRelationships' { '/admin/api/tenantRelationships/orgRelationships' }
            'RemovedTenants' { '/admin/api/tenantRelationships/multiTenantOrganization/removedTenants' }
            'Tenants' { '/admin/api/tenantRelationships/multiTenantOrganization/tenants' }
            'UserSyncAppOutboundDetails' { '/admin/api/tenantRelationships/userSyncApps/outboundDetails' }
        }

        $result = Get-TenantRelationshipResult -ResultName $Name -Path $path
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}