function Get-M365AdminAppSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center app settings.

    .DESCRIPTION
        Reads settings payloads under the admin center apps settings surface discovered in the
        settings HAR capture.

    .PARAMETER Name
        The app settings payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminAppSetting -Name Bookings

        Retrieves the Bookings admin settings payload.

    .OUTPUTS
        Object
        Returns the selected app settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Bookings', 'Calendar', 'CalendarSharing', 'DirectorySynchronization', 'Dynamics365ConnectionGraph', 'Dynamics365CustomerVoice', 'Dynamics365SalesInsights', 'DynamicsCrm', 'EndUserCommunications', 'Learning', 'LoopPolicy', 'Mail', 'Microsoft365OnTheWeb', 'MicrosoftCommunicationToUsers', 'MicrosoftForms', 'MicrosoftGraphDataConnect', 'MicrosoftLoop', 'MicrosoftTeams', 'O365DataPlan', 'OfficeForms', 'OfficeFormsPro', 'OfficeOnline', 'OfficeScripts', 'Project', 'SharePoint', 'SitesSharing', 'SkypeTeams', 'Store', 'Sway', 'UserOwnedAppsAndServices', 'UserSoftware', 'VivaLearning', 'Whiteboard')]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    process {
        $bypassCache = $Force.IsPresent

        function Get-AppSettingResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [string]$Path
            )

            try {
                return Get-M365AdminPortalData -Path $Path -CacheKey "M365AdminAppSetting:$ResultName" -Force:$bypassCache
            }
            catch {
                $fallbackNames = @('Dynamics365ConnectionGraph', 'Dynamics365SalesInsights', 'OfficeScripts')
                $isKnownUnavailableSurface = $fallbackNames -contains $ResultName
                $isUnavailableStatus = $_.Exception.Message -match '400 \(Bad Request\)|404 \(Not Found\)'

                if ($isKnownUnavailableSurface -and $isUnavailableStatus) {
                    return New-M365AdminUnavailableResult -Name $ResultName -Description 'This app setting endpoint currently does not return a usable payload in the current tenant.' -Reason 'TenantSpecific' -ErrorMessage $_.Exception.Message
                }

                throw
            }
        }

        $path = Get-M365AdminAppSettingPath -Name $Name
        Get-AppSettingResult -ResultName $Name -Path $path
    }
}
