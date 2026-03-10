function Get-M365AdminService {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center service configuration data.

    .DESCRIPTION
        Reads service and app configuration payloads from the admin center services apps surface.

    .PARAMETER Name
        The service payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminService -Name ModernAuth

        Retrieves the Modern Auth service configuration payload.

    .OUTPUTS
        Object
        Returns the selected service payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('AzureSpeechServices', 'Cortana', 'DeveloperPortal', 'M365Lighthouse', 'ModernAuth', 'Planner', 'SearchIntelligenceAnalytics', 'Todo', 'VivaInsights')]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    process {
        $path = switch ($Name) {
            'AzureSpeechServices' { '/admin/api/services/apps/azurespeechservices' }
            'Cortana' { '/admin/api/services/apps/cortana' }
            'DeveloperPortal' { '/admin/api/services/apps/developerportal' }
            'M365Lighthouse' { '/admin/api/services/apps/m365lighthouse' }
            'ModernAuth' { '/admin/api/services/apps/modernAuth' }
            'Planner' { '/admin/api/services/apps/planner' }
            'SearchIntelligenceAnalytics' { '/admin/api/services/apps/searchintelligenceanalytics' }
            'Todo' { '/admin/api/services/apps/todo' }
            'VivaInsights' { '/admin/api/services/apps/vivainsights' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminService:$Name" -Force:$Force
    }
}