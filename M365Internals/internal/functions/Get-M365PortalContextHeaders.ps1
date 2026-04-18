function Resolve-M365PortalRequestContext {
    <#
    .SYNOPSIS
        Resolves a portal header context from an x-adminapp-request value.

    .PARAMETER AdminAppRequest
        The x-adminapp-request value observed for the originating page.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string]$AdminAppRequest = '/homepage'
    )

    if ([string]::IsNullOrWhiteSpace($AdminAppRequest)) {
        return 'Homepage'
    }

    switch -Regex ($AdminAppRequest) {
        '^/MicrosoftSearch($|/)' { return 'MicrosoftSearch' }
        '^/Settings/enhancedRestore($|/)' { return 'EnhancedRestore' }
        '^/Settings/OrganizationProfile/:/Settings/L1/DataLocation($|/)' { return 'DataLocation' }
        '^/brandcenter($|/)' { return 'BrandCenter' }
        '^/Settings/Services/:/Settings/L1/OfficeOnline($|/)' { return 'OfficeOnline' }
        '^/viva($|/)' { return 'Viva' }
        default { return 'Homepage' }
    }
}

function Get-M365PortalContextHeaders {
    <#
    .SYNOPSIS
        Builds request headers for common Microsoft 365 admin portal contexts.

    .DESCRIPTION
        Returns the HAR-aligned header sets used by homepage, search, backup, Brand center,
        Office Online, Viva, and tenant data-location requests. These headers can be merged
        with the current portal session headers or used directly when a caller already has an
        AjaxSessionKey value.

    .PARAMETER Context
        The portal context to build headers for.

    .PARAMETER AjaxSessionKey
        Includes the AjaxSessionKey header when provided.

    .EXAMPLE
        Get-M365PortalContextHeaders -Context Homepage

        Returns the homepage request headers.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'ContextHeaders is a fixed internal helper name used throughout the module')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Homepage', 'MicrosoftSearch', 'Viva', 'DataLocation', 'EnhancedRestore', 'BrandCenter', 'OfficeOnline')]
        [string]$Context,

        [string]$AjaxSessionKey
    )

    $headers = @{
        Accept                 = 'application/json;odata=minimalmetadata, text/plain, */*'
        'x-edge-shopping-flag' = '1'
    }

    $contextProfiles = @{
        Homepage = @{
            'Cache-Control'      = 'no-cache'
            Pragma               = 'no-cache'
            Referer              = 'https://admin.cloud.microsoft/?'
            'x-adminapp-request' = '/homepage'
            'x-ms-mac-appid'     = '050829af-7f24-4897-8f81-732bf47719ad'
            'x-ms-mac-hostingapp' = 'M365AdminPortal'
            'x-ms-mac-target-app' = 'MAC'
            'x-ms-mac-version'    = 'host-mac_2026.4.2.8'
        }
        MicrosoftSearch = @{
            'Cache-Control'      = 'no-cache'
            Pragma               = 'no-cache'
            Referer              = 'https://admin.cloud.microsoft/?'
            'x-adminapp-request' = '/MicrosoftSearch'
            'x-ms-mac-appid'     = '36051945-c7f8-4505-8a9b-23f8ba62271e'
            'x-ms-mac-hostingapp' = 'M365AdminPortal'
            'x-ms-mac-target-app' = 'MAC'
            'x-ms-mac-version'    = 'host-mac_2026.4.2.8'
        }
        EnhancedRestore = @{
            'Cache-Control'      = 'no-cache'
            Pragma               = 'no-cache'
            Referer              = 'https://admin.cloud.microsoft/?'
            'x-adminapp-request' = '/Settings/enhancedRestore'
            'x-ms-mac-appid'     = '08a68b73-8058-4c59-8bd5-7b6833e2af21'
            'x-ms-mac-hostingapp' = 'M365AdminPortal'
            'x-ms-mac-target-app' = 'MAC'
            'x-ms-mac-version'    = 'host-mac_2026.4.2.8'
        }
        BrandCenter = @{
            'Cache-Control'      = 'no-cache'
            Pragma               = 'no-cache'
            Referer              = 'https://admin.cloud.microsoft/'
            'x-adminapp-request' = '/brandcenter'
            'x-ms-mac-appid'     = '9f8918eb-b2b7-4b90-b5bd-86b38f6d4d23'
            'x-ms-mac-hostingapp' = 'M365AdminPortal'
            'x-ms-mac-target-app' = 'SPO'
            'x-ms-mac-version'    = 'host-mac_2026.4.2.8'
        }
        OfficeOnline = @{
            'Cache-Control'      = 'no-cache'
            Pragma               = 'no-cache'
            Referer              = 'https://admin.cloud.microsoft/?'
            'x-adminapp-request' = '/Settings/Services/:/Settings/L1/OfficeOnline'
            'x-ms-mac-appid'     = '3fda709f-4f6c-4ba7-8da3-b3d031a4d675'
            'x-ms-mac-hostingapp' = 'M365AdminPortal'
            'x-ms-mac-target-app' = 'MAC'
            'x-ms-mac-version'    = 'host-mac_2026.4.2.8'
        }
        Viva = @{
            'Cache-Control'      = 'no-cache'
            Pragma               = 'no-cache'
            Referer              = 'https://admin.cloud.microsoft/?'
            'x-adminapp-request' = '/viva'
            # Viva has not yet been recaptured with a distinct host profile, so keep the
            # current homepage host metadata until a blade-specific capture is available.
            'x-ms-mac-appid'     = '050829af-7f24-4897-8f81-732bf47719ad'
            'x-ms-mac-hostingapp' = 'M365AdminPortal'
            'x-ms-mac-target-app' = 'MAC'
            'x-ms-mac-version'    = 'host-mac_2026.4.2.8'
        }
        DataLocation = @{
            Referer              = 'https://admin.cloud.microsoft/'
            'x-adminapp-request' = '/Settings/OrganizationProfile/:/Settings/L1/DataLocation'
        }
    }

    foreach ($entry in @($contextProfiles[$Context].GetEnumerator())) {
        $headers[$entry.Key] = $entry.Value
    }

    if (-not [string]::IsNullOrWhiteSpace($AjaxSessionKey)) {
        $headers['AjaxSessionKey'] = $AjaxSessionKey
    }

    return $headers
}