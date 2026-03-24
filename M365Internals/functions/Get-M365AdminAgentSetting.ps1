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

    .PARAMETER Raw
        Returns the underlying shared or leaf payload bundle for the selected page composition
        when it makes sense to do so.

    .EXAMPLE
        Get-M365AdminAgentSetting

        Retrieves the primary Agents settings payload set.

    .EXAMPLE
        Get-M365AdminAgentSetting -Raw

        Retrieves the underlying shared settings payload and templates payload bundle without
        reducing it to the default page-oriented view.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw
    )

    process {
        function Get-AgentSettingsData {
            Get-M365AdminPortalData -Path '/fd/addins/api/v2/settings?keys=MetaOSCopilotExtensibilitySettings,AreFirstPartyAppsAllowed,AreThirdPartyAppsAllowed,AreLOBAppsAllowed,AdminRoles,AllowOrgWideSharing' -CacheKey 'M365AdminAgentSetting:Settings' -Force:$Force
        }

        function Get-AgentSettingResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [scriptblock]$ScriptBlock
            )

            try {
                $result = & $ScriptBlock
                if ($null -ne $result) {
                    return $result
                }

                New-M365AdminUnavailableResult -Name $ResultName -Description 'The Agents settings endpoint returned no data for this section in the current tenant.' -Reason 'TenantSpecific'
            }
            catch {
                New-M365AdminUnavailableResult -Name $ResultName -Description 'The Agents settings endpoint failed during direct retrieval. The portal may be returning a transient error for this section.' -Reason 'Transient' -ErrorMessage $_.Exception.Message
            }
        }

        function Get-TemplatesPayload {
            $result = [pscustomobject]@{
                Templates                = Get-AgentSettingResult -ResultName 'Templates' -ScriptBlock { Get-M365AdminPortalData -Path '/admin/api/agenttemplates/getagenttemplates' -CacheKey 'M365AdminAgentSetting:Templates' -Force:$Force }
                Policies                 = Get-AgentSettingResult -ResultName 'Policies' -ScriptBlock { Get-M365AdminPortalData -Path '/admin/api/agenttemplates/getpolicies?expand=true' -CacheKey 'M365AdminAgentSetting:TemplatePolicies' -Force:$Force }
                BillingAccounts          = Get-AgentSettingResult -ResultName 'BillingAccounts' -ScriptBlock { Get-M365AdminPortalData -Path '/admin/api/tenant/billingAccountsWithShell' -CacheKey 'M365AdminAgentSetting:TemplateBillingAccounts' -Force:$Force }
                AutoQuotaEnabled         = Get-AgentSettingResult -ResultName 'AutoQuotaEnabled' -ScriptBlock { Get-M365AdminPortalData -Path '/_api/SPOInternalUseOnly.TenantAdminSettings/AutoQuotaEnabled' -CacheKey 'M365AdminAgentSetting:AutoQuotaEnabled' -Force:$Force }
                CustomViewFilterDefaults = Get-AgentSettingResult -ResultName 'CustomViewFilterDefaults' -ScriptBlock { Get-M365AdminPortalData -Path '/admin/api/tenant/customviewfilterdefaults' -CacheKey 'M365AdminAgentSetting:CustomViewFilterDefaults' -Force:$Force }
                UserRoles                = Get-AgentSettingResult -ResultName 'UserRoles' -ScriptBlock { Invoke-M365RestMethod -Path '/admin/api/users/getuserroles' -Method Post -Body @{} }
            }

            return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.AgentSetting.Templates'
        }

        function Get-AllRawPayload {
            $result = [pscustomobject]@{
                SharedSettings = Get-AgentSettingsData
                Templates      = Get-TemplatesPayload
            }

            return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.AgentSetting.Raw'
        }

        switch ($Name) {
            'All' {
                if ($Raw) {
                    return Get-AllRawPayload
                }

                $result = [pscustomobject]@{
                    AllowedAgentTypes = Get-M365AdminAgentSetting -Name AllowedAgentTypes -Force:$Force
                    Sharing = Get-M365AdminAgentSetting -Name Sharing -Force:$Force
                    Templates = Get-M365AdminAgentSetting -Name Templates -Force:$Force
                    UserAccess = Get-M365AdminAgentSetting -Name UserAccess -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.AgentSetting'
            }
            'AllowedAgentTypes' {
                $settings = Get-AgentSettingsData
                if ($Raw) {
                    return $settings
                }

                $result = [pscustomobject]@{
                    AllowMicrosoftBuiltAgents = $settings.settings.areFirstPartyAppsAllowed
                    AllowExternalPublisherAgents = $settings.settings.areThirdPartyAppsAllowed
                    AllowOrgBuiltAgents = $settings.settings.areLOBAppsAllowed
                    RequiredAdminRoles = @($settings.settings.adminRoles)
                    Extensibility = $settings.settings.metaOSCopilotExtensibilitySettings
                    RawSettings = $settings
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.AgentSetting.AllowedAgentTypes'
            }
            'Sharing' {
                $settings = Get-AgentSettingsData
                if ($Raw) {
                    return $settings
                }

                $result = [pscustomobject]@{
                    IsSettingApplicable = $settings.settings.allowOrgWideSharing.isSettingApplicable
                    AssignmentCategory = $settings.settings.allowOrgWideSharing.userAssignmentCategory
                    Members = @($settings.settings.allowOrgWideSharing.members)
                    RawSettings = $settings
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.AgentSetting.Sharing'
            }
            'Templates' {
                return Get-TemplatesPayload
            }
            'UserAccess' {
                $settings = Get-AgentSettingsData
                if ($Raw) {
                    return $settings
                }

                $result = [pscustomobject]@{
                    IsApplicable = $settings.settings.metaOSCopilotExtensibilitySettings.isCopilotExtensibilityApplicable
                    AssignmentCategory = $settings.settings.metaOSCopilotExtensibilitySettings.userAssignmentCategory
                    Members = @($settings.settings.metaOSCopilotExtensibilitySettings.members)
                    RawSettings = $settings
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.AgentSetting.UserAccess'
            }
        }
    }
}