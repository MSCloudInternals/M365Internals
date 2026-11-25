function Get-M365PortalConnectionGeneration {
    [CmdletBinding()]
    param()

    if (-not $script:m365PortalSession -or -not $script:m365PortalConnection -or
        -not $script:m365PortalConnection.PSObject.Properties['ConnectionGeneration']) {
        throw 'No Microsoft 365 admin portal connection is available. Run Connect-M365Portal first.'
    }

    return $script:m365PortalConnection.ConnectionGeneration
}

function Assert-M365PortalConnectionGeneration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [guid]$Generation
    )

    if (-not $script:m365PortalSession -or -not $script:m365PortalConnection -or
        -not $script:m365PortalConnection.PSObject.Properties['ConnectionGeneration'] -or
        $script:m365PortalConnection.ConnectionGeneration -ne $Generation) {
        throw 'The Microsoft 365 admin portal connection changed. Start a new invocation before updating settings.'
    }
}
