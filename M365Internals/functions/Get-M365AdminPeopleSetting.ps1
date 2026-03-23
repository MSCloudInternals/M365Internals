function Get-M365AdminPeopleSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center People settings data.

    .DESCRIPTION
        Reads the People settings payloads used by the Org settings people experience,
        including profile card property configuration, name pronunciation, and pronouns.

    .PARAMETER Name
        The People settings payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminPeopleSetting -Name PersonInfoOnProfileCards

        Retrieves the People settings profile card configuration payloads.

    .OUTPUTS
        Object
        Returns the selected People settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('ConnectorProperties', 'NamePronunciation', 'PersonInfoOnProfileCards', 'ProfileCardProperties', 'Pronouns')]
        [string]$Name = 'PersonInfoOnProfileCards',

        [Parameter()]
        [switch]$Force
    )

    process {
        $tenantId = Get-M365PortalTenantId

        function Get-PeopleSettingResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [string]$Path
            )

            $result = Get-M365AdminPortalData -Path $Path -CacheKey "M365AdminPeopleSetting:$ResultName" -Force:$Force
            if ($null -ne $result) {
                return $result
            }

            [pscustomobject]@{
                Name        = $ResultName
                DataBacked  = $false
                Description = 'The People settings endpoint returned no data for this setting in the current tenant.'
            }
        }

        switch ($Name) {
            'PersonInfoOnProfileCards' {
                $profileCardProperties = Get-PeopleSettingResult -ResultName 'ProfileCardProperties' -Path ("/fd/peopleadminservice/{0}/profilecard/properties" -f $tenantId)
                $connectorProperties = Get-PeopleSettingResult -ResultName 'ConnectorProperties' -Path ("/fd/peopleadminservice/{0}/connectorProperties" -f $tenantId)

                [pscustomobject]@{
                    ProfileCardProperties = $profileCardProperties
                    ConnectorProperties   = $connectorProperties
                }
                return
            }
            'ProfileCardProperties' {
                $path = "/fd/peopleadminservice/{0}/profilecard/properties" -f $tenantId
            }
            'ConnectorProperties' {
                $path = "/fd/peopleadminservice/{0}/connectorProperties" -f $tenantId
            }
            'NamePronunciation' {
                $path = "/fd/peopleadminservice/{0}/settings/namePronunciation" -f $tenantId
            }
            'Pronouns' {
                $path = "/fd/peopleadminservice/{0}/settings/pronouns" -f $tenantId
            }
        }

        Get-PeopleSettingResult -ResultName $Name -Path $path
    }
}