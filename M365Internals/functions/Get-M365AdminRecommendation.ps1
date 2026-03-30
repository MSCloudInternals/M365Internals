function Get-M365AdminRecommendation {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center recommendation data.

    .DESCRIPTION
        Reads recommendation payloads exposed by the M365 admin center recommendation endpoints.

    .PARAMETER Name
        The recommendation payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw recommendation payload.

    .PARAMETER RawJson
        Returns the raw recommendation payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminRecommendation -Name M365Alerts

        Retrieves the M365 alerts recommendation payload.

    .OUTPUTS
        Object
        Returns the selected recommendation payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('M365', 'M365Alerts', 'M365Suggestions')]
        [string]$Name = 'M365',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $path = switch ($Name) {
            'M365' { '/admin/api/recommendations/m365' }
            'M365Alerts' { '/admin/api/recommendations/m365alerts?referrer=M365AdminDashboard' }
            'M365Suggestions' { '/admin/api/recommendations/m365suggestions?referrer=SearchAnswers' }
        }

        $headers = if ($Name -eq 'M365Suggestions') {
            Get-M365PortalContextHeaders -Context MicrosoftSearch
        }
        else {
            Get-M365PortalContextHeaders -Context Homepage
        }

        $result = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminRecommendation:$Name" -Headers $headers -Force:$Force
        $result = Add-M365TypeName -InputObject $result -TypeName ("M365Admin.Recommendation.{0}" -f $Name)
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}