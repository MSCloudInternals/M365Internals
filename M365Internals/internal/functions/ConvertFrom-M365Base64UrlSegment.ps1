function ConvertFrom-M365Base64UrlSegment {
    <#
    .SYNOPSIS
        Decodes a Base64Url-encoded text segment.

    .DESCRIPTION
        Normalizes URL-safe Base64 characters and padding before decoding the value as UTF-8 text.
        This is used when reading JWT payload segments returned by Entra and the Microsoft 365 admin portal.

    .PARAMETER Value
        The Base64Url-encoded segment to decode.

    .EXAMPLE
        ConvertFrom-M365Base64UrlSegment -Value 'eyJzdWIiOiIxMjMifQ'

        Decodes the supplied JWT segment into its UTF-8 JSON text.

    .OUTPUTS
        String
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $normalizedValue = $Value.Replace('-', '+').Replace('_', '/')
    switch ($normalizedValue.Length % 4) {
        2 { $normalizedValue += '==' }
        3 { $normalizedValue += '=' }
    }

    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($normalizedValue))
}
