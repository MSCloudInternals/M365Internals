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

    .PARAMETER Raw
        Returns the underlying admin-center payload without applying any additional shaping.

    .PARAMETER RawJson
        Returns the raw app settings payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminAppSetting -Name Bookings

        Retrieves the Bookings admin settings payload.

    .OUTPUTS
        Object
        Returns the selected app settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'Bookings', 'Calendar', 'CalendarSharing', 'DirectorySynchronization', 'Dynamics365ConnectionGraph', 'Dynamics365CustomerVoice', 'Dynamics365SalesInsights', 'DynamicsCrm', 'EndUserCommunications', 'Learning', 'LoopPolicy', 'Mail', 'Microsoft365OnTheWeb', 'MicrosoftCommunicationToUsers', 'MicrosoftForms', 'MicrosoftGraphDataConnect', 'MicrosoftLoop', 'MicrosoftTeams', 'O365DataPlan', 'OfficeForms', 'OfficeFormsPro', 'OfficeOnline', 'OfficeScripts', 'Project', 'SharePoint', 'SitesSharing', 'SkypeTeams', 'Store', 'Sway', 'UserOwnedAppsAndServices', 'UserSoftware', 'VivaLearning', 'Whiteboard')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $bypassCache = $Force.IsPresent
        $allNames = @(
            'Bookings',
            'CalendarSharing',
            'DirectorySynchronization',
            'Dynamics365ConnectionGraph',
            'Dynamics365CustomerVoice',
            'Dynamics365SalesInsights',
            'DynamicsCrm',
            'EndUserCommunications',
            'Learning',
            'LoopPolicy',
            'Mail',
            'Microsoft365OnTheWeb',
            'MicrosoftForms',
            'MicrosoftGraphDataConnect',
            'MicrosoftTeams',
            'OfficeScripts',
            'Project',
            'SharePoint',
            'Sway',
            'UserOwnedAppsAndServices',
            'UserSoftware',
            'Whiteboard'
        )

        function Get-AppSettingResult {
            param (
                [Parameter(Mandatory)]
                [string]$ResultName,

                [Parameter(Mandatory)]
                [string]$Path,

                [Parameter()]
                [hashtable]$ResultHeaders
            )

            try {
                return Get-M365AdminPortalData -Path $Path -CacheKey "M365AdminAppSetting:$ResultName" -Headers $ResultHeaders -Force:$bypassCache
            }
            catch {
                $fallbackNames = @('Dynamics365ConnectionGraph', 'Dynamics365SalesInsights', 'OfficeScripts')
                $isKnownUnavailableSurface = $fallbackNames -contains $ResultName
                $isUnavailableStatus = $_.Exception.Message -match '400 \(Bad Request\)|404 \(Not Found\)'

                if ($isKnownUnavailableSurface -and $isUnavailableStatus) {
                    return New-M365AdminUnavailableResultFromError -Name $ResultName -Area 'app setting surface' -DefaultDescription 'This app setting endpoint currently does not return a usable payload in the current tenant.' -ErrorMessage $_.Exception.Message
                }

                throw
            }
        }

        function Get-AppSettingHeader {
            param (
                [Parameter(Mandatory)]
                [string]$RequestedName
            )

            switch ($RequestedName) {
                'Microsoft365OnTheWeb' { return Get-M365PortalContextHeaders -Context OfficeOnline }
                'OfficeOnline' { return Get-M365PortalContextHeaders -Context OfficeOnline }
                default { return $null }
            }
        }

        function Get-AppSettingView {
            param (
                [Parameter(Mandatory)]
                [string]$RequestedName
            )

            $path = Get-M365AdminAppSettingPath -Name $RequestedName
            $headers = Get-AppSettingHeader -RequestedName $RequestedName
            $rawResult = Get-AppSettingResult -ResultName $RequestedName -Path $path -ResultHeaders $headers
            $defaultResult = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName ("M365Admin.AppSetting.{0}" -f $RequestedName) -Category 'App settings' -ItemName $RequestedName -Endpoint $path

            return [pscustomobject]@{
                Name = $RequestedName
                Path = $path
                Raw = $rawResult
                Default = $defaultResult
            }
        }

        if ($Name -eq 'All') {
            $rawResults = [ordered]@{}
            $defaultResults = [ordered]@{}

            foreach ($itemName in $allNames) {
                $view = Get-AppSettingView -RequestedName $itemName
                $rawResults[$itemName] = $view.Raw
                $defaultResults[$itemName] = $view.Default
            }

            $result = New-M365AdminResultBundle -TypeName 'M365Admin.AppSetting' -Category 'App settings' -Items $defaultResults -RawData ([pscustomobject]$rawResults)
            return Resolve-M365AdminOutput -DefaultValue $result -RawValue ([pscustomobject]$rawResults) -Raw:$Raw -RawJson:$RawJson
        }

        $view = Get-AppSettingView -RequestedName $Name
        return Resolve-M365AdminOutput -DefaultValue $view.Default -RawValue $view.Raw -Raw:$Raw -RawJson:$RawJson
    }
}
