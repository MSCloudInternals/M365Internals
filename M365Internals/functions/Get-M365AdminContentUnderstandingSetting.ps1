function Get-M365AdminContentUnderstandingSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center Content Understanding settings.

    .DESCRIPTION
        Reads Content Understanding settings payloads from the admin center endpoints captured in
        the settings HAR.

    .PARAMETER Name
        The Content Understanding settings payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw Content Understanding payload for the selected section.

    .PARAMETER RawJson
        Returns the raw Content Understanding payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminContentUnderstandingSetting -Name Setting

        Retrieves the primary Content Understanding settings payload.

    .OUTPUTS
        Object
        Returns the selected Content Understanding settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('AutoFill', 'BillingSettings', 'ESignature', 'ImageTagging', 'Licensing', 'PlaybackTranscriptTranslation', 'PowerAppsEnvironments', 'Setting', 'TaxonomyTagging')]
        [string]$Name,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $path = switch ($Name) {
            'AutoFill' { '/admin/api/contentunderstanding/autofillsetting' }
            'BillingSettings' { '/admin/api/contentunderstanding/billingSettings' }
            'ESignature' { '/admin/api/contentunderstanding/esignaturesettings' }
            'ImageTagging' { '/admin/api/contentunderstanding/imagetaggingsetting' }
            'Licensing' { '/admin/api/contentunderstanding/licensing' }
            'PlaybackTranscriptTranslation' { '/admin/api/contentunderstanding/playbacktranscripttranslationsettings' }
            'PowerAppsEnvironments' { '/admin/api/contentunderstanding/powerAppsEnvironments' }
            'Setting' { '/admin/api/contentunderstanding/setting' }
            'TaxonomyTagging' { '/admin/api/contentunderstanding/taxonomytaggingsetting' }
        }

        $rawResult = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminContentUnderstandingSetting:$Name" -Force:$Force
        $result = ConvertTo-M365AdminResult -InputObject $rawResult -TypeName ("M365Admin.ContentUnderstandingSetting.{0}" -f $Name) -Category 'Content understanding' -ItemName $Name -Endpoint $path
        return Resolve-M365AdminOutput -DefaultValue $result -RawValue $rawResult -Raw:$Raw -RawJson:$RawJson
    }
}