function Resolve-M365AdminOutput {
    <#
    .SYNOPSIS
        Selects the default, raw, or raw JSON view for an admin result.

    .DESCRIPTION
        Returns the caller's default shaped result, the underlying raw payload, or a JSON
        rendering of the raw payload. This keeps public cmdlet output contracts consistent while
        still allowing callers and internal setters to request the unmodified admin-center data.

    .PARAMETER DefaultValue
        The default shaped value to return when neither -Raw nor -RawJson is requested.

    .PARAMETER RawValue
        The underlying raw payload to return when -Raw or -RawJson is requested. When omitted,
        the DefaultValue is treated as the raw payload.

    .PARAMETER Raw
        Returns the raw payload.

    .PARAMETER RawJson
        Returns the raw payload serialized as formatted JSON.

    .PARAMETER JsonDepth
        The ConvertTo-Json depth to use when -RawJson is requested.

    .EXAMPLE
        Resolve-M365AdminOutput -DefaultValue $summary -RawValue $payload -Raw

        Returns the raw payload instead of the summary object.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [AllowNull()]
        $DefaultValue,

        [Parameter()]
        [AllowNull()]
        $RawValue,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$JsonDepth = 30
    )

    process {
        $resolvedRawValue = if ($PSBoundParameters.ContainsKey('RawValue')) {
            $RawValue
        }
        else {
            $DefaultValue
        }

        if ($RawJson) {
            if ($null -eq $resolvedRawValue) {
                return $null
            }

            return $resolvedRawValue | ConvertTo-Json -Depth $JsonDepth
        }

        if ($Raw) {
            return $resolvedRawValue
        }

        return $DefaultValue
    }
}