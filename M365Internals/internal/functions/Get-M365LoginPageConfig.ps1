function Get-M365LoginPageConfig {
    <#
    .SYNOPSIS
        Parses the ESTS $Config JSON block from an Entra sign-in page.

    .DESCRIPTION
        Extracts the client-side `$Config` assignment embedded in an Entra sign-in HTML
        response and converts that JSON object into a PowerShell object for downstream
        authentication helpers.

    .PARAMETER Content
        The full HTML content returned by an Entra sign-in page.

    .EXAMPLE
        $config = Get-M365LoginPageConfig -Content $response.Content

        Parses the ESTS page configuration from an Entra sign-in response.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $assignmentMatch = [regex]::Match($Content, '\$Config\s*=\s*\{')
    if (-not $assignmentMatch.Success) {
        throw 'Failed to parse the ESTS page configuration block.'
    }

    $startIndex = $assignmentMatch.Index + $assignmentMatch.Length - 1
    $depth = 0
    $inString = $false
    $isEscaped = $false
    $endIndex = -1

    for ($index = $startIndex; $index -lt $Content.Length; $index++) {
        $character = $Content[$index]

        if ($isEscaped) {
            $isEscaped = $false
            continue
        }

        if ($character -eq '\') {
            if ($inString) {
                $isEscaped = $true
            }

            continue
        }

        if ($character -eq '"') {
            $inString = -not $inString
            continue
        }

        if ($inString) {
            continue
        }

        if ($character -eq '{') {
            $depth++
            continue
        }

        if ($character -eq '}') {
            $depth--
            if ($depth -eq 0) {
                $endIndex = $index
                break
            }
        }
    }

    if ($endIndex -lt $startIndex) {
        throw 'Failed to parse the ESTS page configuration block.'
    }

    return $Content.Substring($startIndex, ($endIndex - $startIndex) + 1) | ConvertFrom-Json -Depth 32
}
