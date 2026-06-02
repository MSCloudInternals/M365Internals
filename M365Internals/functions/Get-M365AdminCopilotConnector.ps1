function Get-M365AdminCopilotConnector {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Copilot Connectors data.

    .DESCRIPTION
        Reads the Copilot > Connectors gallery and your-connections payloads used by the
        Search connectors-backed Copilot connector experience. Connection inventory results
        are enriched with the current user visibility state when the Search vertical settings
        payload is available.

    .PARAMETER Name
        The connectors payload or view to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the underlying leaf payload bundle for the selected page composition when it
        makes sense to do so.

    .PARAMETER RawJson
        Returns the raw connectors payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminCopilotConnector

        Retrieves the primary Copilot Connectors payload set.

    .EXAMPLE
        Get-M365AdminCopilotConnector -Raw

        Retrieves the underlying connectors summary, statistics, connections, and gallery leaf
        payload bundle instead of the default grouped page view.

    .EXAMPLE
        Get-M365AdminCopilotConnector -Name Connections

        Retrieves the current connector inventory and includes the computed EnabledForUsers
        state for each connector when the gallery settings payload is available.

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
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        function Get-ConnectorRawPayload {
            $result = [pscustomobject]@{
                Summary         = Get-M365AdminCopilotConnector -Name Summary -Force:$Force -Raw
                Statistics      = Get-M365AdminCopilotConnector -Name Statistics -Force:$Force -Raw
                Connections     = Get-M365AdminCopilotConnector -Name Connections -Force:$Force -Raw
                AdminUxOptions  = Get-M365AdminCopilotConnector -Name AdminUxOptions -Force:$Force -Raw
                GallerySettings = Get-M365AdminCopilotConnector -Name GallerySettings -Force:$Force -Raw
            }

            return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotConnector.Raw'
        }

        function Get-ConnectorGallerySettingsState {
            $excludedConnectionIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

            try {
                $gallerySettings = Get-M365AdminCopilotConnector -Name GallerySettings -Force:$Force -Raw
            }
            catch {
                return [pscustomobject]@{
                    IsKnown               = $false
                    ExcludedConnectionIds = $excludedConnectionIds
                }
            }

            $payloadText = [string]$gallerySettings.Payload
            if ([string]::IsNullOrWhiteSpace($payloadText)) {
                return [pscustomobject]@{
                    IsKnown               = $true
                    ExcludedConnectionIds = $excludedConnectionIds
                }
            }

            $payload = $payloadText | ConvertFrom-Json -Depth 50
            foreach ($entity in @($payload.Entities | Where-Object { $_.EntityType -eq 'External' })) {
                foreach ($excludedSource in @($entity.ExcludedContentSources)) {
                    $excludedId = [string]$excludedSource.Id
                    if (-not [string]::IsNullOrWhiteSpace($excludedId)) {
                        $null = $excludedConnectionIds.Add($excludedId)
                    }
                }
            }

            return [pscustomobject]@{
                IsKnown               = $true
                ExcludedConnectionIds = $excludedConnectionIds
            }
        }

        function Resolve-ConnectionsResult {
            param(
                [Parameter(Mandatory)]
                $ConnectionsPayload
            )

            $result = $ConnectionsPayload | ConvertTo-Json -Depth 50 | ConvertFrom-Json -Depth 50
            $gallerySettingsState = Get-ConnectorGallerySettingsState

            foreach ($connection in @($result.connections)) {
                $enabledForUsers = if ($gallerySettingsState.IsKnown) {
                    -not $gallerySettingsState.ExcludedConnectionIds.Contains([string]$connection.connectionId)
                }
                else {
                    $null
                }

                $visibilityState = if ($null -eq $enabledForUsers) {
                    'Unknown'
                }
                elseif ($enabledForUsers) {
                    'On'
                }
                else {
                    'Off'
                }

                $connection | Add-Member -NotePropertyName EnabledForUsers -NotePropertyValue $enabledForUsers -Force
                $connection | Add-Member -NotePropertyName VisibilityState -NotePropertyValue $visibilityState -Force
            }

            return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotConnector.Connections'
        }

        switch ($Name) {
            'All' {
                if ($Raw -or $RawJson) {
                    return Resolve-M365AdminOutput -RawValue (Get-ConnectorRawPayload) -Raw:$Raw -RawJson:$RawJson
                }

                $result = [pscustomobject]@{
                    YourConnections = Get-M365AdminCopilotConnector -Name YourConnections -Force:$Force
                    Gallery = Get-M365AdminCopilotConnector -Name Gallery -Force:$Force
                }

                return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotConnector'
            }
            'Summary' {
                $result = Get-M365AdminPortalData -Path '/admin/api/searchadminapi/UDTConnectorsSummary' -CacheKey 'M365AdminCopilotConnector:Summary' -Force:$Force
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'Statistics' {
                $result = Get-M365AdminPortalData -Path '/fd/mssearchconnectors/v1.0/admin/connections/getStatistics' -CacheKey 'M365AdminCopilotConnector:Statistics' -Force:$Force
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'Connections' {
                $result = Get-M365AdminPortalData -Path '/fd/mssearchconnectors/v1.0/admin/connections/v2?filterActive=false&useCachedRead=true&includeFederatedConnections=true' -CacheKey 'M365AdminCopilotConnector:Connections' -Force:$Force
                $defaultValue = if ($Raw -or $RawJson) {
                    $result
                }
                else {
                    Resolve-ConnectionsResult -ConnectionsPayload $result
                }

                return Resolve-M365AdminOutput -DefaultValue $defaultValue -RawValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'AdminUxOptions' {
                $result = Get-M365AdminPortalData -Path '/fd/mssearchconnectors/v1.0/admin/AdminUxOptionsV2/Connectors?query=Connectors' -CacheKey 'M365AdminCopilotConnector:AdminUxOptions' -Force:$Force
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'GallerySettings' {
                $result = Get-M365AdminPortalData -Path "/fd/ssms/api/v1.0/'MSS'/Collection('VT')/Settings(Path='',LogicalId='all')" -CacheKey 'M365AdminCopilotConnector:GallerySettings' -Force:$Force
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'YourConnections' {
                $result = [pscustomobject]@{
                    Summary = Get-M365AdminCopilotConnector -Name Summary -Force:$Force
                    Statistics = Get-M365AdminCopilotConnector -Name Statistics -Force:$Force
                    Connections = Get-M365AdminCopilotConnector -Name Connections -Force:$Force
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotConnector.YourConnections'
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'Gallery' {
                $result = [pscustomobject]@{
                    Summary = Get-M365AdminCopilotConnector -Name Summary -Force:$Force
                    Statistics = Get-M365AdminCopilotConnector -Name Statistics -Force:$Force
                    AdminUxOptions = Get-M365AdminCopilotConnector -Name AdminUxOptions -Force:$Force
                    GallerySettings = Get-M365AdminCopilotConnector -Name GallerySettings -Force:$Force
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.CopilotConnector.Gallery'
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
        }
    }
}

