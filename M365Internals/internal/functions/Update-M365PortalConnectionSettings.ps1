function Update-M365PortalConnectionSettings {
    <#
    .SYNOPSIS
        Refreshes the stored Microsoft 365 admin portal connection settings.

    .DESCRIPTION
        Re-reads the current admin.cloud.microsoft cookies from the active web session and updates
        the script-scoped portal headers. This keeps request headers such as AjaxSessionKey and
        x-portal-routekey aligned with the current session without re-running the validation probes.

    .EXAMPLE
        Update-M365PortalConnectionSettings

        Refreshes the current admin portal session headers from the stored web session.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'ConnectionSettings is singular by design')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Updates only the current PowerShell session state')]
    [CmdletBinding()]
    param ()

    if (-not $script:m365PortalSession) {
        throw 'No Microsoft 365 admin portal session is available. Run Connect-M365Portal first.'
    }

    $authSource = if ($script:m365PortalConnection -and $script:m365PortalConnection.Source) {
        $script:m365PortalConnection.Source
    }
    else {
        'WebSession'
    }

    $authFlow = if ($script:m365PortalConnection -and $script:m365PortalConnection.PSObject.Properties['AuthFlow']) {
        $script:m365PortalConnection.AuthFlow
    }
    else {
        $null
    }

    $null = Set-M365PortalConnectionSettings -WebSession $script:m365PortalSession -AuthSource $authSource -AuthFlow $authFlow -UserAgent $script:m365PortalSession.UserAgent -SkipValidation
}
