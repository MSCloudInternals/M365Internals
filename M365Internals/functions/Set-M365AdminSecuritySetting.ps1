function Set-M365AdminSecuritySetting {
    <#
    .SYNOPSIS
        Updates Microsoft 365 admin center security settings.

    .DESCRIPTION
        Retrieves the current security settings payload, merges the provided setting values into
        that payload, and submits the updated result back to the Microsoft 365 admin center.

    .PARAMETER Name
        The security settings payload to update.

    .PARAMETER Settings
        The setting values to merge into the current payload before submitting the update.

    .PARAMETER Force
        Bypasses the cache when retrieving the current payload before the update.

    .PARAMETER PassThru
        Retrieves and returns the updated payload after the write succeeds.

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs without submitting the update.

    .PARAMETER Confirm
        Prompts for confirmation before submitting the update.

    .EXAMPLE
        Set-M365AdminSecuritySetting -Name BingDataCollection -Settings @{ IsBingDataCollectionConsented = $false } -Confirm:$false

        Updates the Bing data collection security settings payload.

    .OUTPUTS
        Object
        Returns the admin-center write response, or the refreshed payload when `-PassThru` is used.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('BaselineSecurityMode', 'BingDataCollection', 'CustomerLockbox', 'DataAccess', 'GuestUserPolicy', 'NamePronunciation', 'O365GuestUser', 'PasswordExpirationPolicy', 'PasswordPolicy', 'PrivacyPolicy', 'PrivacyProfile', 'PrivilegedAccess', 'Pronouns', 'SecurityDefaults', 'Sharing', 'TenantLockbox')]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Settings,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        $tenantId = Get-M365PortalTenantId
        $path = switch ($Name) {
            'BaselineSecurityMode' { '/admin/api/identitysecurity/securitydefaults' }
            'BingDataCollection' { '/admin/api/settings/security/bingdatacollection' }
            'CustomerLockbox' { '/admin/api/Settings/security/tenantLockbox' }
            'DataAccess' { '/admin/api/settings/security/dataaccess' }
            'GuestUserPolicy' { '/admin/api/Settings/security/guestUserPolicy' }
            'NamePronunciation' { "/fd/peopleadminservice/{0}/settings/namePronunciation" -f $tenantId }
            'O365GuestUser' { '/admin/api/settings/security/o365guestuser' }
            'PasswordExpirationPolicy' { '/admin/api/Settings/security/passwordpolicy' }
            'PasswordPolicy' { '/admin/api/Settings/security/passwordpolicy' }
            'PrivacyPolicy' { '/admin/api/Settings/security/privacypolicy' }
            'PrivacyProfile' { '/admin/api/Settings/security/privacypolicy' }
            'PrivilegedAccess' { '/admin/api/Settings/security/tenantLockbox' }
            'Pronouns' { "/fd/peopleadminservice/{0}/settings/pronouns" -f $tenantId }
            'SecurityDefaults' { '/admin/api/identitysecurity/securitydefaults' }
            'Sharing' { '/admin/api/Settings/security/guestUserPolicy' }
            'TenantLockbox' { '/admin/api/Settings/security/tenantLockbox' }
        }

        $method = if ($Name -in @('BaselineSecurityMode', 'NamePronunciation', 'Pronouns', 'SecurityDefaults')) { 'Patch' } else { 'Post' }
        $currentSettings = Get-M365AdminSecuritySetting -Name $Name -Force:$Force -Raw
        $body = Merge-M365AdminSettingsPayload -CurrentSettings $currentSettings -Settings $Settings

        if ($PSCmdlet.ShouldProcess("Security setting '$Name'", "$method $path")) {
            $result = Invoke-M365AdminRestMethod -Path $path -Method $method -Body $body
            Clear-M365Cache -TenantId (Get-M365PortalTenantId)

            if ($PassThru) {
                return Get-M365AdminSecuritySetting -Name $Name -Force
            }

            return $result
        }
    }
}