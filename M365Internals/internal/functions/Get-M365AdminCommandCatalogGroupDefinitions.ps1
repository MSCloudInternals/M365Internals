function Get-M365AdminCommandCatalogGroupDefinitions {
    <#
    .SYNOPSIS
        Returns the canonical functional command-catalog groups for M365Internals.

    .DESCRIPTION
        Provides the canonical functional group metadata used to organize the public M365Internals
        command catalog in runtime discovery and generated documentation.

    .EXAMPLE
        Get-M365AdminCommandCatalogGroupDefinitions

        Returns the ordered set of functional catalog groups and their descriptions.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Returns the complete set of command catalog group definitions.')]
    [CmdletBinding()]
    [OutputType([object[]])]
    param ()

    process {
        return @(
            [pscustomobject]@{
                Name = 'Authentication'
                Title = 'Authentication'
                Description = 'Connection and sign-in helpers for establishing or reusing admin-center sessions.'
                Order = 10
            }
            [pscustomobject]@{
                Name = 'AgentsAndCopilot'
                Title = 'Agents & Copilot'
                Description = 'Agent inventory, policy, tool, and Copilot management surfaces.'
                Order = 20
            }
            [pscustomobject]@{
                Name = 'OrgSettingsAndWorkloads'
                Title = 'Org Settings & Workloads'
                Description = 'Org settings, workload settings, and workload-specific configuration cmdlets.'
                Order = 30
            }
            [pscustomobject]@{
                Name = 'SearchReportsAndInsights'
                Title = 'Search, Reports & Insights'
                Description = 'Search, reporting, recommendations, and insights-focused read surfaces.'
                Order = 40
            }
            [pscustomobject]@{
                Name = 'TenantUsersAndRelationships'
                Title = 'Tenant, Users & Relationships'
                Description = 'Tenant, user, group, domain, partner, and relationship management surfaces.'
                Order = 50
            }
            [pscustomobject]@{
                Name = 'PlatformAndUtilities'
                Title = 'Platform & Utilities'
                Description = 'Navigation, shell, feature, bootstrap, and supporting platform metadata.'
                Order = 60
            }
            [pscustomobject]@{
                Name = 'WriteOperations'
                Title = 'Write Operations'
                Description = 'State-changing cmdlets that post, put, or patch admin-center settings.'
                Order = 70
            }
            [pscustomobject]@{
                Name = 'AdvancedAccess'
                Title = 'Advanced Access'
                Description = 'Low-level REST access helpers for authenticated admin-center requests.'
                Order = 80
            }
        )
    }
}