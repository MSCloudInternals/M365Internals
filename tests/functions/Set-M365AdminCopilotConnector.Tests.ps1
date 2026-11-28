Describe 'Set-M365AdminCopilotConnector' {
    BeforeEach {
        $script:connectionsRawPayload = [pscustomobject]@{
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
                },
                [pscustomobject]@{
                    connectionId = 'HubSpotMCP01'
                    connectionName = 'HubSpot'
                    contentSourceDisplayName = 'HubSpot'
                }
            )
        }

        $script:gallerySettingsRawPayload = [pscustomobject]@{
            LogicalId = 'all'
            Payload   = '{"DisplayName":"","IncludeConnectorResults":true,"Entities":[{"EntityType":"File","ContentSources":[{"Id":"All","Name":"All"}]}]}'
        }

        $script:refreshedConnections = [pscustomobject]@{
            connections = @(
                [pscustomobject]@{
                    connectionId = 'LSEGMCP01'
                    connectionName = 'LSEG'
                    contentSourceDisplayName = 'LSEG'
                    EnabledForUsers = $false
                    VisibilityState = 'Off'
                },
                [pscustomobject]@{
                    connectionId = 'GContactsMCP01'
                    connectionName = 'GoogleContacts'
                    contentSourceDisplayName = 'Google Contacts'
                    EnabledForUsers = $true
                    VisibilityState = 'On'
                },
                [pscustomobject]@{
                    connectionId = 'HubSpotMCP01'
                    connectionName = 'HubSpot'
                    contentSourceDisplayName = 'HubSpot'
                    EnabledForUsers = $true
                    VisibilityState = 'On'
                }
            )
        }

        Mock -ModuleName M365Internals Get-M365AdminCopilotConnector {
            switch ($Name) {
                'Connections' {
                    if ($Raw) {
                        return $script:connectionsRawPayload
                    }

                    return $script:refreshedConnections
                }
                'GallerySettings' {
                    return $script:gallerySettingsRawPayload
                }
                default {
                    throw "Unexpected connector payload name: $Name"
                }
            }
        }

        Mock -ModuleName M365Internals Get-M365PortalTenantId { 'tenant-1234' }
        Mock -ModuleName M365Internals Clear-M365Cache { }
    }

    Context 'successful writes' {
        BeforeEach {
            Mock -ModuleName M365Internals Invoke-M365AdminRestMethod {
                [pscustomobject]@{ Success = $true }
            }
        }

        It 'posts the observed Search vertical settings payload when disabling a connector by id' {
            Set-M365AdminCopilotConnector -ConnectionId 'LSEGMCP01' -Enabled $false -Confirm:$false | Out-Null

            Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
                $Path -eq "/fd/ssms/api/v1.0/'MSS'/Collection('VT')/Settings" -and
                $Method -eq 'Post' -and
                $Body.LogicalId -eq 'ALL' -and
                $Body.Path -eq ':' -and
                $Body.Payload -is [string] -and
                @((($Body.Payload | ConvertFrom-Json -Depth 50).Entities | Where-Object { $_.EntityType -eq 'External' }).ExcludedContentSources | ForEach-Object { $_.Id }) -contains 'LSEGMCP01'
            }

            Assert-MockCalled Clear-M365Cache -ModuleName M365Internals -Exactly 1 -ParameterFilter {
                $TenantId -eq 'tenant-1234'
            }
        }

        It 'removes only the selected connector exclusion when enabling by display name' {
            $script:gallerySettingsRawPayload = [pscustomobject]@{
                LogicalId = 'all'
                Payload   = '{"DisplayName":"","IncludeConnectorResults":true,"Entities":[{"EntityType":"File","ContentSources":[{"Id":"All","Name":"All"}]},{"EntityType":"External","ContentSources":[],"ExcludedContentSources":[{"Id":"LSEGMCP01","Name":""},{"Id":"HubSpotMCP01","Name":""}]}]}'
            }

            Set-M365AdminCopilotConnector -ConnectionName 'Google Contacts' -Enabled $true -Confirm:$false | Out-Null

            Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 0

            Set-M365AdminCopilotConnector -ConnectionName 'LSEG' -Enabled $true -Confirm:$false | Out-Null

            Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
                $payload = $Body.Payload | ConvertFrom-Json -Depth 50
                $externalEntity = @($payload.Entities | Where-Object { $_.EntityType -eq 'External' }) | Select-Object -First 1
                @($externalEntity.ExcludedContentSources | ForEach-Object { $_.Id }) -join ',' -eq 'HubSpotMCP01'
            }
        }

        It 'removes the external entity when enabling the final excluded connector' {
            $script:gallerySettingsRawPayload = [pscustomobject]@{
                LogicalId = 'all'
                Payload   = '{"DisplayName":"","IncludeConnectorResults":true,"Entities":[{"EntityType":"File","ContentSources":[{"Id":"All","Name":"All"}]},{"EntityType":"External","ContentSources":[],"ExcludedContentSources":[{"Id":"LSEGMCP01","Name":""}]}]}'
            }

            Set-M365AdminCopilotConnector -ConnectionId 'LSEGMCP01' -Enabled $true -Confirm:$false | Out-Null

            Assert-MockCalled Invoke-M365AdminRestMethod -ModuleName M365Internals -Exactly 1 -ParameterFilter {
                @((($Body.Payload | ConvertFrom-Json -Depth 50).Entities | Where-Object { $_.EntityType -eq 'External' })).Count -eq 0
            }
        }

        It 'returns the refreshed connector record when PassThru is used' {
            $result = Set-M365AdminCopilotConnector -ConnectionId 'LSEGMCP01' -Enabled $false -PassThru -Confirm:$false

            $result.connectionId | Should -Be 'LSEGMCP01'
            $result.EnabledForUsers | Should -BeFalse
        }
    }

    It 'stops before cache invalidation and readback after a redirected connector write' {
        InModuleScope M365Internals {
            $script:m365PortalSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            $script:m365PortalHeaders = @{}
        }
        Mock -ModuleName M365Internals Update-M365PortalConnectionSettings {}
        Mock -ModuleName M365Internals Invoke-RestMethod {
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Found)
            $response.Headers.Location = [uri]'/admin/api/next'
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Redirect refused', $response)
        }

        try {
            {
                Set-M365AdminCopilotConnector -ConnectionId 'LSEGMCP01' -Enabled $false -PassThru -Confirm:$false -ErrorAction SilentlyContinue
            } | Should -Throw '*write outcome is unconfirmed*HTTP 302*'
            Should -Invoke Invoke-RestMethod -ModuleName M365Internals -Times 1 -Exactly
            Should -Invoke Clear-M365Cache -ModuleName M365Internals -Times 0 -Exactly
            Should -Invoke Get-M365AdminCopilotConnector -ModuleName M365Internals -Times 0 -Exactly -ParameterFilter { $Name -eq 'Connections' -and -not $Raw }
        }
        finally {
            InModuleScope M365Internals {
                $script:m365PortalSession = $null
                $script:m365PortalHeaders = $null
            }
        }
    }
}
