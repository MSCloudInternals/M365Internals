Describe 'Get-M365AdminCopilotConnector' {
    BeforeEach {
        $script:connectionsPath = '/fd/mssearchconnectors/v1.0/admin/connections/v2?filterActive=false&useCachedRead=true&includeFederatedConnections=true'
        $script:gallerySettingsPath = "/fd/ssms/api/v1.0/'MSS'/Collection('VT')/Settings(Path='',LogicalId='all')"
        $script:connectionsPayload = [pscustomobject]@{
            connections = @(
                [pscustomobject]@{
                    connectionId = 'LSEGMCP01'
                    connectionName = 'LSEG'
                    contentSourceDisplayName = 'LSEG'
                },
                [pscustomobject]@{
                    connectionId = 'GContactsMCP01'
                    connectionName = 'GoogleContacts'
                    contentSourceDisplayName = 'Google Contacts'
                }
            )
        }

        $script:gallerySettingsPayload = [pscustomobject]@{
            LogicalId = 'all'
            Payload   = '{"DisplayName":"","IncludeConnectorResults":true,"Entities":[{"EntityType":"File","ContentSources":[{"Id":"All","Name":"All"}]},{"EntityType":"External","ContentSources":[],"ExcludedContentSources":[{"Id":"LSEGMCP01","Name":""}]}]}'
        }

        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            switch ($Path) {
                $script:connectionsPath {
                    return $script:connectionsPayload
                }
                $script:gallerySettingsPath {
                    return $script:gallerySettingsPayload
                }
                default {
                    throw "Unexpected path: $Path"
                }
            }
        }
    }

    It 'adds EnabledForUsers and VisibilityState based on gallery setting exclusions' {
        $result = Get-M365AdminCopilotConnector -Name Connections

        $result.connections[0].connectionId | Should -Be 'LSEGMCP01'
        $result.connections[0].EnabledForUsers | Should -BeFalse
        $result.connections[0].VisibilityState | Should -Be 'Off'
        $result.connections[1].connectionId | Should -Be 'GContactsMCP01'
        $result.connections[1].EnabledForUsers | Should -BeTrue
        $result.connections[1].VisibilityState | Should -Be 'On'
    }

    It 'defaults connectors to enabled when the gallery settings payload has no external exclusions' {
        $script:gallerySettingsPayload = [pscustomobject]@{
            LogicalId = 'all'
            Payload   = '{"DisplayName":"","IncludeConnectorResults":true,"Entities":[{"EntityType":"File","ContentSources":[{"Id":"All","Name":"All"}]}]}'
        }

        $result = Get-M365AdminCopilotConnector -Name Connections

        $result.connections[0].EnabledForUsers | Should -BeTrue
        $result.connections[1].EnabledForUsers | Should -BeTrue
    }

    It 'returns an unknown visibility state when gallery settings cannot be read' {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            switch ($Path) {
                $script:connectionsPath {
                    return $script:connectionsPayload
                }
                $script:gallerySettingsPath {
                    throw 'Response status code does not indicate success: 503 (Service Unavailable).'
                }
                default {
                    throw "Unexpected path: $Path"
                }
            }
        }

        $result = Get-M365AdminCopilotConnector -Name Connections

        $result.connections[0].EnabledForUsers | Should -Be $null
        $result.connections[0].VisibilityState | Should -Be 'Unknown'
    }

    It 'returns the raw connections payload unchanged when Raw is requested' {
        $result = Get-M365AdminCopilotConnector -Name Connections -Raw

        $result.connections[0].PSObject.Properties.Name | Should -Not -Contain 'EnabledForUsers'
        Assert-MockCalled Get-M365AdminPortalData -ModuleName M365Internals -Exactly 1 -ParameterFilter {
            $Path -eq $script:connectionsPath
        }
        Assert-MockCalled Get-M365AdminPortalData -ModuleName M365Internals -Exactly 0 -ParameterFilter {
            $Path -eq $script:gallerySettingsPath
        }
    }
}


