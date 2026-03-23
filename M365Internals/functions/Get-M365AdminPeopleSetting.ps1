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

        switch ($Name) {
            'PersonInfoOnProfileCards' {
                $profileCardProperties = Get-M365AdminPortalData -Path ("/fd/peopleadminservice/{0}/profilecard/properties" -f $tenantId) -CacheKey 'M365AdminPeopleSetting:ProfileCardProperties' -Force:$Force
                $connectorProperties = Get-M365AdminPortalData -Path ("/fd/peopleadminservice/{0}/connectorProperties" -f $tenantId) -CacheKey 'M365AdminPeopleSetting:ConnectorProperties' -Force:$Force

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

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminPeopleSetting:$Name" -Force:$Force
    }
}