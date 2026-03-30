function Get-M365AdminCopilotOverview {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Copilot overview data.

    .DESCRIPTION
        Reads the Copilot > Overview tabs and their backing payloads, including adoption,
        usage, discover, and Purview-backed security views.

    .PARAMETER Name
        The overview tab or payload group to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw Copilot overview payload for the selected section.

    .PARAMETER RawJson
        Returns the raw Copilot overview payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminCopilotOverview

        Retrieves the primary Copilot Overview payload set.

    .OUTPUTS
        Object
        Returns the selected Copilot Overview payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('About', 'All', 'Overview', 'Security', 'Usage')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
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
                New-M365AdminUnavailableResult -Name $ResultName -Description 'The Copilot overview section did not return a usable payload.' -Reason 'TenantSpecific' -ErrorMessage $_.Exception.Message
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
        $purviewFilter13 = [uri]::EscapeDataString("PurviewAIScenario eq 'P4AIAdhocQuery13' and appCategories eq 'Copilot' and appIdentities eq 'Copilot.MicrosoftCopilot,Copilot.M365Copilot'")
        $purviewFilter14 = [uri]::EscapeDataString("PurviewAIScenario eq 'P4AIAdhocQuery14' and HostNames eq '' and SensitiveInfoTypes eq 'None'")
        $purviewFilter15 = [uri]::EscapeDataString("PurviewAIScenario eq 'P4AIAdhocQuery15' and HostNames eq '' and SensitiveInfoTypes eq 'None'")
        $startTime = [uri]::EscapeDataString($windowStart.ToString('o'))
        $endTime = [uri]::EscapeDataString($windowEnd.ToString('o'))

        switch ($Name) {
            'All' {
                $result = [pscustomobject]@{
                    Overview = Get-M365AdminCopilotOverview -Name Overview -Force:$Force
                    Security = Get-M365AdminCopilotOverview -Name Security -Force:$Force
                    Usage = Get-M365AdminCopilotOverview -Name Usage -Force:$Force
                    About = Get-M365AdminCopilotOverview -Name About -Force:$Force
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotOverview'
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'Overview' {
                $result = [pscustomobject]@{
                    CopilotSettings = Get-M365AdminPortalData -Path '/admin/api/copilotsettings/settings' -CacheKey 'M365AdminCopilotOverview:CopilotSettings' -Force:$Force
                    PinPolicy = Get-M365AdminPortalData -Path '/admin/api/settings/company/copilotpolicy/pin' -CacheKey 'M365AdminCopilotOverview:PinPolicy' -Force:$Force
                    LicenseAssignmentDate = Get-M365AdminPortalData -Path '/admin/api/Copilot/getcopilotlicenseassignmentdate' -CacheKey 'M365AdminCopilotOverview:LicenseAssignmentDate' -Force:$Force
                    CapacityPackUsage = Get-M365AdminPortalData -Path '/_api/v2.1/copilot/capacitypack/checkUsage' -CacheKey 'M365AdminCopilotOverview:CapacityPackUsage' -Force:$Force
                    AdoptionSummary = Get-M365AdminPortalData -Path '/fd/IDEAsKnowledgeService/api/odata/v2.0.0/OrganizationM365CopilotAdoption' -CacheKey 'M365AdminCopilotOverview:AdoptionSummary' -Force:$Force
                    AdoptionByProducts = Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityName=getCopilotAdoptionByProductsV2' -CacheKey 'M365AdminCopilotOverview:AdoptionByProducts' -Force:$Force
                    AdoptionByDate = Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityName=getCopilotAdoptionByDateV2' -CacheKey 'M365AdminCopilotOverview:AdoptionByDate' -Force:$Force
                    CopilotChatAdoptionByPeriod = Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityName=getCopilotEDPAdoptionByPeriodV2' -CacheKey 'M365AdminCopilotOverview:CopilotChatAdoptionByPeriod' -Force:$Force
                    CopilotChatAdoptionByDate = Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityName=getCopilotEDPAdoptionByDateV2' -CacheKey 'M365AdminCopilotOverview:CopilotChatAdoptionByDate' -Force:$Force
                    ThumbsUpRate = Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityName=getCopilotThumbsUpRateByDate' -CacheKey 'M365AdminCopilotOverview:ThumbsUpRate' -Force:$Force
                    CopilotChatThumbsUpRate = Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityName=getCopilotEDPThumbsUpRateByDate' -CacheKey 'M365AdminCopilotOverview:CopilotChatThumbsUpRate' -Force:$Force
                    AgentActiveUsers = Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityName=getCopilotAgentActiveUserRL30DailyMetrics' -CacheKey 'M365AdminCopilotOverview:AgentActiveUsers' -Force:$Force
                    ActiveAgents = Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityName=getCopilotAgentActiveAgentRL30Metrics' -CacheKey 'M365AdminCopilotOverview:ActiveAgents' -Force:$Force
                    SubscribedSkus = Get-M365AdminPortalData -Path '/fd/MSGraph/v1.0/subscribedSkus' -CacheKey 'M365AdminCopilotOverview:SubscribedSkus' -Force:$Force
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotOverview.Overview'
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'Security' {
                $result = [pscustomobject]@{
                    PurviewBootInfo = Get-CopilotResult -ResultName 'PurviewBootInfo' -ScriptBlock { Get-M365AdminPortalData -Path '/fd/purview/api/boot/getNexusBootInfo' -CacheKey 'M365AdminCopilotOverview:PurviewBootInfo' -Force:$Force }
                    PurviewRoles = Get-CopilotResult -ResultName 'PurviewRoles' -ScriptBlock { Get-M365AdminPortalData -Path '/fd/purview/api/v2/auth/GetCachedRoles?refreshCache=false' -CacheKey 'M365AdminCopilotOverview:PurviewRoles' -Force:$Force }
                    PurviewSettings = Get-CopilotResult -ResultName 'PurviewSettings' -ScriptBlock { Get-M365AdminPortalData -Path "/fd/purview/apiproxy/di/find/PurviewForAISetting?tenantId=$tenantId" -CacheKey 'M365AdminCopilotOverview:PurviewSettings' -Force:$Force }
                    AIBaselineSummary = Get-CopilotResult -ResultName 'AIBaselineSummary' -ScriptBlock { Get-PurviewAIBaselineSummary -CacheKey 'M365AdminCopilotOverview:AIBaselineSummary' -BypassCache:$Force }
                    DefaultDlpPolicy = Get-CopilotResult -ResultName 'DefaultDlpPolicy' -ScriptBlock { Get-M365AdminPortalData -Path "/fd/purview/apiproxy/di/find/DlpCompliancePolicy?tenantId=$tenantId&filter=$policyFilter" -CacheKey 'M365AdminCopilotOverview:DefaultDlpPolicy' -Force:$Force }
                    SensitiveInfoTypes = Get-CopilotResult -ResultName 'SensitiveInfoTypes' -ScriptBlock { Get-M365AdminPortalData -Path "/fd/purview/apiproxy/di/find/DlpSensitiveInformationType?tenantId=$tenantId" -CacheKey 'M365AdminCopilotOverview:SensitiveInfoTypes' -Force:$Force }
                    OversharingRecommendation = Get-CopilotResult -ResultName 'OversharingRecommendation' -ScriptBlock { Get-M365AdminPortalData -Path "/fd/purview/apiproxy/di/find/PurviewForAI?tenantId=$tenantId&filter=$purviewFilter13&startTime=$startTime&endTime=$endTime" -CacheKey 'M365AdminCopilotOverview:OversharingRecommendation' -Force:$Force }
                    ComplianceRecommendation = Get-CopilotResult -ResultName 'ComplianceRecommendation' -ScriptBlock { Get-M365AdminPortalData -Path "/fd/purview/apiproxy/di/find/PurviewForAI?tenantId=$tenantId&filter=$purviewFilter14&startTime=$startTime&endTime=$endTime" -CacheKey 'M365AdminCopilotOverview:ComplianceRecommendation' -Force:$Force }
                    DataLeakRecommendation = Get-CopilotResult -ResultName 'DataLeakRecommendation' -ScriptBlock { Get-M365AdminPortalData -Path "/fd/purview/apiproxy/di/find/PurviewForAI?tenantId=$tenantId&filter=$purviewFilter15&startTime=$startTime&endTime=$endTime" -CacheKey 'M365AdminCopilotOverview:DataLeakRecommendation' -Force:$Force }
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotOverview.Security'
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'Usage' {
                $result = [pscustomobject]@{
                    Readiness = Get-M365AdminPortalData -Path '/fd/IDEAsKnowledgeService/api/odata/v1.0.0/OrganizationM365CopilotReadiness' -CacheKey 'M365AdminCopilotOverview:Readiness' -Force:$Force
                    AdoptionByProducts = Get-M365AdminPortalData -Path '/admin/api/reports/GetSummaryDataV3?ServiceId=MicrosoftOffice&CategoryId=MicrosoftCopilot&Report=CopilotActivityReport&active_view=CopilotAdoptionByProductsV2' -CacheKey 'M365AdminCopilotOverview:UsageAdoptionByProducts' -Force:$Force
                    AdoptionByDate = Get-M365AdminPortalData -Path '/admin/api/reports/GetSummaryDataV3?ServiceId=MicrosoftOffice&CategoryId=MicrosoftCopilot&Report=CopilotActivityReport&active_view=CopilotAdoptionByDateV2' -CacheKey 'M365AdminCopilotOverview:UsageAdoptionByDate' -Force:$Force
                    CopilotChatSummary = Get-M365AdminPortalData -Path '/admin/api/reports/GetSummaryDataV3?ServiceId=MicrosoftOffice&CategoryId=MicrosoftCopilotBCE&Report=CopilotBCEActivityReport&active_view=CopilotEDPAdoptionSummaryByPeriodV2' -CacheKey 'M365AdminCopilotOverview:CopilotChatSummary' -Force:$Force
                    CopilotChatAdoptionByPeriod = Get-M365AdminPortalData -Path '/admin/api/reports/GetSummaryDataV3?ServiceId=MicrosoftOffice&CategoryId=MicrosoftCopilotBCE&Report=CopilotBCEActivityReport&active_view=CopilotBCEAdoptionByPeriodV2' -CacheKey 'M365AdminCopilotOverview:UsageCopilotChatByPeriod' -Force:$Force
                    CopilotChatAdoptionByDate = Get-M365AdminPortalData -Path '/admin/api/reports/GetSummaryDataV3?ServiceId=MicrosoftOffice&CategoryId=MicrosoftCopilotBCE&Report=CopilotBCEActivityReport&active_view=CopilotBCEAdoptionByDateV2' -CacheKey 'M365AdminCopilotOverview:UsageCopilotChatByDate' -Force:$Force
                    SearchUsage = Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityname=getTenantSearchMetric&period=30&locale=en-US' -CacheKey 'M365AdminCopilotOverview:SearchUsage' -Force:$Force
                    CreditUsage = Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityname=getMessageConsumptionSummary&period=30&locale=en-US' -CacheKey 'M365AdminCopilotOverview:CreditUsage' -Force:$Force
                    AgentUsage = Get-M365AdminPortalData -Path '/admin/api/reports/GetReportData?entityname=getDeclarativeAgentConsumptionSummary&locale=en-US' -CacheKey 'M365AdminCopilotOverview:AgentUsage' -Force:$Force
                    PinPolicy = Get-M365AdminPortalData -Path '/admin/api/settings/company/copilotpolicy/pin' -CacheKey 'M365AdminCopilotOverview:UsagePinPolicy' -Force:$Force
                    LicenseAssignmentDate = Get-M365AdminPortalData -Path '/admin/api/Copilot/getcopilotlicenseassignmentdate' -CacheKey 'M365AdminCopilotOverview:UsageLicenseAssignmentDate' -Force:$Force
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotOverview.Usage'
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'About' {
                $result = [pscustomobject]@{
                    Discover = Get-M365AdminPortalData -Path '/admin/api/copilotsettings/copilot/discover' -CacheKey 'M365AdminCopilotOverview:Discover' -Force:$Force
                    OfferRecommendations = Get-M365AdminPortalData -Path '/admin/api/offerrec/copilotagentsoffers/CopilotDiscoverPage' -CacheKey 'M365AdminCopilotOverview:OfferRecommendations' -Force:$Force
                    MarketplaceSeatSize = Get-M365AdminPortalData -Path '/admin/api/tenant/marketplaceSeatSize' -CacheKey 'M365AdminCopilotOverview:MarketplaceSeatSize' -Force:$Force
                    SubscribedSkus = Get-M365AdminPortalData -Path '/fd/MSGraph/v1.0/subscribedSkus' -CacheKey 'M365AdminCopilotOverview:AboutSubscribedSkus' -Force:$Force
                    PinPolicy = Get-M365AdminPortalData -Path '/admin/api/settings/company/copilotpolicy/pin' -CacheKey 'M365AdminCopilotOverview:AboutPinPolicy' -Force:$Force
                    LicenseAssignmentDate = Get-M365AdminPortalData -Path '/admin/api/Copilot/getcopilotlicenseassignmentdate' -CacheKey 'M365AdminCopilotOverview:AboutLicenseAssignmentDate' -Force:$Force
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotOverview.About'
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
        }
    }
}