function Get-M365AdminAgentTool {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Agents tools data.

    .DESCRIPTION
        Reads the Agents > Tools payloads, currently covering the MCP server inventory.

    .PARAMETER Name
        The tools payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminAgentTool

        Retrieves the Agents tools payloads.

    .OUTPUTS
        Object
        Returns the selected Agents tools payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'McpServers')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force
    )

    process {
        switch ($Name) {
            'All' {
                $result = [pscustomobject]@{
                    McpServers = Get-M365AdminAgentTool -Name McpServers -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.AgentTool'
            }
            'McpServers' {
                return Get-M365AdminPortalData -Path '/admin/api/agentssettings/mcpservers' -CacheKey 'M365AdminAgentTool:McpServers' -Force:$Force
            }
        }
    }
}