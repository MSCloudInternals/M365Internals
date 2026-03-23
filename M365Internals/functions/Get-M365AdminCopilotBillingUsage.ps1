function Get-M365AdminCopilotBillingUsage {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Copilot Billing & usage data.

    .DESCRIPTION
        Reads the Copilot > Billing & usage payloads used by the billing policies,
        pay-as-you-go services, and high-usage users tabs.

    .PARAMETER Name
        The Billing & usage payload or tab to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminCopilotBillingUsage

        Retrieves the primary Copilot Billing & usage payload set.

    .OUTPUTS
        Object
        Returns the selected Copilot Billing & usage payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'AzureSubscriptions', 'BillingAccounts', 'BillingPolicies', 'BillingPolicyBudgets', 'BillingTabs', 'HighUsageUsers', 'PayAsYouGoServices')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        switch ($Name) {
            'All' {
                return [pscustomobject]@{
                    BillingTabs = [pscustomobject]@{
                        BillingPolicies = Get-M365AdminCopilotBillingUsage -Name BillingPolicies -Force:$Force
                        PayAsYouGoServices = Get-M365AdminCopilotBillingUsage -Name PayAsYouGoServices -Force:$Force
                        HighUsageUsers = Get-M365AdminCopilotBillingUsage -Name HighUsageUsers -Force:$Force
                    }
                    BillingAccounts = Get-M365AdminCopilotBillingUsage -Name BillingAccounts -Force:$Force
                    AzureSubscriptions = Get-M365AdminCopilotBillingUsage -Name AzureSubscriptions -Force:$Force
                }
            }
            'BillingTabs' {
                return [pscustomobject]@{
                    BillingPolicies = Get-M365AdminCopilotBillingUsage -Name BillingPolicies -Force:$Force
                    PayAsYouGoServices = Get-M365AdminCopilotBillingUsage -Name PayAsYouGoServices -Force:$Force
                    HighUsageUsers = Get-M365AdminCopilotBillingUsage -Name HighUsageUsers -Force:$Force
                }
            }
            'BillingPolicies' {
                return [pscustomobject]@{
                    Policies = Get-M365AdminPortalData -Path '/_api/v2.1/billingPolicies' -CacheKey 'M365AdminCopilotBillingUsage:BillingPolicies' -Force:$Force
                    PolicyBudgets = Get-M365AdminCopilotBillingUsage -Name BillingPolicyBudgets -Force:$Force
                    BillingAccounts = Get-M365AdminCopilotBillingUsage -Name BillingAccounts -Force:$Force
                    AzureSubscriptions = Get-M365AdminCopilotBillingUsage -Name AzureSubscriptions -Force:$Force
                }
            }
            'BillingPolicyBudgets' {
                return Get-M365AdminPortalData -Path '/_api/v2.1/billingPolicies?budgets=true' -CacheKey 'M365AdminCopilotBillingUsage:BillingPolicyBudgets' -Force:$Force
            }
            'BillingAccounts' {
                return [pscustomobject]@{
                    ShellBillingAccounts = Get-M365AdminPortalData -Path '/admin/api/tenant/billingAccountsWithShell' -CacheKey 'M365AdminCopilotBillingUsage:ShellBillingAccounts' -Force:$Force
                    ArmBillingAccounts = Get-M365AdminPortalData -Path '/fd/arm/providers/Microsoft.Billing/billingAccounts?api-version=2020-05-01' -CacheKey 'M365AdminCopilotBillingUsage:ArmBillingAccounts' -Force:$Force
                }
            }
            'AzureSubscriptions' {
                return Get-M365AdminPortalData -Path '/admin/api/tenant/azureSubscriptions' -CacheKey 'M365AdminCopilotBillingUsage:AzureSubscriptions' -Force:$Force
            }
            'PayAsYouGoServices' {
                return [pscustomobject]@{
                    Policies = Get-M365AdminPortalData -Path '/_api/v2.1/billingPolicies' -CacheKey 'M365AdminCopilotBillingUsage:PayAsYouGoPolicies' -Force:$Force
                    CopilotChatPolicy = Get-M365AdminPortalData -Path '/_api/v2.1/billingPolicies?feature=M365CopilotChat' -CacheKey 'M365AdminCopilotBillingUsage:PayAsYouGoCopilotChatPolicy' -Force:$Force
                }
            }
            'HighUsageUsers' {
                return [pscustomobject]@{
                    Policies = Get-M365AdminPortalData -Path '/_api/v2.1/billingPolicies' -CacheKey 'M365AdminCopilotBillingUsage:HighUsagePolicies' -Force:$Force
                    DataBacked = $false
                    Description = 'The High-usage users tab shows a prerequisite message until at least one Copilot billing policy is connected. No separate high-usage user feed was requested by the current tenant state.'
                }
            }
        }
    }
}