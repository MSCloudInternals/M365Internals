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

    .PARAMETER Raw
        Returns the raw security settings payload for the selected section.

    .PARAMETER RawJson
        Returns the raw security settings payload serialized as formatted JSON.

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
        [ValidateSet('ActivityBasedTimeout', 'BaselineSecurityMode', 'BingDataCollection', 'CustomerLockbox', 'DataAccess', 'GuestUserPolicy', 'HelpAndSupportQueryCollection', 'IdleSessionTimeout', 'MicrosoftGraphDataConnectApplications', 'MultiFactorAuth', 'NamePronunciation', 'O365GuestUser', 'PasswordExpirationPolicy', 'PasswordPolicy', 'PrivacyPolicy', 'PrivacyProfile', 'PrivilegedAccess', 'Pronouns', 'SecurityDefaults', 'SecuritySettings', 'SecuritySettingsOptIn', 'SecuritySettingsStatus', 'SelfServicePasswordReset', 'Sharing', 'TenantLockbox')]
        [string]$Name,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        function Add-SecuritySettingTypeName {
            param(
                [Parameter(Mandatory)]
                $InputObject,

                [Parameter(Mandatory)]
                [string]$SectionName
            )

            if ($InputObject -and ($InputObject.PSObject.TypeNames -notcontains 'M365Admin.UnavailableResult')) {
                $InputObject = Add-M365TypeName -InputObject $InputObject -TypeName ("M365Admin.SecuritySetting.{0}" -f $SectionName)
            }

            return $InputObject
        }

        if ($Name -in @('NamePronunciation', 'Pronouns')) {
            $tenantId = Get-M365PortalTenantId
            $path = if ($Name -eq 'NamePronunciation') {
                "/fd/peopleadminservice/{0}/settings/namePronunciation" -f $tenantId
            }
            else {
                "/fd/peopleadminservice/{0}/settings/pronouns" -f $tenantId
            }

            $result = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminSecuritySetting:$Name" -Force:$Force
            $result = Add-SecuritySettingTypeName -InputObject $result -SectionName $Name
            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
        }

        $path = switch ($Name) {
            'ActivityBasedTimeout' { '/admin/api/settings/security/activitybasedtimeout' }
            'BaselineSecurityMode' { '/admin/api/identitysecurity/securitydefaults' }
            'BingDataCollection' { '/admin/api/settings/security/bingdatacollection' }
            'CustomerLockbox' { '/admin/api/Settings/security/tenantLockbox' }
            'DataAccess' { '/admin/api/settings/security/dataaccess' }
            'GuestUserPolicy' { '/admin/api/Settings/security/guestUserPolicy' }
            'HelpAndSupportQueryCollection' { '/admin/api/settings/security/bingdatacollection' }
            'IdleSessionTimeout' { '/admin/api/settings/security/activitybasedtimeout' }
            'MicrosoftGraphDataConnectApplications' { '/admin/api/settings/apps/o365dataplan' }
            'MultiFactorAuth' { '/admin/api/settings/security/multifactorauth' }
            'O365GuestUser' { '/admin/api/settings/security/o365guestuser' }
            'PasswordExpirationPolicy' { '/admin/api/Settings/security/passwordpolicy' }
            'PasswordPolicy' { '/admin/api/Settings/security/passwordpolicy' }
            'PrivacyPolicy' { '/admin/api/Settings/security/privacypolicy' }
            'PrivacyProfile' { '/admin/api/Settings/security/privacypolicy' }
            'PrivilegedAccess' { '/admin/api/Settings/security/tenantLockbox' }
            'SecurityDefaults' { '/admin/api/identitysecurity/securitydefaults' }
            'SecuritySettings' { '/admin/api/securitysettings/settings' }
            'SecuritySettingsStatus' { '/admin/api/securitysettings/settings/status' }
            'SecuritySettingsOptIn' { '/admin/api/securitysettings/optIn' }
            'SelfServicePasswordReset' { '/admin/api/tenant/AADLink' }
            'Sharing' { '/admin/api/Settings/security/guestUserPolicy' }
            'TenantLockbox' { '/admin/api/Settings/security/tenantLockbox' }
        }

        $result = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminSecuritySetting:$Name" -Force:$Force
        $result = Add-SecuritySettingTypeName -InputObject $result -SectionName $Name
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}