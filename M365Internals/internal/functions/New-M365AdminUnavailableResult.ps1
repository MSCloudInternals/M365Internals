function New-M365AdminUnavailableResult {
    <#
    .SYNOPSIS
        Creates a standardized unavailable-result object for public admin cmdlets.

    .DESCRIPTION
        Returns a consistent object shape for tenant-specific, optional, or otherwise
        unavailable admin-center results so callers can inspect availability without
        parsing free-form error text.

    .PARAMETER Name
        The section or result name that was unavailable.

    .PARAMETER Description
        A user-friendly description of why the result is unavailable.

    .PARAMETER Status
        The high-level availability state. Defaults to Unavailable.

    .PARAMETER Reason
        A short reason code such as TenantSpecific, Optional, or Transient.

    .PARAMETER ErrorMessage
        Optional raw error message associated with the unavailable result.

    .PARAMETER HttpStatusCode
        Optional HTTP status code associated with the unavailable result.

    .PARAMETER SuggestedAction
        Optional user guidance describing the most likely next step.

    .EXAMPLE
        New-M365AdminUnavailableResult -Name Qnas -Description 'This tenant returns 404.'

        Creates a standardized unavailable result object.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory result object only.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter()]
        [string]$Status = 'Unavailable',

        [Parameter()]
        [string]$Reason = 'TenantSpecific',

        [Parameter()]
        [string]$ErrorMessage,

        [Parameter()]
        [nullable[int]]$HttpStatusCode,

        [Parameter()]
        [string]$SuggestedAction
    )

    process {
        $result = [pscustomobject]@{
            Name           = $Name
            DataBacked     = $false
            Status         = $Status
            Reason         = $Reason
            HttpStatusCode = $HttpStatusCode
            Description    = $Description
            SuggestedAction = $SuggestedAction
            Error          = $ErrorMessage
        }

        return Add-M365TypeName -InputObject $result -TypeName 'M365Admin.UnavailableResult'
    }
}

function New-M365AdminUnavailableResultFromError {
    <#
    .SYNOPSIS
        Creates a standardized unavailable result from a portal error.

    .DESCRIPTION
        Interprets common admin-center HTTP failures and returns a standardized unavailable
        result with more actionable licensing, provisioning, access, or retry guidance.

    .PARAMETER Name
        The section or result name that was unavailable.

    .PARAMETER Area
        A short description of the feature area for user-facing messaging.

    .PARAMETER ErrorMessage
        The raw portal error message.

    .PARAMETER DefaultDescription
        The fallback description when no specialized guidance applies.

    .PARAMETER DefaultReason
        The fallback reason when no specialized guidance applies.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory result object only.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Area,

        [Parameter()]
        [string]$ErrorMessage,

        [Parameter()]
        [string]$DefaultDescription = 'This admin-center section did not return a usable payload in the current tenant.',

        [Parameter()]
        [string]$DefaultReason = 'TenantSpecific'
    )

    process {
        $httpStatusCode = $null
        $description = $DefaultDescription
        $reason = $DefaultReason
        $suggestedAction = 'Retry later or inspect the Error field for the raw admin-center response.'

        if (-not [string]::IsNullOrWhiteSpace($ErrorMessage) -and $ErrorMessage -match '\b(?<StatusCode>400|401|403|404|409|429|500|503)\b') {
            $httpStatusCode = [int]$Matches.StatusCode
        }

        switch ($httpStatusCode) {
            400 {
                $description = "This $Area is not currently available in the tenant. The backing workload may not be licensed, provisioned, or enabled yet."
                $reason = 'ProvisioningOrLicensing'
                $suggestedAction = 'Confirm the tenant has the required product license or add-on, open the workload in the admin center to complete first-run provisioning if needed, and then retry.'
            }
            401 {
                $description = "This $Area is not currently available to the signed-in admin session. The session may need to be refreshed before this workload can be accessed."
                $reason = 'AccessDenied'
                $suggestedAction = 'Reconnect to the admin center, confirm the session is still valid, and retry.'
            }
            403 {
                $description = "This $Area is not currently available to the signed-in admin. The account may not have the required role, or the workload may be restricted in this tenant."
                $reason = 'AccessDenied'
                $suggestedAction = 'Verify the signed-in account has the required admin role and that the workload is enabled for this tenant, then retry.'
            }
            404 {
                $description = "This $Area is not currently exposed in the tenant. The backing workload may not be provisioned, licensed, or applicable to the current tenant configuration."
                $reason = 'ProvisioningOrLicensing'
                $suggestedAction = 'Verify the workload is licensed and initialized for the tenant, then retry after the service is fully provisioned.'
            }
            429 {
                $description = "This $Area is temporarily unavailable because the admin center is throttling requests."
                $reason = 'Throttled'
                $suggestedAction = 'Wait a few minutes for the throttling window to clear, then retry.'
            }
            500 {
                $description = "This $Area is temporarily unavailable because the admin center returned an internal error."
                $reason = 'Transient'
                $suggestedAction = 'Retry later. If the issue persists, compare with the live portal experience to confirm whether the service is degraded.'
            }
            503 {
                $description = "This $Area is temporarily unavailable because the backing service is not responding successfully."
                $reason = 'Transient'
                $suggestedAction = 'Retry later. If the service remains unavailable, verify the same section in the live admin portal.'
            }
        }

        return New-M365AdminUnavailableResult -Name $Name -Description $description -Reason $reason -ErrorMessage $ErrorMessage -HttpStatusCode $httpStatusCode -SuggestedAction $suggestedAction
    }
}