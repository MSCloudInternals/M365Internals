function Get-M365AdminMicrosoft365InstallationOption {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 installation options settings.

    .DESCRIPTION
        Reads the payloads used by the Org settings Microsoft 365 installation options page,
        including software download policy, release-management configuration, and servicing
        channel metadata.

    .PARAMETER Name
        The installation options payload to retrieve.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw installation options payload for the selected section.

    .PARAMETER RawJson
        Returns the raw installation options payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminMicrosoft365InstallationOption

        Retrieves the full Microsoft 365 installation options payload set.

    .OUTPUTS
        Object
        Returns the selected installation options payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('All', 'DefaultReleaseRule', 'EligibleToRemoveSac', 'MecReleaseInfo', 'MonthlyReleaseInfo', 'ReleaseManagement', 'SacReleaseInfo', 'TenantInfo', 'UserSoftware')]
        [string]$Name = 'All',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $tenantId = Get-M365PortalTenantId

        switch ($Name) {
            'All' {
                $result = [pscustomobject]@{
                    UserSoftware        = Get-M365AdminPortalData -Path '/admin/api/settings/apps/usersoftware' -CacheKey 'M365AdminMicrosoft365InstallationOption:UserSoftware' -Force:$Force
                    TenantInfo          = Get-M365AdminPortalData -Path ("/fd/dms/odata/TenantInfo({0})" -f $tenantId) -CacheKey 'M365AdminMicrosoft365InstallationOption:TenantInfo' -Force:$Force
                    DefaultReleaseRule  = Get-M365AdminPortalData -Path "/fd/dms/odata/C2RReleaseRule?$filter=FFN eq 55336b82-a18d-4dd6-b5f6-9e5095c314a6 and IsDefault eq true" -CacheKey 'M365AdminMicrosoft365InstallationOption:DefaultReleaseRule' -Force:$Force
                    ReleaseManagement   = Get-M365AdminPortalData -Path ("/fd/oacms/api/ReleaseManagement/admin?tenantId={0}" -f $tenantId) -CacheKey 'M365AdminMicrosoft365InstallationOption:ReleaseManagement' -Force:$Force
                    MecReleaseInfo      = Get-M365AdminPortalData -Path "/fd/dms/odata/C2RReleaseInfo?$filter=ServicingChannel eq 'MEC'&$orderby=ReleaseVersion desc&$top=1" -CacheKey 'M365AdminMicrosoft365InstallationOption:MecReleaseInfo' -Force:$Force
                    SacReleaseInfo      = Get-M365AdminPortalData -Path "/fd/dms/odata/C2RReleaseInfo?$filter=ServicingChannel eq 'SAC'&$orderby=ReleaseVersion desc&$top=1" -CacheKey 'M365AdminMicrosoft365InstallationOption:SacReleaseInfo' -Force:$Force
                    MonthlyReleaseInfo  = Get-M365AdminPortalData -Path "/fd/dms/odata/C2RReleaseInfo?$filter=ServicingChannel eq 'Monthly'&$orderby=ReleaseVersion desc&$top=1" -CacheKey 'M365AdminMicrosoft365InstallationOption:MonthlyReleaseInfo' -Force:$Force
                    EligibleToRemoveSac = Get-M365AdminPortalData -Path '/admin/api/tenant/isTenantEligibleToRemoveSAC' -CacheKey 'M365AdminMicrosoft365InstallationOption:EligibleToRemoveSac' -Force:$Force
                }

                $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.Microsoft365InstallationOption'
                return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
            }
            'UserSoftware' {
                $path = '/admin/api/settings/apps/usersoftware'
            }
            'TenantInfo' {
                $path = "/fd/dms/odata/TenantInfo({0})" -f $tenantId
            }
            'DefaultReleaseRule' {
                $path = "/fd/dms/odata/C2RReleaseRule?$filter=FFN eq 55336b82-a18d-4dd6-b5f6-9e5095c314a6 and IsDefault eq true"
            }
            'ReleaseManagement' {
                $path = "/fd/oacms/api/ReleaseManagement/admin?tenantId={0}" -f $tenantId
            }
            'MecReleaseInfo' {
                $path = "/fd/dms/odata/C2RReleaseInfo?$filter=ServicingChannel eq 'MEC'&$orderby=ReleaseVersion desc&$top=1"
            }
            'SacReleaseInfo' {
                $path = "/fd/dms/odata/C2RReleaseInfo?$filter=ServicingChannel eq 'SAC'&$orderby=ReleaseVersion desc&$top=1"
            }
            'MonthlyReleaseInfo' {
                $path = "/fd/dms/odata/C2RReleaseInfo?$filter=ServicingChannel eq 'Monthly'&$orderby=ReleaseVersion desc&$top=1"
            }
            'EligibleToRemoveSac' {
                $path = '/admin/api/tenant/isTenantEligibleToRemoveSAC'
            }
        }

        $result = Get-M365AdminPortalData -Path $path -CacheKey "M365AdminMicrosoft365InstallationOption:$Name" -Force:$Force
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}