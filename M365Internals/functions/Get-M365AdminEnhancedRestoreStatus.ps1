function Get-M365AdminEnhancedRestoreStatus {
    <#
    .SYNOPSIS
        Retrieves enhanced restore offboarding status from the Microsoft 365 admin center.

    .DESCRIPTION
        Reads the offboarding protection unit counts used by the Enhanced Restore settings page.
        The cmdlet uses the admin center Graph proxy batch endpoint observed in the portal HAR and
        returns the current site, drive, and mailbox offboarding counts together with the raw batch
        responses.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw Graph batch response instead of the summarized offboarding counts.

    .PARAMETER RawJson
        Returns the raw Graph batch response serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminEnhancedRestoreStatus

        Retrieves the current enhanced restore offboarding counts.

    .OUTPUTS
        Object
        Returns the summarized offboarding counts and raw Graph batch responses.
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

    begin {
        Update-M365PortalConnectionSettings
    }

    process {
        $summaryCacheKey = 'M365AdminEnhancedRestoreStatus'
        $rawCacheKey = 'M365AdminEnhancedRestoreStatus:Raw'
        $cacheKey = if ($Raw -or $RawJson) { $rawCacheKey } else { $summaryCacheKey }
        $currentCacheValue = Get-M365Cache -CacheKey $cacheKey -ErrorAction SilentlyContinue
        if (-not $Force -and $currentCacheValue -and $currentCacheValue.NotValidAfter -gt (Get-Date)) {
            Write-Verbose "Using cached $cacheKey data"
            return Resolve-M365AdminOutput -DefaultValue $currentCacheValue.Value -Raw:$Raw -RawJson:$RawJson
        }
        elseif ($Force) {
            Write-Verbose 'Force parameter specified, bypassing cache'
            Clear-M365Cache -CacheKey $summaryCacheKey
            Clear-M365Cache -CacheKey $rawCacheKey
        }

        $batchBody = @{
            requests = @(
                @{
                    id     = 'GetOffboardingSiteProtectionUnits'
                    method = 'GET'
                    url    = 'solutions/backupRestore/protectionUnits/microsoft.graph.siteProtectionUnit/$count?$filter=offboardRequestedDateTime gt 0001-01-01'
                },
                @{
                    id     = 'GetOffboardingDriveProtectionUnits'
                    method = 'GET'
                    url    = 'solutions/backupRestore/protectionUnits/microsoft.graph.driveProtectionUnit/$count?$filter=offboardRequestedDateTime gt 0001-01-01'
                },
                @{
                    id     = 'GetOffboardingMailboxProtectionUnits'
                    method = 'GET'
                    url    = 'solutions/backupRestore/protectionUnits/microsoft.graph.mailboxProtectionUnit/$count?$filter=offboardRequestedDateTime gt 0001-01-01'
                }
            )
        }

        try {
            $result = Invoke-M365AdminGraphRequest -Path '/beta/$batch' -Method Post -AdminAppRequest '/Settings/enhancedRestore' -Body $batchBody
        }
        catch {
            throw "Failed to retrieve M365 admin enhanced restore status: $($_.Exception.Message)"
        }

        $responsesById = @{}
        foreach ($response in @($result.responses)) {
            $responsesById[$response.id] = $response
        }

        $summary = [pscustomobject]@{
            SiteOffboardingCount = if ($responsesById['GetOffboardingSiteProtectionUnits'] -and $responsesById['GetOffboardingSiteProtectionUnits'].status -eq 200) { [int]$responsesById['GetOffboardingSiteProtectionUnits'].body } else { $null }
            DriveOffboardingCount = if ($responsesById['GetOffboardingDriveProtectionUnits'] -and $responsesById['GetOffboardingDriveProtectionUnits'].status -eq 200) { [int]$responsesById['GetOffboardingDriveProtectionUnits'].body } else { $null }
            MailboxOffboardingCount = if ($responsesById['GetOffboardingMailboxProtectionUnits'] -and $responsesById['GetOffboardingMailboxProtectionUnits'].status -eq 200) { [int]$responsesById['GetOffboardingMailboxProtectionUnits'].body } else { $null }
            RawResponses = @($result.responses)
        }
        $summary = Add-M365TypeName -InputObject $summary -TypeName 'M365Admin.EnhancedRestoreStatus'

        if ((@($result.responses | Where-Object { $_.status -ge 400 })).Count -eq 0) {
            Set-M365Cache -CacheKey $summaryCacheKey -Value $summary -TTLMinutes 15 | Out-Null
            Set-M365Cache -CacheKey $rawCacheKey -Value $result -TTLMinutes 15 | Out-Null
        }

        return Resolve-M365AdminOutput -DefaultValue $summary -RawValue $result -Raw:$Raw -RawJson:$RawJson
    }
}