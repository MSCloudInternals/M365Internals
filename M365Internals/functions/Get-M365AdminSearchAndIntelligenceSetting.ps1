function Get-M365AdminSearchAndIntelligenceSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Search & intelligence data.

    .DESCRIPTION
        Reads the Settings > Search & intelligence landing-page sections by composing the
        underlying search, reporting, and search-intelligence payloads used by the portal.

    .PARAMETER Name
        The Search & intelligence section to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the underlying leaf payload bundle for the selected page composition when it
        makes sense to do so.

    .EXAMPLE
        Get-M365AdminSearchAndIntelligenceSetting

        Retrieves the primary Search & intelligence landing-page sections.

    .EXAMPLE
        Get-M365AdminSearchAndIntelligenceSetting -Raw

        Retrieves the underlying search, reporting, and connectors leaf payload bundle instead
        of the default grouped landing-page sections.

    .OUTPUTS
        Object
        Returns the selected Search & intelligence payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'Answers', 'Configurations', 'Customizations', 'DataSources', 'Insights', 'Overview')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw
    )

    process {
        function Get-SearchSectionResult {
            param (
                [Parameter(Mandatory)]
                [string]$SectionName,

                [Parameter(Mandatory)]
                [scriptblock]$ScriptBlock
            )

            try {
                & $ScriptBlock
            }
            catch {
                New-M365AdminUnavailableResult -Name $SectionName -Description 'The Search & intelligence section did not return a usable payload.' -Reason 'TenantSpecific' -ErrorMessage $_.Exception.Message
            }
        }

        function Get-RawAllPayload {
            $result = [pscustomobject]@{
                SearchIntelligenceHomeCards = Get-M365AdminSearchSetting -Name SearchIntelligenceHomeCards -Force:$Force
                UsageAnalytics              = Get-M365AdminService -Name SearchAndIntelligenceUsageAnalytics -Force:$Force
                Reports                     = Get-M365AdminReportSetting -Name Reports -Force:$Force
                AdoptionScore               = Get-M365AdminReportSetting -Name AdoptionScore -Force:$Force
                ModernResultTypes           = Get-M365AdminSearchSetting -Name ModernResultTypes -Force:$Force
                News                        = Get-M365AdminSearchSetting -Name News -Force:$Force
                Pivots                      = Get-M365AdminSearchSetting -Name Pivots -Force:$Force
                Qnas                        = Get-M365AdminSearchSetting -Name Qnas -Force:$Force
                UdtConnectorsSummary        = Get-M365AdminSearchSetting -Name UdtConnectorsSummary -Force:$Force
                ConfigurationSettings       = Get-M365AdminSearchSetting -Name ConfigurationSettings -Force:$Force
                FirstRunExperience          = Get-M365AdminSearchSetting -Name FirstRunExperience -Force:$Force
                Configurations              = Get-M365AdminSearchSetting -Name Configurations -Force:$Force
            }

            return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.SearchAndIntelligenceSetting.Raw'
        }

        switch ($Name) {
            'All' {
                if ($Raw) {
                    return Get-RawAllPayload
                }

                $result = [pscustomobject]@{
                    Overview       = Get-SearchSectionResult -SectionName 'Overview' -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name Overview -Force:$Force }
                    Insights       = Get-SearchSectionResult -SectionName 'Insights' -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name Insights -Force:$Force }
                    Answers        = Get-SearchSectionResult -SectionName 'Answers' -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name Answers -Force:$Force }
                    DataSources    = Get-SearchSectionResult -SectionName 'DataSources' -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name DataSources -Force:$Force }
                    Customizations = Get-SearchSectionResult -SectionName 'Customizations' -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name Customizations -Force:$Force }
                    Configurations = Get-SearchSectionResult -SectionName 'Configurations' -ScriptBlock { Get-M365AdminSearchAndIntelligenceSetting -Name Configurations -Force:$Force }
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.SearchAndIntelligenceSetting'
            }
            'Overview' {
                $result = [pscustomobject]@{
                    SearchIntelligenceHomeCards = Get-M365AdminSearchSetting -Name SearchIntelligenceHomeCards -Force:$Force
                    UsageAnalytics              = Get-M365AdminService -Name SearchAndIntelligenceUsageAnalytics -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.SearchAndIntelligenceSetting.Overview'
            }
            'Insights' {
                $result = [pscustomobject]@{
                    UsageAnalytics = Get-M365AdminService -Name SearchAndIntelligenceUsageAnalytics -Force:$Force
                    Reports        = Get-M365AdminReportSetting -Name Reports -Force:$Force
                    AdoptionScore  = Get-M365AdminReportSetting -Name AdoptionScore -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.SearchAndIntelligenceSetting.Insights'
            }
            'Answers' {
                $result = [pscustomobject]@{
                    ModernResultTypes = Get-M365AdminSearchSetting -Name ModernResultTypes -Force:$Force
                    News              = Get-M365AdminSearchSetting -Name News -Force:$Force
                    Pivots            = Get-M365AdminSearchSetting -Name Pivots -Force:$Force
                    Qnas              = Get-M365AdminSearchSetting -Name Qnas -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.SearchAndIntelligenceSetting.Answers'
            }
            'DataSources' {
                $result = [pscustomobject]@{
                    UdtConnectorsSummary = Get-M365AdminSearchSetting -Name UdtConnectorsSummary -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.SearchAndIntelligenceSetting.DataSources'
            }
            'Customizations' {
                $result = [pscustomobject]@{
                    ConfigurationSettings = Get-M365AdminSearchSetting -Name ConfigurationSettings -Force:$Force
                    FirstRunExperience    = Get-M365AdminSearchSetting -Name FirstRunExperience -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.SearchAndIntelligenceSetting.Customizations'
            }
            'Configurations' {
                return Get-SearchSectionResult -SectionName 'Configurations' -ScriptBlock {
                    Get-M365AdminSearchSetting -Name Configurations -Force:$Force
                }
            }
        }
    }
}