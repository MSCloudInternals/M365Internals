function Get-M365AdminFeature {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center feature metadata.

    .DESCRIPTION
        Reads feature configuration data from the Microsoft 365 admin center. This cmdlet uses the
        active portal session and the current script-scoped admin headers.

    .PARAMETER InitialLoad
        Retrieves the initial feature payload used during portal startup.

    .PARAMETER Config
        Retrieves the feature configuration payload.

    .PARAMETER All
        Retrieves the full feature set exposed by the admin center.

    .PARAMETER AdminContentCdnImagePath
        Retrieves the configured admin content CDN image path.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw feature payload for the selected parameter set.

    .PARAMETER RawJson
        Returns the raw feature payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminFeature -All

        Retrieves the full admin center feature payload.

    .EXAMPLE
        Get-M365AdminFeature -Config -Force

        Retrieves the feature configuration payload without using cache.

    .OUTPUTS
        Object
        Returns the selected feature payload.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Feature is used as a logical configuration area name')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Switches define parameter sets and endpoint selection is driven by PSParameterSetName')]
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(ParameterSetName = 'InitialLoad')]
        [switch]$InitialLoad,

        [Parameter(ParameterSetName = 'Config')]
        [switch]$Config,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All,

        [Parameter(ParameterSetName = 'AdminContentCdnImagePath')]
        [switch]$AdminContentCdnImagePath,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $cacheKey = 'M365AdminFeature:{0}' -f $PSCmdlet.ParameterSetName
        $path = switch ($PSCmdlet.ParameterSetName) {
            'InitialLoad' { '/admin/api/features/initialload' }
            'Config' { '/admin/api/features/config' }
            'AdminContentCdnImagePath' { '/admin/api/features/admincontentcdnimagepath' }
            default { '/admin/api/features/all' }
        }

        $rawResult = Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Force:$Force
        $result = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName ("M365Admin.Feature.{0}" -f $PSCmdlet.ParameterSetName) -Category 'Feature metadata' -ItemName $PSCmdlet.ParameterSetName -Endpoint $path
        return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
    }
}