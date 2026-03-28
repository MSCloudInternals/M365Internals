function Get-M365AdminUserOwnedAppSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center user-owned apps and services settings.

    .DESCRIPTION
        Reads the store, in-app purchase, and auto-claim licensing policy payloads used by
        the user-owned apps and services experience in the Microsoft 365 admin center.

    .PARAMETER Name
        The user-owned apps and services payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminUserOwnedAppSetting

        Retrieves the grouped store, in-app purchase, and auto-claim policy payloads.

    .OUTPUTS
        Object
        Returns the selected user-owned apps and services payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'AutoClaimPolicy', 'InAppPurchasesAllowed', 'StoreAccess')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        $bypassCache = $Force.IsPresent

        function Get-UserOwnedAppSettingResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [string]$Path
            )

            try {
                return Get-M365AdminPortalData -Path $Path -CacheKey "M365AdminUserOwnedAppSetting:$ResultName" -Force:$bypassCache
            }
            catch {
                return New-M365AdminUnavailableResult -Name $ResultName -Description 'This user-owned apps and services endpoint currently does not return a usable payload in the current tenant.' -Reason 'TenantSpecific' -ErrorMessage $_.Exception.Message
            }
        }

        switch ($Name) {
            'All' {
                $result = [pscustomobject]@{
                    StoreAccess           = Get-UserOwnedAppSettingResult -ResultName 'StoreAccess' -Path (Get-M365AdminUserOwnedAppSettingPath -Name StoreAccess)
                    InAppPurchasesAllowed = Get-UserOwnedAppSettingResult -ResultName 'InAppPurchasesAllowed' -Path (Get-M365AdminUserOwnedAppSettingPath -Name InAppPurchasesAllowed)
                    AutoClaimPolicy       = Get-UserOwnedAppSettingResult -ResultName 'AutoClaimPolicy' -Path (Get-M365AdminUserOwnedAppSettingPath -Name AutoClaimPolicy)
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.UserOwnedAppSetting'
            }
        }

        $path = Get-M365AdminUserOwnedAppSettingPath -Name $Name
        Get-UserOwnedAppSettingResult -ResultName $Name -Path $path
    }
}
