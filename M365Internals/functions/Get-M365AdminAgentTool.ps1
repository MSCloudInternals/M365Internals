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

    .PARAMETER Raw
        Returns the raw Agents tools payload for the selected view.

    .PARAMETER RawJson
        Returns the raw Agents tools payload serialized as formatted JSON.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        switch ($Name) {
            'All' {
                $rawResult = [pscustomobject]@{
                    McpServers = Get-M365AdminAgentTool -Name McpServers -Force:$Force
                }

                if ($Raw -or $RawJson) {
                    $rawResult = Add-M365TypeName -InputObject $rawResult -TypeName 'M365Admin.AgentTool.Raw'
                    return Resolve-M365AdminOutput -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
                }

                $result = [pscustomobject]@{
                    McpServers = $rawResult.McpServers
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.AgentTool'
            }
            'McpServers' {
                $result = Get-M365AdminPortalData -Path '/admin/api/agentssettings/mcpservers' -CacheKey 'M365AdminAgentTool:McpServers' -Force:$Force
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
        }
    }
}