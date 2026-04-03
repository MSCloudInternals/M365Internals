function Test-M365PortalUnexpectedHtmlShell {
    <#
    .SYNOPSIS
        Detects unexpected admin portal HTML shell responses.

    .DESCRIPTION
        Distinguishes between expected bootstrap HTML payloads and the generic admin portal shell
        that indicates the request should be retried after rebuilding session state.

    .PARAMETER Content
        The response content to inspect.

    .EXAMPLE
        Test-M365PortalUnexpectedHtmlShell -Content $response.Content

        Returns True when the response content looks like the generic portal shell instead of bootstrap data.

    .OUTPUTS
        Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$Content
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $false
    }

    $trimmedContent = $Content.TrimStart()
    if (-not $trimmedContent.StartsWith('<')) {
        return $false
    }

    if ($Content -match 'O365\.TID=' -or
        $Content -match '\$Config\s*=\s*\{' -or
        $Content -match '"TID"\s*:\s*"?[0-9a-fA-F-]{36}') {
        return $false
    }

    return $true
}
