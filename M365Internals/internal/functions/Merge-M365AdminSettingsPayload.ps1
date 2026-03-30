function Merge-M365AdminSettingsPayload {
    <#
    .SYNOPSIS
        Merges updated setting values into an existing admin-center payload.

    .DESCRIPTION
        Creates a mutable copy of an existing admin-center settings payload and overlays the
        provided key-value pairs so the resulting object can be sent back to the admin center.

    .PARAMETER CurrentSettings
        The current admin-center payload returned by a getter cmdlet.

    .PARAMETER Settings
        The setting values to overlay onto the current payload.

    .EXAMPLE
        Merge-M365AdminSettingsPayload -CurrentSettings $current -Settings @{ Enabled = $true }

        Returns a mutable payload with the `Enabled` property updated.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Builds an in-memory payload only.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $CurrentSettings,

        [Parameter(Mandatory)]
        [hashtable]$Settings
    )

    process {
        if ($null -eq $CurrentSettings) {
            throw 'The current settings payload was null.'
        }

        if ($CurrentSettings.PSObject.TypeNames -contains 'M365Admin.UnavailableResult') {
            $message = "Cannot update unavailable settings payload '$($CurrentSettings.Name)'. $($CurrentSettings.Description)"

            if (($CurrentSettings.PSObject.Properties.Name -contains 'SuggestedAction') -and -not [string]::IsNullOrWhiteSpace([string]$CurrentSettings.SuggestedAction)) {
                $message = "{0} {1}" -f $message, $CurrentSettings.SuggestedAction
            }

            throw $message
        }

        if ($Settings.Count -eq 0) {
            throw 'At least one setting value must be provided.'
        }

        $body = $CurrentSettings | ConvertTo-Json -Depth 30 | ConvertFrom-Json -Depth 30
        if ($body -isnot [pscustomobject]) {
            $body = [pscustomobject]@{}
        }

        foreach ($settingEntry in @($Settings.GetEnumerator())) {
            if ($body.PSObject.Properties.Name -contains $settingEntry.Key) {
                $body.($settingEntry.Key) = $settingEntry.Value
            }
            else {
                Add-Member -InputObject $body -NotePropertyName $settingEntry.Key -NotePropertyValue $settingEntry.Value -Force
            }
        }

        return $body
    }
}
