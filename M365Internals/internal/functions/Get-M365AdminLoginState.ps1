function Get-M365AdminLoginState {
    <#
    .SYNOPSIS
        Starts the Microsoft 365 admin portal sign-in bootstrap and returns the Entra login state.

    .DESCRIPTION
        Requests the Microsoft 365 admin portal home page, extracts the Entra sign-in URL
        used by the portal, optionally applies a tenant override or login hint, and then
        returns both the raw sign-in response and the parsed ESTS page configuration.

        This helper keeps the M365-specific admin bootstrap centralized so the individual
        authentication flows do not need to hard-code their own authorize URLs.

    .PARAMETER WebSession
        The WebRequestSession that should be used for the admin bootstrap and follow-up
        Entra sign-in request.

    .PARAMETER Username
        Optional username to pass as a login hint to the Entra sign-in page.

    .PARAMETER TenantId
        Optional tenant ID used to replace the default tenant segment in the extracted
        Entra sign-in URL.

    .PARAMETER UserAgent
        User-Agent string used for the admin bootstrap and Entra sign-in requests.

    .EXAMPLE
        $state = Get-M365AdminLoginState -WebSession $session -Username 'admin@contoso.com'

        Starts the admin portal bootstrap and returns the resolved Entra login state.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [string]$Username,

        [string]$TenantId,

        [string]$UserAgent = (Get-M365DefaultUserAgent)
    )

    $bootstrapResponse = Invoke-WebRequest -Uri 'https://admin.cloud.microsoft/' -WebSession $WebSession -UserAgent $UserAgent
    $loginUrlMatch = [regex]::Match($bootstrapResponse.Content, "var loginURL = '(?<value>(?:\\.|[^'])+)'")
    if (-not $loginUrlMatch.Success) {
        throw 'Failed to determine the admin.cloud.microsoft sign-in URL.'
    }

    $loginUrl = [System.Text.RegularExpressions.Regex]::Unescape($loginUrlMatch.Groups['value'].Value)
    if ($TenantId) {
        $loginUrl = $loginUrl -replace 'https://login\.microsoftonline\.com/(?:common|organizations)/', "https://login.microsoftonline.com/$TenantId/"
    }

    if ($Username -and $loginUrl -notmatch '(?:\?|&)login_hint=') {
        $separator = if ($loginUrl -match '\?') { '&' } else { '?' }
        $loginUrl = $loginUrl + $separator + 'login_hint=' + [uri]::EscapeDataString($Username)
    }

    $loginResponse = Invoke-WebRequest -Uri $loginUrl -WebSession $WebSession -MaximumRedirection 5 -UserAgent $UserAgent

    return [pscustomobject]@{
        LoginUrl = $loginUrl
        Response = $loginResponse
        Config   = Get-M365LoginPageConfig -Content $loginResponse.Content
    }
}
