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

    .PARAMETER Raw
        Returns the underlying leaf payload bundle for the selected page composition when it
        makes sense to do so.

    .EXAMPLE
        Get-M365AdminCopilotBillingUsage

        Retrieves the primary Copilot Billing & usage payload set.

    .EXAMPLE
        Get-M365AdminCopilotBillingUsage -Raw

        Retrieves the underlying Billing & usage leaf payload bundle instead of the default
        grouped page view.

    .OUTPUTS
        Object
        Returns the selected Copilot Billing & usage payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'AzureSubscriptions', 'BillingAccounts', 'BillingPolicies', 'BillingPolicyBudgets', 'HighUsageUsers', 'PayAsYouGoServices')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw
    )

    process {
        function Get-BillingUsageRawPayload {
            $result = [pscustomobject]@{
                BillingPolicies     = Get-M365AdminCopilotBillingUsage -Name BillingPolicies -Force:$Force
                BillingPolicyBudgets = Get-M365AdminCopilotBillingUsage -Name BillingPolicyBudgets -Force:$Force
                PayAsYouGoServices  = Get-M365AdminCopilotBillingUsage -Name PayAsYouGoServices -Force:$Force
                HighUsageUsers      = Get-M365AdminCopilotBillingUsage -Name HighUsageUsers -Force:$Force
                BillingAccounts     = Get-M365AdminCopilotBillingUsage -Name BillingAccounts -Force:$Force
                AzureSubscriptions  = Get-M365AdminCopilotBillingUsage -Name AzureSubscriptions -Force:$Force
            }

            return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotBillingUsage.Raw'
        }

        switch ($Name) {
            'All' {
                if ($Raw) {
                    return Get-BillingUsageRawPayload
                }

                $result = [pscustomobject]@{
                    BillingPolicies = Get-M365AdminCopilotBillingUsage -Name BillingPolicies -Force:$Force
                    PayAsYouGoServices = Get-M365AdminCopilotBillingUsage -Name PayAsYouGoServices -Force:$Force
                    HighUsageUsers = Get-M365AdminCopilotBillingUsage -Name HighUsageUsers -Force:$Force
                    BillingAccounts = Get-M365AdminCopilotBillingUsage -Name BillingAccounts -Force:$Force
                    AzureSubscriptions = Get-M365AdminCopilotBillingUsage -Name AzureSubscriptions -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotBillingUsage'
            }
            'BillingPolicies' {
                $result = [pscustomobject]@{
                    Policies = Get-M365AdminPortalData -Path '/_api/v2.1/billingPolicies' -CacheKey 'M365AdminCopilotBillingUsage:BillingPolicies' -Force:$Force
                    PolicyBudgets = Get-M365AdminCopilotBillingUsage -Name BillingPolicyBudgets -Force:$Force
                    BillingAccounts = Get-M365AdminCopilotBillingUsage -Name BillingAccounts -Force:$Force
                    AzureSubscriptions = Get-M365AdminCopilotBillingUsage -Name AzureSubscriptions -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotBillingUsage.BillingPolicies'
            }
            'BillingPolicyBudgets' {
                return Get-M365AdminPortalData -Path '/_api/v2.1/billingPolicies?budgets=true' -CacheKey 'M365AdminCopilotBillingUsage:BillingPolicyBudgets' -Force:$Force
            }
            'BillingAccounts' {
                $result = [pscustomobject]@{
                    ShellBillingAccounts = Get-M365AdminPortalData -Path '/admin/api/tenant/billingAccountsWithShell' -CacheKey 'M365AdminCopilotBillingUsage:ShellBillingAccounts' -Force:$Force
                    ArmBillingAccounts = Get-M365AdminPortalData -Path '/fd/arm/providers/Microsoft.Billing/billingAccounts?api-version=2020-05-01' -CacheKey 'M365AdminCopilotBillingUsage:ArmBillingAccounts' -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotBillingUsage.BillingAccounts'
            }
            'AzureSubscriptions' {
                return Get-M365AdminPortalData -Path '/admin/api/tenant/azureSubscriptions' -CacheKey 'M365AdminCopilotBillingUsage:AzureSubscriptions' -Force:$Force
            }
            'PayAsYouGoServices' {
                $result = [pscustomobject]@{
                    Policies = Get-M365AdminPortalData -Path '/_api/v2.1/billingPolicies' -CacheKey 'M365AdminCopilotBillingUsage:PayAsYouGoPolicies' -Force:$Force
                    CopilotChatPolicy = Get-M365AdminPortalData -Path '/_api/v2.1/billingPolicies?feature=M365CopilotChat' -CacheKey 'M365AdminCopilotBillingUsage:PayAsYouGoCopilotChatPolicy' -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotBillingUsage.PayAsYouGoServices'
            }
            'HighUsageUsers' {
                $result = [pscustomobject]@{
                    Policies = Get-M365AdminPortalData -Path '/_api/v2.1/billingPolicies' -CacheKey 'M365AdminCopilotBillingUsage:HighUsagePolicies' -Force:$Force
                    DataBacked = $false
                    Description = 'The High-usage users tab shows a prerequisite message until at least one Copilot billing policy is connected. No separate high-usage user feed was requested by the current tenant state.'
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotBillingUsage.HighUsageUsers'
            }
        }
    }
}