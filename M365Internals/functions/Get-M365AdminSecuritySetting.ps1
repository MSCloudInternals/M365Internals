function Get-M365AdminSecuritySetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center security settings.

    .DESCRIPTION
        Reads security-related settings payloads across the admin center security surfaces.

    .PARAMETER Name
        The security settings payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .EXAMPLE
        Get-M365AdminSecuritySetting -Name MultiFactorAuth

        Retrieves the multi-factor authentication settings payload.

    .OUTPUTS
        Object
        Returns the selected security settings payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('ActivityBasedTimeout', 'BingDataCollection', 'DataAccess', 'GuestUserPolicy', 'MultiFactorAuth', 'O365GuestUser', 'PasswordPolicy', 'PrivacyPolicy', 'SecurityDefaults', 'SecuritySettings', 'SecuritySettingsStatus', 'SecuritySettingsOptIn', 'TenantLockbox')]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    process {
        $path = switch ($Name) {
            'ActivityBasedTimeout' { '/admin/api/settings/security/activitybasedtimeout' }
            'BingDataCollection' { '/admin/api/settings/security/bingdatacollection' }
            'DataAccess' { '/admin/api/settings/security/dataaccess' }
            'GuestUserPolicy' { '/admin/api/Settings/security/guestUserPolicy' }
            'MultiFactorAuth' { '/admin/api/settings/security/multifactorauth' }
            'O365GuestUser' { '/admin/api/settings/security/o365guestuser' }
            'PasswordPolicy' { '/admin/api/Settings/security/passwordpolicy' }
            'PrivacyPolicy' { '/admin/api/Settings/security/privacypolicy' }
            'SecurityDefaults' { '/admin/api/identitysecurity/securitydefaults' }
            'SecuritySettings' { '/admin/api/securitysettings/settings' }
            'SecuritySettingsStatus' { '/admin/api/securitysettings/settings/status' }
            'SecuritySettingsOptIn' { '/admin/api/securitysettings/optIn' }
            'TenantLockbox' { '/admin/api/Settings/security/tenantLockbox' }
        }

        Get-M365AdminPortalData -Path $path -CacheKey "M365AdminSecuritySetting:$Name" -Force:$Force
    }
}