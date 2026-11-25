function Assert-M365AdminPortalUri {
    param (
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $parsedUri = $null
    if (-not [System.Uri]::TryCreate($Uri, [System.UriKind]::Absolute, [ref]$parsedUri) -or
        $parsedUri.Scheme -ne 'https' -or
        $parsedUri.DnsSafeHost -ne 'admin.cloud.microsoft' -or
        $parsedUri.Port -ne 443 -or
        -not [string]::IsNullOrEmpty($parsedUri.UserInfo)) {
        throw 'The request URI must use HTTPS and the admin.cloud.microsoft origin.'
    }
}
