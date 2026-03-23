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
        [switch]$Force
    )

    process {
        switch ($Name) {
            'All' {
                [pscustomobject]@{
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
                    Telemetry                     = [pscustomobject]@{
                        DataBacked  = $false
                        Description = 'The telemetry endpoint currently requires an undiscovered API version and does not respond successfully to the direct read pattern used elsewhere in the module.'
                    }
                }
                return
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
                return [pscustomobject]@{
                    DataBacked  = $false
                    Description = 'The telemetry endpoint currently requires an undiscovered API version and does not respond successfully to the direct read pattern used elsewhere in the module.'
                }
            }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminPayAsYouGoService:$Name" -Force:$Force
    }
}