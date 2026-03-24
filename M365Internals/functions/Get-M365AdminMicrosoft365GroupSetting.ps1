function Get-M365AdminMicrosoft365GroupSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 Groups settings from the Org settings experience.

    .DESCRIPTION
        Reads the combined payloads used by the Microsoft 365 Groups Org settings flyout,
        including guest access and ownerless group policy data.

    .PARAMETER Name
        The Microsoft 365 Groups payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminMicrosoft365GroupSetting

        Retrieves the full Microsoft 365 Groups settings payload set.

    .OUTPUTS
        Object
        Returns the selected Microsoft 365 Groups payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'GuestAccess', 'GuestUserPolicy', 'OwnerlessGroupPolicy')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        $tenantId = Get-M365PortalTenantId

        function Get-OwnerlessGroupPolicyResult {
            try {
                $result = Get-M365AdminPortalData -Path ("/fd/speedwayB2Service/v1.0/organizations('TID:{0}')/policy/ownerlessGroupPolicy" -f $tenantId) -CacheKey 'M365AdminMicrosoft365GroupSetting:OwnerlessGroupPolicy' -Force:$Force
                if ($null -ne $result) {
                    return $result
                }
            }
            catch {
                if ($_.Exception.Message -notmatch '404') {
                    throw
                }
            }

            New-M365AdminUnavailableResult -Name 'OwnerlessGroupPolicy' -Description 'The ownerless groups policy has not been initialized in the current tenant.' -Reason 'Optional'
        }

        switch ($Name) {
            'All' {
                $guestAccess = Get-M365AdminPortalData -Path '/admin/api/settings/security/o365guestuser' -CacheKey 'M365AdminMicrosoft365GroupSetting:GuestAccess' -Force:$Force
                $guestUserPolicy = Get-M365AdminPortalData -Path '/admin/api/Settings/security/guestUserPolicy' -CacheKey 'M365AdminMicrosoft365GroupSetting:GuestUserPolicy' -Force:$Force
                $ownerlessGroupPolicy = Get-OwnerlessGroupPolicyResult

                $result = [pscustomobject]@{
                    GuestAccess          = $guestAccess
                    GuestUserPolicy      = $guestUserPolicy
                    OwnerlessGroupPolicy = $ownerlessGroupPolicy
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.Microsoft365GroupSetting'
            }
            'GuestAccess' {
                $path = '/admin/api/settings/security/o365guestuser'
            }
            'GuestUserPolicy' {
                $path = '/admin/api/Settings/security/guestUserPolicy'
            }
            'OwnerlessGroupPolicy' {
                return Get-OwnerlessGroupPolicyResult
            }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminMicrosoft365GroupSetting:$Name" -Force:$Force
    }
}