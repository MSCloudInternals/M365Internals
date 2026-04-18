function Get-M365AdminBrandCenterSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Brand center data.

    .DESCRIPTION
        Reads the Brand center configuration payloads used by the Org settings Brand center
        experience.

    .PARAMETER Name
        The Brand center payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw Brand center payload bundle for the selected view.

    .PARAMETER RawJson
        Returns the raw Brand center payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminBrandCenterSetting

        Retrieves the Brand center configuration and site URL information.

    .OUTPUTS
        Object
        Returns the selected Brand center payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'Configuration', 'SiteUrl')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $forceRequested = $Force

        function Get-BrandCenterHeader {
            $headers = Get-M365PortalContextHeaders -Context BrandCenter

            try {
                $sharePointToken = Get-M365AdminAccessToken -TokenType SharePoint -AdminAppRequest '/brandcenter'
                if ($sharePointToken -and -not [string]::IsNullOrWhiteSpace([string]$sharePointToken.Token)) {
                    $headers['Authorization'] = 'Bearer {0}' -f $sharePointToken.Token
                }
            }
            catch {
                Write-Verbose "Unable to acquire a SharePoint bearer token for Brand center. Falling back to cookie-only headers. $($_.Exception.Message)"
            }

            return $headers
        }

        $brandCenterHeaders = Get-BrandCenterHeader

        function Get-BrandCenterView {
            param (
                [Parameter(Mandatory)]
                [ValidateSet('Configuration', 'SiteUrl')]
                [string]$ViewName
            )

            $path = switch ($ViewName) {
                'Configuration' { '/_api/spo.tenant/GetBrandCenterConfiguration' }
                'SiteUrl' { "/_api/GroupSiteManager/GetValidSiteUrlFromAlias?alias='BrandGuide'&managedPath='sites'" }
            }

            $rawResult = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminBrandCenterSetting:$ViewName" -Headers $brandCenterHeaders -Force:$forceRequested
            $defaultResult = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName ("M365Admin.BrandCenterSetting.{0}" -f $ViewName) -Category 'Brand center settings' -ItemName $ViewName -Endpoint $path

            return [pscustomobject]@{
                Name = $ViewName
                Path = $path
                Raw = $rawResult
                Default = $defaultResult
            }
        }

        switch ($Name) {
            'All' {
                $rawResults = [ordered]@{}
                $defaultResults = [ordered]@{}

                foreach ($viewName in @('Configuration', 'SiteUrl')) {
                    $view = Get-BrandCenterView -ViewName $viewName
                    $rawResults[$viewName] = $view.Raw
                    $defaultResults[$viewName] = $view.Default
                }

                $result = New-M365AdminResultBundle -TypeName 'M365Admin.BrandCenterSetting' -Category 'Brand center settings' -Items $defaultResults -RawData ([pscustomobject]$rawResults)
                return Resolve-M365AdminOutput -DefaultValue $result -RawValue ([pscustomobject]$rawResults) -Raw:$Raw -RawJson:$RawJson
            }
        }

        $view = Get-BrandCenterView -ViewName $Name
        return Resolve-M365AdminOutput -DefaultValue $view.Default -RawValue $view.Raw -Raw:$Raw -RawJson:$RawJson
    }
}