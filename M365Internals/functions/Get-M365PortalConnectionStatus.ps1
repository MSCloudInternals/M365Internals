function Get-M365PortalConnectionStatus {
    <#
    .SYNOPSIS
        Reports local Microsoft 365 portal connection availability.

    .DESCRIPTION
        Reports whether a connection exists in this PowerShell session and whether it
        retains a dedicated browser profile. This is local state, not a live authentication
        check or verification of an account or tenant.

    .EXAMPLE
        Get-M365PortalConnectionStatus

        Reports the local connection and browser-profile availability.

    .OUTPUTS
        PSCustomObject
        Local connection and retained browser-profile flags.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $present = $null -ne $script:m365PortalSession -and $null -ne $script:m365PortalConnection
    $profilePath = if ($present -and $script:m365PortalSession.PSObject.Properties['M365BrowserProfilePath']) {
        [string]$script:m365PortalSession.M365BrowserProfilePath
    }
    [pscustomobject]@{
        ConnectionPresent = $present
        RetainedBrowserProfile = $present -and
            $null -ne $script:m365PortalConnection.PSObject.Properties['RetainedBrowserProfile'] -and
            [bool]$script:m365PortalConnection.RetainedBrowserProfile -and
            -not [string]::IsNullOrWhiteSpace($profilePath) -and
            (Test-Path -LiteralPath $profilePath -PathType Container)
    }
}
