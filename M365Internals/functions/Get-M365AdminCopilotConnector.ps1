function Get-M365AdminCopilotConnector {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Copilot Connectors data.

    .DESCRIPTION
        Reads the Copilot > Connectors gallery and your-connections payloads used by the
        Search connectors-backed Copilot connector experience.

    .PARAMETER Name
        The connectors payload or view to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminCopilotConnector

        Retrieves the primary Copilot Connectors payload set.

    .OUTPUTS
        Object
        Returns the selected Copilot Connectors payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('AdminUxOptions', 'All', 'Connections', 'Gallery', 'GallerySettings', 'Statistics', 'Summary', 'YourConnections')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        switch ($Name) {
            'All' {
                return [pscustomobject]@{
                    Summary = Get-M365AdminCopilotConnector -Name Summary -Force:$Force
                    Statistics = Get-M365AdminCopilotConnector -Name Statistics -Force:$Force
                    YourConnections = Get-M365AdminCopilotConnector -Name YourConnections -Force:$Force
                    Gallery = Get-M365AdminCopilotConnector -Name Gallery -Force:$Force
                }
            }
            'Summary' {
                return Get-M365AdminPortalData -Path '/admin/api/searchadminapi/UDTConnectorsSummary' -CacheKey 'M365AdminCopilotConnector:Summary' -Force:$Force
            }
            'Statistics' {
                return Get-M365AdminPortalData -Path '/fd/mssearchconnectors/v1.0/admin/connections/getStatistics' -CacheKey 'M365AdminCopilotConnector:Statistics' -Force:$Force
            }
            'Connections' {
                return Get-M365AdminPortalData -Path '/fd/mssearchconnectors/v1.0/admin/connections/v2?filterActive=false&useCachedRead=true&includeFederatedConnections=true' -CacheKey 'M365AdminCopilotConnector:Connections' -Force:$Force
            }
            'AdminUxOptions' {
                return Get-M365AdminPortalData -Path '/fd/mssearchconnectors/v1.0/admin/AdminUxOptionsV2/Connectors?query=Connectors' -CacheKey 'M365AdminCopilotConnector:AdminUxOptions' -Force:$Force
            }
            'GallerySettings' {
                return Get-M365AdminPortalData -Path "/fd/ssms/api/v1.0/'MSS'/Collection('VT')/Settings(Path='',LogicalId='all')" -CacheKey 'M365AdminCopilotConnector:GallerySettings' -Force:$Force
            }
            'YourConnections' {
                return [pscustomobject]@{
                    Summary = Get-M365AdminCopilotConnector -Name Summary -Force:$Force
                    Statistics = Get-M365AdminCopilotConnector -Name Statistics -Force:$Force
                    Connections = Get-M365AdminCopilotConnector -Name Connections -Force:$Force
                }
            }
            'Gallery' {
                return [pscustomobject]@{
                    Summary = Get-M365AdminCopilotConnector -Name Summary -Force:$Force
                    Statistics = Get-M365AdminCopilotConnector -Name Statistics -Force:$Force
                    AdminUxOptions = Get-M365AdminCopilotConnector -Name AdminUxOptions -Force:$Force
                    GallerySettings = Get-M365AdminCopilotConnector -Name GallerySettings -Force:$Force
                }
            }
        }
    }
}