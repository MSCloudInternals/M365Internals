function Get-M365AdminCopilotSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Copilot settings data.

    .DESCRIPTION
        Reads the Copilot > Settings optimize and view-all payloads used by the deployment and
        settings management experience.

    .PARAMETER Name
        The settings payload or tab to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminCopilotSetting

        Retrieves the primary Copilot settings payload set.

    .OUTPUTS
        Object
        Returns the selected Copilot settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('AIBaselineSummary', 'All', 'AuditEnabled', 'AzureSubscriptions', 'CopilotChatBillingPolicy', 'DefaultDlpPolicy', 'Dismissed', 'Optimize', 'PurviewForAISetting', 'Recommendations', 'SecurityCopilotAuth', 'ViewAll')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        function Get-CopilotResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [scriptblock]$ScriptBlock
            )

            try {
                & $ScriptBlock
            }
            catch {
                [pscustomobject]@{
                    Name = $ResultName
                    DataBacked = $false
                    Error = $_.Exception.Message
                }
            }
        }

        function Get-PurviewAIBaselineSummary {
            param (
                [Parameter(Mandatory)]
                [string]$CacheKey,

                [Parameter(Mandatory)]
                [switch]$BypassCache
            )

            $purviewHeaders = @{
                tenantid = $tenantId
                'x-tid' = $tenantId
                'client-type' = 'purview'
                'x-clientpage' = '/'
                'client-version' = '1.0.2774.1'
                'x-tabvisible' = 'visible'
                'x-clientpkgversion' = ''
                'client-request-id' = [guid]::NewGuid().ToString()
            }

            Get-M365AdminPortalData -Path '/fd/purview/apiproxy/cpm/v1.0/Tenant/AIBaselineSummary' -CacheKey $CacheKey -Headers $purviewHeaders -Force:$BypassCache
        }

        $tenantId = Get-M365PortalTenantId
        $windowEnd = (Get-Date).ToUniversalTime()
        $windowStart = $windowEnd.AddDays(-31)
        $policyFilter = [uri]::EscapeDataString("Identity eq 'Default DLP policy - Protect sensitive M365 Copilot interactions'")
        $purviewFilter14 = [uri]::EscapeDataString("PurviewAIScenario eq 'P4AIAdhocQuery14' and HostNames eq '' and SensitiveInfoTypes eq 'None'")
        $startTime = [uri]::EscapeDataString($windowStart.ToString('o'))
        $endTime = [uri]::EscapeDataString($windowEnd.ToString('o'))

        switch ($Name) {
            'All' {
                return [pscustomobject]@{
                    Optimize = Get-M365AdminCopilotSetting -Name Optimize -Force:$Force
                    ViewAll = Get-M365AdminCopilotSetting -Name ViewAll -Force:$Force
                }
            }
            'Recommendations' {
                return Get-M365AdminPortalData -Path '/admin/api/recommendations/m365/ccs' -CacheKey 'M365AdminCopilotSetting:Recommendations' -Force:$Force
            }
            'Dismissed' {
                return Get-M365AdminPortalData -Path '/admin/api/copilotsettings/settings/dismissed' -CacheKey 'M365AdminCopilotSetting:Dismissed' -Force:$Force
            }
            'SecurityCopilotAuth' {
                return Get-M365AdminPortalData -Path '/admin/api/copilotsettings/securitycopilot/auth' -CacheKey 'M365AdminCopilotSetting:SecurityCopilotAuth' -Force:$Force
            }
            'AzureSubscriptions' {
                return Get-M365AdminPortalData -Path '/admin/api/syntexbilling/azureSubscriptions' -CacheKey 'M365AdminCopilotSetting:AzureSubscriptions' -Force:$Force
            }
            'CopilotChatBillingPolicy' {
                return Get-M365AdminPortalData -Path '/_api/v2.1/billingPolicies?feature=M365CopilotChat' -CacheKey 'M365AdminCopilotSetting:CopilotChatBillingPolicy' -Force:$Force
            }
            'AuditEnabled' {
                return Get-M365AdminPortalData -Path '/fd/purview/apiproxy/adtsch/AuditEnabled' -CacheKey 'M365AdminCopilotSetting:AuditEnabled' -Force:$Force
            }
            'AIBaselineSummary' {
                return Get-CopilotResult -ResultName 'AIBaselineSummary' -ScriptBlock { Get-PurviewAIBaselineSummary -CacheKey 'M365AdminCopilotSetting:AIBaselineSummary' -BypassCache:$Force }
            }
            'PurviewForAISetting' {
                return Get-CopilotResult -ResultName 'PurviewForAISetting' -ScriptBlock { Get-M365AdminPortalData -Path "/fd/purview/apiproxy/di/find/PurviewForAISetting?tenantId=$tenantId" -CacheKey 'M365AdminCopilotSetting:PurviewForAISetting' -Force:$Force }
            }
            'DefaultDlpPolicy' {
                return Get-CopilotResult -ResultName 'DefaultDlpPolicy' -ScriptBlock { Get-M365AdminPortalData -Path "/fd/purview/apiproxy/di/find/DlpCompliancePolicy?tenantId=$tenantId&filter=$policyFilter" -CacheKey 'M365AdminCopilotSetting:DefaultDlpPolicy' -Force:$Force }
            }
            'Optimize' {
                return [pscustomobject]@{
                    Recommendations = Get-M365AdminCopilotSetting -Name Recommendations -Force:$Force
                    Dismissed = Get-M365AdminCopilotSetting -Name Dismissed -Force:$Force
                    SecurityCopilotAuth = Get-M365AdminCopilotSetting -Name SecurityCopilotAuth -Force:$Force
                    AzureSubscriptions = Get-M365AdminCopilotSetting -Name AzureSubscriptions -Force:$Force
                    CopilotChatBillingPolicy = Get-M365AdminCopilotSetting -Name CopilotChatBillingPolicy -Force:$Force
                    AuditEnabled = Get-CopilotResult -ResultName 'AuditEnabled' -ScriptBlock { Get-M365AdminCopilotSetting -Name AuditEnabled -Force:$Force }
                    AIBaselineSummary = Get-M365AdminCopilotSetting -Name AIBaselineSummary -Force:$Force
                    PurviewForAISetting = Get-M365AdminCopilotSetting -Name PurviewForAISetting -Force:$Force
                    ComplianceRecommendation = Get-CopilotResult -ResultName 'ComplianceRecommendation' -ScriptBlock { Get-M365AdminPortalData -Path "/fd/purview/apiproxy/di/find/PurviewForAI?tenantId=$tenantId&filter=$purviewFilter14&startTime=$startTime&endTime=$endTime" -CacheKey 'M365AdminCopilotSetting:ComplianceRecommendation' -Force:$Force }
                    DefaultDlpPolicy = Get-M365AdminCopilotSetting -Name DefaultDlpPolicy -Force:$Force
                }
            }
            'ViewAll' {
                return [pscustomobject]@{
                    Recommendations = Get-M365AdminCopilotSetting -Name Recommendations -Force:$Force
                    Dismissed = Get-M365AdminCopilotSetting -Name Dismissed -Force:$Force
                    SecurityCopilotAuth = Get-M365AdminCopilotSetting -Name SecurityCopilotAuth -Force:$Force
                    AzureSubscriptions = Get-M365AdminCopilotSetting -Name AzureSubscriptions -Force:$Force
                    CopilotChatBillingPolicy = Get-M365AdminCopilotSetting -Name CopilotChatBillingPolicy -Force:$Force
                }
            }
        }
    }
}