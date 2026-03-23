function Get-M365AdminAgentSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Agents settings data.

    .DESCRIPTION
        Reads the Agents > Settings payloads, including allowed agent types, sharing, templates,
        and user access configuration.

    .PARAMETER Name
        The settings payload or group to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminAgentSetting

        Retrieves the primary Agents settings payload set.

    .OUTPUTS
        Object
        Returns the selected Agents settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'AllowedAgentTypes', 'Sharing', 'Templates', 'UserAccess')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        function Get-AgentSettingsData {
            Get-M365AdminPortalData -Path '/fd/addins/api/v2/settings?keys=MetaOSCopilotExtensibilitySettings,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AdminRoles,AllowOrgWideSharing' -CacheKey 'M365AdminAgentSetting:Settings' -Force:$Force
        }

        switch ($Name) {
            'All' {
                return [pscustomobject]@{
                    AllowedAgentTypes = Get-M365AdminAgentSetting -Name AllowedAgentTypes -Force:$Force
                    Sharing = Get-M365AdminAgentSetting -Name Sharing -Force:$Force
                    Templates = Get-M365AdminAgentSetting -Name Templates -Force:$Force
                    UserAccess = Get-M365AdminAgentSetting -Name UserAccess -Force:$Force
                }
            }
            'AllowedAgentTypes' {
                $settings = Get-AgentSettingsData
                return [pscustomobject]@{
                    AllowMicrosoftBuiltAgents = $settings.settings.areFirstPartyAppsAllowed
                    AllowExternalPublisherAgents = $settings.settings.areThirdPartyAppsAllowed
                    AllowOrgBuiltAgents = $settings.settings.areLOBAppsAllowed
                    RequiredAdminRoles = @($settings.settings.adminRoles)
                    Extensibility = $settings.settings.metaOSCopilotExtensibilitySettings
                    RawSettings = $settings
                }
            }
            'Sharing' {
                $settings = Get-AgentSettingsData
                return [pscustomobject]@{
                    IsSettingApplicable = $settings.settings.allowOrgWideSharing.isSettingApplicable
                    AssignmentCategory = $settings.settings.allowOrgWideSharing.userAssignmentCategory
                    Members = @($settings.settings.allowOrgWideSharing.members)
                    RawSettings = $settings
                }
            }
            'Templates' {
                return [pscustomobject]@{
                    Templates = Get-M365AdminPortalData -Path '/admin/api/agenttemplates/getagenttemplates' -CacheKey 'M365AdminAgentSetting:Templates' -Force:$Force
                    Policies = Get-M365AdminPortalData -Path '/admin/api/agenttemplates/getpolicies?expand=true' -CacheKey 'M365AdminAgentSetting:TemplatePolicies' -Force:$Force
                    BillingAccounts = Get-M365AdminPortalData -Path '/admin/api/tenant/billingAccountsWithShell' -CacheKey 'M365AdminAgentSetting:TemplateBillingAccounts' -Force:$Force
                    AutoQuotaEnabled = Get-M365AdminPortalData -Path '/_api/SPOInternalUseOnly.TenantAdminSettings/AutoQuotaEnabled' -CacheKey 'M365AdminAgentSetting:AutoQuotaEnabled' -Force:$Force
                    CustomViewFilterDefaults = Get-M365AdminPortalData -Path '/admin/api/tenant/customviewfilterdefaults' -CacheKey 'M365AdminAgentSetting:CustomViewFilterDefaults' -Force:$Force
                    UserRoles = Invoke-M365RestMethod -Path '/admin/api/users/getuserroles' -Method Post -Body @{}
                }
            }
            'UserAccess' {
                $settings = Get-AgentSettingsData
                return [pscustomobject]@{
                    IsApplicable = $settings.settings.metaOSCopilotExtensibilitySettings.isCopilotExtensibilityApplicable
                    AssignmentCategory = $settings.settings.metaOSCopilotExtensibilitySettings.userAssignmentCategory
                    Members = @($settings.settings.metaOSCopilotExtensibilitySettings.members)
                    RawSettings = $settings
                }
            }
        }
    }
}