function Get-M365AdminEdgeSiteList {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Microsoft Edge site list data.

    .DESCRIPTION
        Reads the Edge enterprise site list payloads used by the Org settings Microsoft Edge
        site lists experience.

    .PARAMETER Name
        The Edge site list payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminEdgeSiteList

        Retrieves the Edge enterprise site lists and notification payloads.

    .OUTPUTS
        Object
        Returns the selected Edge site list payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'Notifications', 'SiteLists')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        function Get-EdgeSiteListNotification {
            try {
                $result = Get-M365AdminPortalData -Path '/fd/edgeenterprisesitemanagement/api/v2/notifications' -CacheKey 'M365AdminEdgeSiteList:Notifications' -Force:$Force
                if ($null -ne $result) {
                    return $result
                }

                return New-M365AdminUnavailableResult -Name 'Notifications' -Description 'The Microsoft Edge site list notifications feed returned no data in the current tenant.' -Reason 'TenantSpecific'
            }
            catch {
                if ($_.Exception.Message -match '404') {
                    return New-M365AdminUnavailableResult -Name 'Notifications' -Description 'The Microsoft Edge site list notifications feed is not available in the current tenant.' -Reason 'TenantSpecific'
                }

                throw
            }
        }

        switch ($Name) {
            'All' {
                $siteLists = Get-M365AdminPortalData -Path '/fd/edgeenterprisesitemanagement/api/v2/emiesitelists' -CacheKey 'M365AdminEdgeSiteList:SiteLists' -Force:$Force
                $notifications = Get-EdgeSiteListNotification

                $result = [pscustomobject]@{
                    SiteLists     = $siteLists
                    Notifications = $notifications
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.EdgeSiteList'
            }
            'SiteLists' {
                $path = '/fd/edgeenterprisesitemanagement/api/v2/emiesitelists'
            }
            'Notifications' {
                return Get-EdgeSiteListNotification
            }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminEdgeSiteList:$Name" -Force:$Force
    }
}