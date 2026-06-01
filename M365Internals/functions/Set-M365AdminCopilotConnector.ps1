function Set-M365AdminCopilotConnector {
    <#
    .SYNOPSIS
        Updates the Copilot connector visibility state for users.

    .DESCRIPTION
        Retrieves the current Copilot connector inventory and Search vertical gallery settings,
        resolves the requested connector, then updates the gallery settings exclusion list used
        by the Copilot Connectors portal to enable or disable that source for users.

    .PARAMETER ConnectionId
        The connector identifier to update.

    .PARAMETER ConnectionName
        The connector name to update. This matches either the connector inventory name or the
        portal display name shown in the connectors experience.

    .PARAMETER Enabled
        Specifies whether the connector should be enabled for users.

    .PARAMETER Force
        Bypasses the cache when retrieving the current connector inventory and gallery settings.

    .PARAMETER PassThru
        Retrieves and returns the refreshed connector inventory record after the update succeeds.

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs without submitting the update.

    .PARAMETER Confirm
        Prompts for confirmation before submitting the update.

    .EXAMPLE
        Set-M365AdminCopilotConnector -ConnectionId 'LSEGMCP01' -Enabled $false -Confirm:$false

        Disables the LSEG connector for users.

    .EXAMPLE
        Set-M365AdminCopilotConnector -ConnectionName 'Google Contacts' -Enabled $true -PassThru -Confirm:$false

        Enables the Google Contacts connector for users and returns the refreshed inventory record.

    .OUTPUTS
        Object
        Returns the admin-center write response, or the refreshed connector inventory record when
        `-PassThru` is used.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionId,

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionName,

        [Parameter(Mandatory)]
        [bool]$Enabled,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        function Resolve-TargetConnector {
            param(
                [Parameter(Mandatory)]
                $ConnectionsPayload,

                [Parameter(Mandatory)]
                [string]$LookupValue,

                [Parameter(Mandatory)]
                [string]$LookupMode
            )

            $connections = @($ConnectionsPayload.connections)
            if ($LookupMode -eq 'ById') {
                $connectorMatches = @($connections | Where-Object { [string]$_.connectionId -ieq $LookupValue })
            }
            else {
                $connectorMatches = @(
                    $connections | Where-Object {
                        ([string]$_.connectionName -ieq $LookupValue) -or
                        ([string]$_.contentSourceDisplayName -ieq $LookupValue)
                    }
                )
            }

            if ($connectorMatches.Count -eq 0) {
                throw "Copilot connector '$LookupValue' was not found."
            }

            if ($connectorMatches.Count -gt 1) {
                $resolvedIds = @($connectorMatches | ForEach-Object { [string]$_.connectionId }) -join ', '
                throw "Copilot connector '$LookupValue' matched multiple connectors: $resolvedIds"
            }

            return $connectorMatches[0]
        }

        function Get-ParsedGallerySettingsRecord {
            $settingsRecord = Get-M365AdminCopilotConnector -Name GallerySettings -Force:$Force -Raw
            if ($null -eq $settingsRecord) {
                throw 'The Copilot connector gallery settings payload was empty.'
            }

            $payloadText = [string]$settingsRecord.Payload
            if ([string]::IsNullOrWhiteSpace($payloadText)) {
                throw 'The Copilot connector gallery settings payload did not include a Payload value.'
            }

            return [pscustomobject]@{
                SettingsRecord = $settingsRecord
                Payload        = $payloadText | ConvertFrom-Json -Depth 50
            }
        }

        function Test-ConnectorExternalEntityRemovable {
            param(
                [Parameter(Mandatory)]
                $ExternalEntity
            )

            foreach ($property in $ExternalEntity.PSObject.Properties) {
                switch ($property.Name) {
                    'EntityType' {
                        continue
                    }
                    'ExcludedContentSources' {
                        if (@($property.Value).Count -gt 0) {
                            return $false
                        }

                        continue
                    }
                    'ContentSources' {
                        if (@($property.Value).Count -gt 0) {
                            return $false
                        }

                        continue
                    }
                    default {
                        $value = $property.Value
                        if ($null -eq $value) {
                            continue
                        }

                        if ($value -is [string]) {
                            if ([string]::IsNullOrWhiteSpace($value)) {
                                continue
                            }

                            return $false
                        }

                        if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                            if (@($value).Count -eq 0) {
                                continue
                            }
                        }

                        return $false
                    }
                }
            }

            return $true
        }

        function Get-UpdatedConnectorGallerySettingsPayload {
            param(
                [Parameter(Mandatory)]
                $GalleryPayload,

                [Parameter(Mandatory)]
                [string]$TargetConnectionId,

                [Parameter(Mandatory)]
                [bool]$DesiredEnabledState
            )

            $updatedPayload = $GalleryPayload | ConvertTo-Json -Depth 50 | ConvertFrom-Json -Depth 50
            $entities = [System.Collections.ArrayList]::new()
            foreach ($entity in @($updatedPayload.Entities)) {
                [void]$entities.Add($entity)
            }

            $updatedPayload.Entities = $entities
            $externalEntity = @($entities | Where-Object { $_.EntityType -eq 'External' }) | Select-Object -First 1

            if ($null -eq $externalEntity -and -not $DesiredEnabledState) {
                $externalEntity = [pscustomobject]@{
                    EntityType             = 'External'
                    ContentSources         = @()
                    ExcludedContentSources = @()
                }

                [void]$entities.Add($externalEntity)
            }

            if ($null -eq $externalEntity) {
                return $updatedPayload
            }

            $excludedContentSources = [System.Collections.ArrayList]::new()
            $matchedExistingExclusion = $false
            foreach ($excludedSource in @($externalEntity.ExcludedContentSources)) {
                if ([string]$excludedSource.Id -ieq $TargetConnectionId) {
                    $matchedExistingExclusion = $true
                    if (-not $DesiredEnabledState) {
                        [void]$excludedContentSources.Add($excludedSource)
                    }

                    continue
                }

                [void]$excludedContentSources.Add($excludedSource)
            }

            if (-not $DesiredEnabledState -and -not $matchedExistingExclusion) {
                [void]$excludedContentSources.Add([pscustomobject]@{
                        Id   = $TargetConnectionId
                        Name = ''
                    })
            }

            $externalEntity.ExcludedContentSources = @($excludedContentSources)
            if ($DesiredEnabledState -and @($externalEntity.ExcludedContentSources).Count -eq 0 -and (Test-ConnectorExternalEntityRemovable -ExternalEntity $externalEntity)) {
                [void]$entities.Remove($externalEntity)
            }

            $updatedPayload.Entities = @($entities)
            return $updatedPayload
        }

        function Get-RefreshedConnectorRecord {
            param(
                [Parameter(Mandatory)]
                [string]$TargetConnectionId
            )

            $connectionsResult = Get-M365AdminCopilotConnector -Name Connections -Force
            return @($connectionsResult.connections | Where-Object { [string]$_.connectionId -ieq $TargetConnectionId }) | Select-Object -First 1
        }

        $connectionsPayload = Get-M365AdminCopilotConnector -Name Connections -Force:$Force -Raw
        $lookupValue = if ($PSCmdlet.ParameterSetName -eq 'ById') { $ConnectionId } else { $ConnectionName }
        $targetConnector = Resolve-TargetConnector -ConnectionsPayload $connectionsPayload -LookupValue $lookupValue -LookupMode $PSCmdlet.ParameterSetName
        $gallerySettings = Get-ParsedGallerySettingsRecord
        $updatedPayload = Get-UpdatedConnectorGallerySettingsPayload -GalleryPayload $gallerySettings.Payload -TargetConnectionId ([string]$targetConnector.connectionId) -DesiredEnabledState $Enabled

        $currentPayloadJson = $gallerySettings.Payload | ConvertTo-Json -Depth 50 -Compress
        $updatedPayloadJson = $updatedPayload | ConvertTo-Json -Depth 50 -Compress
        if ($currentPayloadJson -eq $updatedPayloadJson) {
            if ($PassThru) {
                return Get-RefreshedConnectorRecord -TargetConnectionId ([string]$targetConnector.connectionId)
            }

            return
        }

        $path = "/fd/ssms/api/v1.0/'MSS'/Collection('VT')/Settings"
        $writeBody = [ordered]@{
            LogicalId = 'ALL'
            Path      = ':'
            Payload   = $updatedPayloadJson
        }

        $action = if ($Enabled) { 'Enable' } else { 'Disable' }
        $targetLabel = '{0} ({1})' -f ([string]$targetConnector.connectionName), ([string]$targetConnector.connectionId)
        if ($PSCmdlet.ShouldProcess($targetLabel, "$action Copilot connector visibility")) {
            $result = Invoke-M365AdminRestMethod -Path $path -Method Post -Body $writeBody
            Clear-M365Cache -TenantId (Get-M365PortalTenantId)

            if ($PassThru) {
                return Get-RefreshedConnectorRecord -TargetConnectionId ([string]$targetConnector.connectionId)
            }

            return $result
        }
    }
}


