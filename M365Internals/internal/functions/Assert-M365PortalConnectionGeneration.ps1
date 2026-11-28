function Assert-M365PortalConnectionGeneration {
    <#
    .SYNOPSIS
        Checks that the active portal connection has not been replaced since preflight.
    #>
    [CmdletBinding()]
    param (
        [guid]$Generation
    )

    if ($Generation -ne ([guid]$script:m365PortalConnectionGeneration)) {
        throw 'The Microsoft 365 admin portal connection changed. Start a new invocation before updating settings.'
    }
}
