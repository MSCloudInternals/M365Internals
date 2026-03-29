function Resolve-M365EstsUrl {
    <#
    .SYNOPSIS
        Resolves a relative ESTS URL into an absolute login.microsoftonline.com URL.

    .DESCRIPTION
        Accepts either an already-absolute ESTS URL or a relative ESTS path and returns
        the absolute login.microsoftonline.com URL expected by the authentication helpers.

    .PARAMETER Url
        The ESTS URL or relative path to resolve.

    .EXAMPLE
        Resolve-M365EstsUrl -Url '/common/GetCredentialType?mkt=en-US'

        Returns the absolute login.microsoftonline.com URL for the supplied relative path.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

    if ($Url -match '^https?://') {
        return $Url
    }

    return "https://login.microsoftonline.com$Url"
}
