function Get-M365AdminPayAsYouGoService {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center pay-as-you-go service data.

    .DESCRIPTION
        Reads the primary payloads used by the Org settings Pay-as-you-go services page,
        including billing, backup, and Content Understanding related settings.

    .PARAMETER Name
        The pay-as-you-go payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw pay-as-you-go payload for the selected view.

    .PARAMETER RawJson
        Returns the raw pay-as-you-go payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminPayAsYouGoService

        Retrieves the primary pay-as-you-go service payload set.

    .OUTPUTS
        Object
        Returns the selected pay-as-you-go payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'AutoFill', 'AzureSubscriptions', 'BillingFeature', 'DataLocationAndCommitments', 'ESignature', 'EnhancedRestoreFeature', 'ImageTagging', 'Licensing', 'PlaybackTranscriptTranslation', 'PrimarySetting', 'TaxonomyTagging', 'Telemetry')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        function Get-TelemetryUnavailableResult {
            $result = New-M365AdminUnavailableResult -Name 'Telemetry' -Description 'The telemetry surface is known to use POST /admin/api/km/setting/telemetry in the live portal, but the request body and surrounding workflow have not been captured well enough to issue a safe direct read from the module yet.' -Reason 'UndiscoveredEndpoint' -SuggestedAction 'Inspect the live portal telemetry interaction with browser DevTools to capture the exact POST body and any required headers before adding direct module support.'
            Add-Member -InputObject $result -NotePropertyName RequestMethod -NotePropertyValue 'Post' -Force
            Add-Member -InputObject $result -NotePropertyName RequestPath -NotePropertyValue '/admin/api/km/setting/telemetry' -Force
            Add-Member -InputObject $result -NotePropertyName ObservedStatusCode -NotePropertyValue 204 -Force
            Add-Member -InputObject $result -NotePropertyName RequestBodyCaptured -NotePropertyValue $false -Force
            Add-Member -InputObject $result -NotePropertyName PortalSurface -NotePropertyValue 'Org settings / Pay-as-you-go services' -Force
            return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.PayAsYouGoService.Telemetry'
        }

        switch ($Name) {
            'All' {
                $result = [pscustomobject]@{
                    BillingFeature                = Get-M365AdminPortalData -Path "/_api/v2.1/billingFeatures('M365Backup')" -CacheKey 'M365AdminPayAsYouGoService:BillingFeature' -Force:$Force
                    AzureSubscriptions            = Get-M365AdminPortalData -Path '/admin/api/syntexbilling/azureSubscriptions' -CacheKey 'M365AdminPayAsYouGoService:AzureSubscriptions' -Force:$Force
                    EnhancedRestoreFeature        = Get-M365AdminPortalData -Path '/fd/enhancedRestorev2/v1/featureSetting' -CacheKey 'M365AdminPayAsYouGoService:EnhancedRestoreFeature' -Force:$Force
                    DataLocationAndCommitments    = Get-M365AdminPortalData -Path '/admin/api/tenant/datalocationandcommitments' -CacheKey 'M365AdminPayAsYouGoService:DataLocationAndCommitments' -Force:$Force
                    PrimarySetting                = Get-M365AdminPortalData -Path '/admin/api/contentunderstanding/setting' -CacheKey 'M365AdminPayAsYouGoService:PrimarySetting' -Force:$Force
                    AutoFill                      = Get-M365AdminPortalData -Path '/admin/api/contentunderstanding/autofillsetting' -CacheKey 'M365AdminPayAsYouGoService:AutoFill' -Force:$Force
                    Licensing                     = Get-M365AdminPortalData -Path '/admin/api/contentunderstanding/licensing' -CacheKey 'M365AdminPayAsYouGoService:Licensing' -Force:$Force
                    ImageTagging                  = Get-M365AdminPortalData -Path '/admin/api/contentunderstanding/imagetaggingsetting' -CacheKey 'M365AdminPayAsYouGoService:ImageTagging' -Force:$Force
                    ESignature                    = Get-M365AdminPortalData -Path '/admin/api/contentunderstanding/esignaturesettings' -CacheKey 'M365AdminPayAsYouGoService:ESignature' -Force:$Force
                    TaxonomyTagging               = Get-M365AdminPortalData -Path '/admin/api/contentunderstanding/taxonomytaggingsetting' -CacheKey 'M365AdminPayAsYouGoService:TaxonomyTagging' -Force:$Force
                    PlaybackTranscriptTranslation = Get-M365AdminPortalData -Path '/admin/api/contentunderstanding/playbacktranscripttranslationsettings' -CacheKey 'M365AdminPayAsYouGoService:PlaybackTranscriptTranslation' -Force:$Force
                    Telemetry                     = Get-TelemetryUnavailableResult
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.PayAsYouGoService'
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'BillingFeature' {
                $path = "/_api/v2.1/billingFeatures('M365Backup')"
            }
            'AzureSubscriptions' {
                $path = '/admin/api/syntexbilling/azureSubscriptions'
            }
            'EnhancedRestoreFeature' {
                $path = '/fd/enhancedRestorev2/v1/featureSetting'
            }
            'DataLocationAndCommitments' {
                $path = '/admin/api/tenant/datalocationandcommitments'
            }
            'PrimarySetting' {
                $path = '/admin/api/contentunderstanding/setting'
            }
            'AutoFill' {
                $path = '/admin/api/contentunderstanding/autofillsetting'
            }
            'Licensing' {
                $path = '/admin/api/contentunderstanding/licensing'
            }
            'ImageTagging' {
                $path = '/admin/api/contentunderstanding/imagetaggingsetting'
            }
            'ESignature' {
                $path = '/admin/api/contentunderstanding/esignaturesettings'
            }
            'TaxonomyTagging' {
                $path = '/admin/api/contentunderstanding/taxonomytaggingsetting'
            }
            'PlaybackTranscriptTranslation' {
                $path = '/admin/api/contentunderstanding/playbacktranscripttranslationsettings'
            }
            'Telemetry' {
                $result = Get-TelemetryUnavailableResult
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
        }

        $result = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminPayAsYouGoService:$Name" -Force:$Force
        $result = Add-M365TypeName -InputObject $result -TypeName ("M365Admin.PayAsYouGoService.{0}" -f $Name)
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}