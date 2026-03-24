function Invoke-M365PortalPostLandingBootstrap {
    <#
    .SYNOPSIS
        Replays the browser's post-landing portal bootstrap navigation.

    .DESCRIPTION
        After admin.cloud.microsoft receives the ESTS form post at /landing, the browser
        continues with document requests that establish additional portal session state.
        This helper performs the same follow-up navigation so later bootstrap and admin
        API requests see the fuller cookie set expected by the portal.

    .PARAMETER WebSession
        The authenticated web session to continue bootstrapping.

    .PARAMETER UserAgent
        The user agent string used for the navigation requests.

    .EXAMPLE
        Invoke-M365PortalPostLandingBootstrap -WebSession $session -UserAgent $agent

        Completes the document navigation sequence after a successful /landing post.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.PowerShell.Commands.WebRequestSession])]
    param (
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [string]$UserAgent
    )

    function Get-PortalCookieValue {
        param (
            [Parameter(Mandatory)]
            [string]$Name
        )

        foreach ($cookieUri in @('https://admin.cloud.microsoft/', 'https://admin.cloud.microsoft/adminportal')) {
            $portalCookies = $WebSession.Cookies.GetCookies($cookieUri)
            $cookie = $portalCookies | Where-Object Name -eq $Name | Select-Object -First 1
            if ($cookie) {
                return $cookie.Value
            }
        }
    }

    function Copy-HeaderMap {
        param (
            [Parameter(Mandatory)]
            [hashtable]$Headers
        )

        $copiedHeaders = @{}
        foreach ($entry in @($Headers.GetEnumerator())) {
            $copiedHeaders[$entry.Key] = $entry.Value
        }

        return $copiedHeaders
    }

    if ($UserAgent) {
        $WebSession.UserAgent = $UserAgent
    }

    $documentHeaders = @{
        Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
    }

    foreach ($uri in @(
        'https://admin.cloud.microsoft/adminportal?ref=/homepage',
        'https://admin.cloud.microsoft/?ref=/homepage',
        'https://admin.cloud.microsoft/login?ru=%2Fadminportal%3Fref%3D%2Fhomepage'
    )) {
        try {
            $null = Invoke-WebRequest -MaximumRedirection 20 -ErrorAction Stop -WebSession $WebSession -Method Get -Uri $uri -Headers $documentHeaders -UserAgent $UserAgent
        }
        catch {
            throw "Failed to complete the admin portal post-landing bootstrap at '$uri'. $($_.Exception.Message)"
        }
    }

    $ajaxSessionKey = Get-PortalCookieValue -Name 's.AjaxSessionKey'
    if (-not [string]::IsNullOrWhiteSpace($ajaxSessionKey)) {
        try {
            $null = Invoke-WebRequest -MaximumRedirection 20 -ErrorAction Stop -WebSession $WebSession -Method Post -Uri 'https://admin.cloud.microsoft/api/instrument/logclient' -Headers @{
                Accept                 = '*/*'
                'Cache-Control'        = 'no-cache'
                Origin                 = 'https://admin.cloud.microsoft'
                Pragma                 = 'no-cache'
                Referer                = 'https://admin.cloud.microsoft/?ref=/homepage'
                'x-edge-shopping-flag' = '1'
                'x-ms-mac-hostingapp'  = 'M365AdminPortal'
            } -ContentType 'application/json' -Body '[{"TagId":"516290","LogLevel":"Info","Message":"Loading the initial bundle","Adhoc2":"{\"appName\":\"M365AdminPortal\",\"featureName\":\"\"}"}]' -UserAgent $UserAgent
        }
        catch {
            Write-Verbose "The optional logclient bootstrap request did not complete successfully: $($_.Exception.Message)"
        }

        try {
            $null = Invoke-WebRequest -MaximumRedirection 20 -ErrorAction Stop -WebSession $WebSession -Method Get -Uri 'https://admin.cloud.microsoft/adminportal/home/ClassicModernAdminDataStream?ref=/homepage' -Headers (Copy-HeaderMap -Headers (Get-M365PortalContextHeaders -Context Homepage -AjaxSessionKey $ajaxSessionKey)) -UserAgent $UserAgent
        }
        catch {
            Write-Verbose "The optional ClassicModernAdminDataStream bootstrap request did not complete successfully: $($_.Exception.Message)"
        }

        try {
            $null = Invoke-WebRequest -MaximumRedirection 20 -ErrorAction Stop -WebSession $WebSession -Method Get -Uri 'https://admin.cloud.microsoft/admin/api/tenant/datalocationandcommitments' -Headers (Copy-HeaderMap -Headers (Get-M365PortalContextHeaders -Context DataLocation -AjaxSessionKey $ajaxSessionKey)) -UserAgent $UserAgent
        }
        catch {
            Write-Verbose "The optional data-location bootstrap request did not complete successfully: $($_.Exception.Message)"
        }
    }

    $WebSession
}