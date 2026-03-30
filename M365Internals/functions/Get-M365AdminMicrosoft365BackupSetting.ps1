function Get-M365AdminMicrosoft365BackupSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Microsoft 365 Backup settings.

    .DESCRIPTION
        Reads the Settings > Microsoft 365 Backup payloads that back subscription setup,
        feature state, and enhanced restore status.

    .PARAMETER Name
        The Microsoft 365 Backup payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw Microsoft 365 Backup payload for the selected section.

    .PARAMETER RawJson
        Returns the raw Microsoft 365 Backup payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminMicrosoft365BackupSetting

        Retrieves the primary Microsoft 365 Backup landing-page payloads.

    .OUTPUTS
        Object
        Returns the selected Microsoft 365 Backup payload.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    [OutputType([object[]])]
    param (
        [Parameter()]
        [ValidateSet('All', 'AzureSubscriptionPermissions', 'AzureSubscriptions', 'BillingFeature', 'EnhancedRestoreFeature', 'EnhancedRestoreStatus')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        if ($Name -eq 'All') {
            if ($Raw -or $RawJson) {
                $azureSubscriptions = Get-M365AdminPortalData -Path '/admin/api/syntexbilling/azureSubscriptions' -CacheKey 'M365AdminMicrosoft365BackupSetting:AzureSubscriptions' -Force:$Force
                $permissions = foreach ($subscription in @($azureSubscriptions.value)) {
                    [pscustomobject]@{
                        SubscriptionId = $subscription.subscriptionId
                        DisplayName    = $subscription.displayName
                        Permissions    = Get-M365AdminPortalData -Path ("/admin/api/syntexbilling/azureSubscriptions/{0}/permissions" -f $subscription.subscriptionId) -CacheKey ("M365AdminMicrosoft365BackupSetting:AzureSubscriptionPermissions:{0}" -f $subscription.subscriptionId) -Force:$Force
                    }
                }

                $result = [pscustomobject]@{
                    BillingFeature               = Get-M365AdminPortalData -Path "/_api/v2.1/billingFeatures('M365Backup')" -CacheKey 'M365AdminMicrosoft365BackupSetting:BillingFeature' -Force:$Force
                    AzureSubscriptions           = $azureSubscriptions
                    AzureSubscriptionPermissions = @($permissions)
                    EnhancedRestoreFeature       = Get-M365AdminPortalData -Path '/fd/enhancedRestorev2/v1/featureSetting' -CacheKey 'M365AdminMicrosoft365BackupSetting:EnhancedRestoreFeature' -Force:$Force
                    EnhancedRestoreStatus        = Get-M365AdminEnhancedRestoreStatus -Force:$Force -Raw
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.Microsoft365BackupSetting.Raw'
                return Resolve-M365AdminOutput -RawValue $result -Raw:$Raw -RawJson:$RawJson
            }

            $azureSubscriptions = Get-M365AdminPortalData -Path '/admin/api/syntexbilling/azureSubscriptions' -CacheKey 'M365AdminMicrosoft365BackupSetting:AzureSubscriptions' -Force:$Force
            $permissions = foreach ($subscription in @($azureSubscriptions.value)) {
                [pscustomobject]@{
                    SubscriptionId = $subscription.subscriptionId
                    DisplayName    = $subscription.displayName
                    Permissions    = Get-M365AdminPortalData -Path ("/admin/api/syntexbilling/azureSubscriptions/{0}/permissions" -f $subscription.subscriptionId) -CacheKey ("M365AdminMicrosoft365BackupSetting:AzureSubscriptionPermissions:{0}" -f $subscription.subscriptionId) -Force:$Force
                }
            }

            $result = [pscustomobject]@{
                BillingFeature               = Get-M365AdminPortalData -Path "/_api/v2.1/billingFeatures('M365Backup')" -CacheKey 'M365AdminMicrosoft365BackupSetting:BillingFeature' -Force:$Force
                AzureSubscriptions           = $azureSubscriptions
                AzureSubscriptionPermissions = @($permissions)
                EnhancedRestoreFeature       = Get-M365AdminPortalData -Path '/fd/enhancedRestorev2/v1/featureSetting' -CacheKey 'M365AdminMicrosoft365BackupSetting:EnhancedRestoreFeature' -Force:$Force
                EnhancedRestoreStatus        = Get-M365AdminEnhancedRestoreStatus -Force:$Force
            }

            $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.Microsoft365BackupSetting'
            return $result
        }

        if ($Name -eq 'AzureSubscriptionPermissions') {
            $azureSubscriptions = Get-M365AdminPortalData -Path '/admin/api/syntexbilling/azureSubscriptions' -CacheKey 'M365AdminMicrosoft365BackupSetting:AzureSubscriptions' -Force:$Force
            $permissions = foreach ($subscription in @($azureSubscriptions.value)) {
                [pscustomobject]@{
                    SubscriptionId = $subscription.subscriptionId
                    DisplayName    = $subscription.displayName
                    Permissions    = Get-M365AdminPortalData -Path ("/admin/api/syntexbilling/azureSubscriptions/{0}/permissions" -f $subscription.subscriptionId) -CacheKey ("M365AdminMicrosoft365BackupSetting:AzureSubscriptionPermissions:{0}" -f $subscription.subscriptionId) -Force:$Force
                }
            }

            return Resolve-M365AdminOutput -DefaultValue @($permissions) -Raw:$Raw -RawJson:$RawJson
        }

        if ($Name -eq 'EnhancedRestoreStatus') {
            return Get-M365AdminEnhancedRestoreStatus -Force:$Force -Raw:$Raw -RawJson:$RawJson
        }

        $path = switch ($Name) {
            'AzureSubscriptions' { '/admin/api/syntexbilling/azureSubscriptions' }
            'BillingFeature' { "/_api/v2.1/billingFeatures('M365Backup')" }
            'EnhancedRestoreFeature' { '/fd/enhancedRestorev2/v1/featureSetting' }
        }

        $result = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminMicrosoft365BackupSetting:$Name" -Force:$Force
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}