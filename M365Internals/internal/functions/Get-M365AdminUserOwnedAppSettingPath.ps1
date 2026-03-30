function Get-M365AdminUserOwnedAppSettingPath {
    <#
    .SYNOPSIS
        Resolves the admin-center path for a user-owned apps and services setting.

    .DESCRIPTION
        Maps the public `Get-M365AdminUserOwnedAppSetting` and
        `Set-M365AdminUserOwnedAppSetting` names to the corresponding Microsoft 365 admin center
        endpoint paths.

    .PARAMETER Name
        The user-owned apps and services setting name to resolve.

    .EXAMPLE
        Get-M365AdminUserOwnedAppSettingPath -Name StoreAccess

        Returns the user-owned apps store-access endpoint path.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('AutoClaimPolicy', 'InAppPurchasesAllowed', 'StoreAccess')]
        [string]$Name
    )

    process {
        switch ($Name) {
            'StoreAccess' { '/admin/api/settings/apps/store' }
            'InAppPurchasesAllowed' { '/admin/api/storesettings/iwpurchaseallowed' }
            'AutoClaimPolicy' { '/fd/m365licensing/v1/policies/autoclaim' }
        }
    }
}
