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

    .PARAMETER Raw
        Returns the raw user-owned apps payload for the selected section.

    .PARAMETER RawJson
        Returns the raw user-owned apps payload serialized as formatted JSON.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
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
                return New-M365AdminUnavailableResultFromError -Name $ResultName -Area 'user-owned apps and services setting' -DefaultDescription 'This user-owned apps and services endpoint currently does not return a usable payload in the current tenant.' -ErrorMessage $_.Exception.Message
            }
        }

        function Convert-UserOwnedAppSettingResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                $ResultValue
            )

            if ($ResultValue.PSObject.TypeNames -contains 'M365Admin.UnavailableResult') {
                return $ResultValue
            }

            switch ($ResultName) {
                'StoreAccess' {
                    if ($ResultValue -is [bool]) {
                        return [bool]$ResultValue
                    }

                    if ($ResultValue.PSObject.Properties.Name -contains 'Enabled') {
                        return [bool]$ResultValue.Enabled
                    }
                }
            }

            return $ResultValue
        }

        switch ($Name) {
            'All' {
                $rawResult = [pscustomobject]@{
                    StoreAccess           = Get-UserOwnedAppSettingResult -ResultName 'StoreAccess' -Path (Get-M365AdminUserOwnedAppSettingPath -Name StoreAccess)
                    InAppPurchasesAllowed = Get-UserOwnedAppSettingResult -ResultName 'InAppPurchasesAllowed' -Path (Get-M365AdminUserOwnedAppSettingPath -Name InAppPurchasesAllowed)
                    AutoClaimPolicy       = Get-UserOwnedAppSettingResult -ResultName 'AutoClaimPolicy' -Path (Get-M365AdminUserOwnedAppSettingPath -Name AutoClaimPolicy)
                }

                if ($Raw -or $RawJson) {
                    $rawResult = Add-M365TypeName -InputObject $rawResult -TypeName 'M365Admin.UserOwnedAppSetting.Raw'
                    return Resolve-M365AdminOutput -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
                }

                $result = [pscustomobject]@{
                    StoreAccess           = Convert-UserOwnedAppSettingResult -ResultName 'StoreAccess' -ResultValue $rawResult.StoreAccess
                    InAppPurchasesAllowed = Convert-UserOwnedAppSettingResult -ResultName 'InAppPurchasesAllowed' -ResultValue $rawResult.InAppPurchasesAllowed
                    AutoClaimPolicy       = Convert-UserOwnedAppSettingResult -ResultName 'AutoClaimPolicy' -ResultValue $rawResult.AutoClaimPolicy
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.UserOwnedAppSetting'
                return $result
            }
        }

        $path = Get-M365AdminUserOwnedAppSettingPath -Name $Name
        $rawResult = Get-UserOwnedAppSettingResult -ResultName $Name -Path $path
        $result = Convert-UserOwnedAppSettingResult -ResultName $Name -ResultValue $rawResult
        return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
    }
}
