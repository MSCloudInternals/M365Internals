function Get-M365AdminDevice {
    <#
    .SYNOPSIS
        Retrieves Intune-managed devices visible in the Microsoft 365 admin center.

    .DESCRIPTION
        Reads the admin center device inventory and returns one typed object per device,
        suitable for filtering, sorting, and exporting. This is the admin center projection,
        not the complete Microsoft Graph managed-device resource. No device actions are performed.

    .PARAMETER Force
        Bypasses the tenant-aware cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the original device records without module metadata.

    .PARAMETER RawJson
        Returns the original inventory as a JSON array, including for zero or one device.

    .EXAMPLE
        Get-M365AdminDevice | Where-Object ComplianceState -eq 'Noncompliant'

        Filters the admin center inventory to devices reported as noncompliant.

    .EXAMPLE
        Get-M365AdminDevice -Force | Select-Object DisplayName, UserPrincipalName, OperatingSystem, LastSyncDateTime

        Retrieves fresh device inventory and selects common troubleshooting fields.

    .OUTPUTS
        Object
        Returns typed device records, original records, or a JSON array.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $path = '/admin/api/Intune/devices'
        $rawResult = @(Get-M365AdminPortalData -Path $path -CacheKey 'M365AdminDevice:Devices' -CacheMinutes 5 -Force:$Force)

        if ($RawJson) {
            return ConvertTo-Json -InputObject $rawResult -Depth 30
        }

        $result = foreach ($device in $rawResult) {
            ConvertTo-M365AdminResult -InputObject $device -TypeName 'M365Admin.Device' -Category 'Devices' -ItemName 'Device' -Endpoint $path
        }

        return Resolve-M365AdminOutput -DefaultValue @($result) -RawValue $rawResult -Raw:$Raw
    }
}
