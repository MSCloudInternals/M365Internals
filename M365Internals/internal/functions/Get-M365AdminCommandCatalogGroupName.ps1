function Get-M365AdminCommandCatalogGroupName {
    <#
    .SYNOPSIS
        Resolves the functional command-catalog group for a public M365Internals cmdlet.

    .DESCRIPTION
        Maps a public command name to the canonical functional command-catalog group used by the
        runtime discovery cmdlet and the generated README command index.

    .PARAMETER CmdletName
        The public cmdlet name to classify.

    .EXAMPLE
        Get-M365AdminCommandCatalogGroupName -CmdletName 'Get-M365AdminAppSetting'

        Returns the functional group key for the specified public cmdlet.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$CmdletName
    )

    process {
        switch -Regex ($CmdletName) {
            '^Connect-M365Portal' { return 'Authentication' }
            '^Set-M365Admin' { return 'WriteOperations' }
            '^Invoke-M365AdminRestMethod$' { return 'AdvancedAccess' }
            'Agent|Copilot' { return 'AgentsAndCopilot' }
            'AppSetting|Bookings|BrandCenter|CompanySetting|ContentUnderstandingSetting|IntegratedAppSetting|Microsoft365BackupSetting|Microsoft365GroupSetting|Microsoft365InstallationOption|MicrosoftEdgeSetting|PayAsYouGoService|PeopleSetting|SecuritySetting|SelfServicePurchaseSetting|Service|UserOwnedAppSetting|VivaSetting' {
                return 'OrgSettingsAndWorkloads'
            }
            'SearchAndIntelligenceSetting|SearchSetting|ReportSetting|Recommendation|EnhancedRestoreStatus' {
                return 'SearchReportsAndInsights'
            }
            'Domain|Group|PartnerClient|PartnerRelationship|TenantRelationship|TenantSetting|UserSetting' {
                return 'TenantUsersAndRelationships'
            }
            'CommandCatalog|DirectorySyncError|Feature|HomeData|Navigation|ShellInfo' {
                return 'PlatformAndUtilities'
            }
            default {
                return 'PlatformAndUtilities'
            }
        }
    }
}