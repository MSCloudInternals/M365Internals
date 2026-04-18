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
        $backupHeaders = Get-M365PortalContextHeaders -Context EnhancedRestore

        if ($Name -eq 'All') {
            $azureSubscriptions = Get-M365AdminPortalData -Path '/admin/api/syntexbilling/azureSubscriptions' -CacheKey 'M365AdminMicrosoft365BackupSetting:AzureSubscriptions' -Headers $backupHeaders -Force:$Force
            $permissions = foreach ($subscription in @($azureSubscriptions.value)) {
                [pscustomobject]@{
                    SubscriptionId = $subscription.subscriptionId
                    DisplayName    = $subscription.displayName
                    Permissions    = Get-M365AdminPortalData -Path ("/admin/api/syntexbilling/azureSubscriptions/{0}/permissions" -f $subscription.subscriptionId) -CacheKey ("M365AdminMicrosoft365BackupSetting:AzureSubscriptionPermissions:{0}" -f $subscription.subscriptionId) -Headers $backupHeaders -Force:$Force
                }
            }

            $rawResult = [ordered]@{
                BillingFeature               = Get-M365AdminPortalData -Path "/_api/v2.1/billingFeatures('M365Backup')" -CacheKey 'M365AdminMicrosoft365BackupSetting:BillingFeature' -Headers $backupHeaders -Force:$Force
                AzureSubscriptions           = $azureSubscriptions
                AzureSubscriptionPermissions = @($permissions)
                EnhancedRestoreFeature       = Get-M365AdminPortalData -Path '/fd/enhancedRestorev2/v1/featureSetting' -CacheKey 'M365AdminMicrosoft365BackupSetting:EnhancedRestoreFeature' -Headers $backupHeaders -Force:$Force
                EnhancedRestoreStatus        = Get-M365AdminEnhancedRestoreStatus -Force:$Force -Raw
            }

            $items = [ordered]@{
                BillingFeature = ConvertTo-M365AdminResult -InputObject $rawResult.BillingFeature -TypeName 'M365Admin.Microsoft365BackupSetting.BillingFeature' -Category 'Microsoft 365 Backup' -ItemName 'BillingFeature' -Endpoint "/_api/v2.1/billingFeatures('M365Backup')"
                AzureSubscriptions = ConvertTo-M365AdminResult -InputObject $rawResult.AzureSubscriptions -TypeName 'M365Admin.Microsoft365BackupSetting.AzureSubscriptions' -Category 'Microsoft 365 Backup' -ItemName 'AzureSubscriptions' -Endpoint '/admin/api/syntexbilling/azureSubscriptions'
                AzureSubscriptionPermissions = ConvertTo-M365AdminResult -InputObject $rawResult.AzureSubscriptionPermissions -TypeName 'M365Admin.Microsoft365BackupSetting.AzureSubscriptionPermissions' -Category 'Microsoft 365 Backup' -ItemName 'AzureSubscriptionPermissions' -Endpoint '/admin/api/syntexbilling/azureSubscriptions/{subscriptionId}/permissions'
                EnhancedRestoreFeature = ConvertTo-M365AdminResult -InputObject $rawResult.EnhancedRestoreFeature -TypeName 'M365Admin.Microsoft365BackupSetting.EnhancedRestoreFeature' -Category 'Microsoft 365 Backup' -ItemName 'EnhancedRestoreFeature' -Endpoint '/fd/enhancedRestorev2/v1/featureSetting'
                EnhancedRestoreStatus = Get-M365AdminEnhancedRestoreStatus -Force:$Force
            }

            $result = New-M365AdminResultBundle -TypeName 'M365Admin.Microsoft365BackupSetting' -Category 'Microsoft 365 Backup' -Items $items -RawData ([pscustomobject]$rawResult)
            return Resolve-M365AdminOutput -DefaultValue $result -RawValue ([pscustomobject]$rawResult) -Raw:$Raw -RawJson:$RawJson
        }

        if ($Name -eq 'AzureSubscriptionPermissions') {
            $azureSubscriptions = Get-M365AdminPortalData -Path '/admin/api/syntexbilling/azureSubscriptions' -CacheKey 'M365AdminMicrosoft365BackupSetting:AzureSubscriptions' -Headers $backupHeaders -Force:$Force
            $permissions = foreach ($subscription in @($azureSubscriptions.value)) {
                [pscustomobject]@{
                    SubscriptionId = $subscription.subscriptionId
                    DisplayName    = $subscription.displayName
                    Permissions    = Get-M365AdminPortalData -Path ("/admin/api/syntexbilling/azureSubscriptions/{0}/permissions" -f $subscription.subscriptionId) -CacheKey ("M365AdminMicrosoft365BackupSetting:AzureSubscriptionPermissions:{0}" -f $subscription.subscriptionId) -Headers $backupHeaders -Force:$Force
                }
            }

            $result = ConvertTo-M365AdminResult -InputObject @($permissions) -TypeName 'M365Admin.Microsoft365BackupSetting.AzureSubscriptionPermissions' -Category 'Microsoft 365 Backup' -ItemName 'AzureSubscriptionPermissions' -Endpoint '/admin/api/syntexbilling/azureSubscriptions/{subscriptionId}/permissions'
            return Resolve-M365AdminOutput -DefaultValue $result -RawValue @($permissions) -Raw:$Raw -RawJson:$RawJson
        }

        if ($Name -eq 'EnhancedRestoreStatus') {
            return Get-M365AdminEnhancedRestoreStatus -Force:$Force -Raw:$Raw -RawJson:$RawJson
        }

        $path = switch ($Name) {
            'AzureSubscriptions' { '/admin/api/syntexbilling/azureSubscriptions' }
            'BillingFeature' { "/_api/v2.1/billingFeatures('M365Backup')" }
            'EnhancedRestoreFeature' { '/fd/enhancedRestorev2/v1/featureSetting' }
        }

        $rawResult = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminMicrosoft365BackupSetting:$Name" -Headers $backupHeaders -Force:$Force
        $result = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName ("M365Admin.Microsoft365BackupSetting.{0}" -f $Name) -Category 'Microsoft 365 Backup' -ItemName $Name -Endpoint $path
        return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
    }
}