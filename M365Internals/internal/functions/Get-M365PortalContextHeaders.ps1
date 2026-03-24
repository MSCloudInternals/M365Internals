function Get-M365PortalContextHeaders {
    <#
    .SYNOPSIS
        Builds request headers for common Microsoft 365 admin portal contexts.

    .DESCRIPTION
        Returns the HAR-aligned header sets used by homepage, recommendation, Viva, and
        tenant data-location requests. These headers can be merged with the current portal
        session headers or used directly when a caller already has an AjaxSessionKey value.

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
        [ValidateSet('Homepage', 'MicrosoftSearch', 'Viva', 'DataLocation')]
        [string]$Context,

        [string]$AjaxSessionKey
    )

    $headers = @{
        Accept                 = 'application/json;odata=minimalmetadata, text/plain, */*'
        'x-edge-shopping-flag' = '1'
    }

    switch ($Context) {
        'Homepage' {
            $headers['Cache-Control'] = 'no-cache'
            $headers['Pragma'] = 'no-cache'
            $headers['Referer'] = 'https://admin.cloud.microsoft/?'
            $headers['x-adminapp-request'] = '/homepage'
            $headers['x-ms-mac-appid'] = 'f00c5fa5-eee4-4f57-88fa-c082d83b3c94'
            $headers['x-ms-mac-hostingapp'] = 'M365AdminPortal'
            $headers['x-ms-mac-target-app'] = 'MAC'
            $headers['x-ms-mac-version'] = 'host-mac_2026.3.2.6'
        }
        'MicrosoftSearch' {
            $headers['Cache-Control'] = 'no-cache'
            $headers['Pragma'] = 'no-cache'
            $headers['Referer'] = 'https://admin.cloud.microsoft/?'
            $headers['x-adminapp-request'] = '/MicrosoftSearch'
            $headers['x-ms-mac-appid'] = 'f00c5fa5-eee4-4f57-88fa-c082d83b3c94'
            $headers['x-ms-mac-hostingapp'] = 'M365AdminPortal'
            $headers['x-ms-mac-target-app'] = 'MAC'
            $headers['x-ms-mac-version'] = 'host-mac_2026.3.2.6'
        }
        'Viva' {
            $headers['Cache-Control'] = 'no-cache'
            $headers['Pragma'] = 'no-cache'
            $headers['Referer'] = 'https://admin.cloud.microsoft/'
            $headers['x-adminapp-request'] = '/viva'
            $headers['x-ms-mac-appid'] = 'f00c5fa5-eee4-4f57-88fa-c082d83b3c94'
            $headers['x-ms-mac-hostingapp'] = 'M365AdminPortal'
            $headers['x-ms-mac-target-app'] = 'MAC'
            $headers['x-ms-mac-version'] = 'host-mac_2026.3.2.6'
        }
        'DataLocation' {
            $headers['Referer'] = 'https://admin.cloud.microsoft/'
            $headers['x-adminapp-request'] = '/Settings/OrganizationProfile/:/Settings/L1/DataLocation'
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($AjaxSessionKey)) {
        $headers['AjaxSessionKey'] = $AjaxSessionKey
    }

    return $headers
}