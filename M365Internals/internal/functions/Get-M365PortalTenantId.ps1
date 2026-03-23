function Get-M365PortalTenantId {
    <#
    .SYNOPSIS
        Resolves the active Microsoft 365 admin portal tenant ID.

    .DESCRIPTION
        Ensures the current portal connection settings are refreshed and returns the tenant ID
        associated with the active admin.cloud.microsoft session.

    .EXAMPLE
        Get-M365PortalTenantId

        Returns the tenant ID for the current portal connection.

    .OUTPUTS
        String
        Returns the resolved tenant ID.
    #>
    [CmdletBinding()]
    param ()

    process {
        Update-M365PortalConnectionSettings

        if (-not $script:m365PortalConnection -or [string]::IsNullOrWhiteSpace($script:m365PortalConnection.TenantId)) {
            throw 'No active Microsoft 365 admin portal tenant ID is available. Connect with Connect-M365Portal first.'
        }

        $script:m365PortalConnection.TenantId
    }
}