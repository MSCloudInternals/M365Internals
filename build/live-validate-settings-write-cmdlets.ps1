param ()

$artifactRoot = Join-Path (Join-Path $PSScriptRoot '..\TestResults') 'Artifacts'
$logPath = Join-Path $artifactRoot 'live-admin-write-expansion-log.md'
$resultPath = Join-Path $artifactRoot 'settings-write-validation.json'

$null = New-Item -Path $artifactRoot -ItemType Directory -Force

function Add-RunLog {
    param (
        [Parameter(Mandatory)]
        [string]$Message
    )

    Add-Content -Path $logPath -Value $Message
}

function Invoke-NoOpValidation {
    param (
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [scriptblock]$Getter,

        [Parameter(Mandatory)]
        [scriptblock]$Setter,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $current = & $Getter
    $value = $current.$PropertyName

    Add-RunLog ("- {0} baseline: {1} = {2}" -f $Label, $PropertyName, (ConvertTo-Json $value -Compress -Depth 20))

    $passThru = & $Setter $value

    Add-RunLog ("- {0} no-op validation succeeded: {1} remained {2}" -f $Label, $PropertyName, (ConvertTo-Json $passThru.$PropertyName -Compress -Depth 20))

    return [pscustomobject]@{
        Label = $Label
        ValidationType = 'NoOp'
        PropertyName = $PropertyName
        OriginalValue = $value
        UpdatedValue = $passThru.$PropertyName
        RestoredValue = $passThru.$PropertyName
    }
}

function Invoke-ReversibleToggleValidation {
    param (
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [scriptblock]$Getter,

        [Parameter(Mandatory)]
        [scriptblock]$Setter,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [int]$SleepSeconds = 5
    )

    $original = & $Getter
    $originalValue = [bool]$original.$PropertyName
    $targetValue = -not $originalValue
    $updated = $null
    $restored = $null

    Add-RunLog ("- {0} baseline: {1} = {2}" -f $Label, $PropertyName, ($originalValue.ToString().ToLowerInvariant()))
    Add-RunLog ("- {0} target change: {1} {2} -> {3}" -f $Label, $PropertyName, ($originalValue.ToString().ToLowerInvariant()), ($targetValue.ToString().ToLowerInvariant()))

    try {
        $null = & $Setter $targetValue
        Start-Sleep -Seconds $SleepSeconds
        $updated = & $Getter
        Add-RunLog ("- {0} after change: {1} = {2}" -f $Label, $PropertyName, ([bool]$updated.$PropertyName).ToString().ToLowerInvariant())
    }
    finally {
        $null = & $Setter $originalValue
        Start-Sleep -Seconds $SleepSeconds
        $restored = & $Getter
        Add-RunLog ("- {0} after restore: {1} = {2}" -f $Label, $PropertyName, ([bool]$restored.$PropertyName).ToString().ToLowerInvariant())
    }

    return [pscustomobject]@{
        Label = $Label
        ValidationType = 'Toggle'
        PropertyName = $PropertyName
        OriginalValue = $originalValue
        UpdatedValue = [bool]$updated.$PropertyName
        RestoredValue = [bool]$restored.$PropertyName
    }
}

$results = @()

$results += Invoke-NoOpValidation -Label 'CompanyHelpDesk' -Getter {
    Get-M365AdminCompanySetting -Name HelpDesk -Force
} -Setter {
    param($Value)
    Set-M365AdminCompanySetting -Name HelpDesk -Settings @{ CustomSupportEnabled = $Value } -PassThru -Confirm:$false
} -PropertyName 'CustomSupportEnabled'

$results += Invoke-NoOpValidation -Label 'CompanyProfile' -Getter {
    Get-M365AdminCompanySetting -Name Profile -Force
} -Setter {
    param($Value)
    Set-M365AdminCompanySetting -Name Profile -Settings @{ Name = $Value } -PassThru -Confirm:$false
} -PropertyName 'Name'

$results += Invoke-NoOpValidation -Label 'CompanyReleaseTrack' -Getter {
    Get-M365AdminCompanySetting -Name ReleaseTrack -Force
} -Setter {
    param($Value)
    Set-M365AdminCompanySetting -Name ReleaseTrack -Settings @{ ReleaseTrack = $Value } -PassThru -Confirm:$false
} -PropertyName 'ReleaseTrack'

$results += Invoke-NoOpValidation -Label 'CompanySendFromAddress' -Getter {
    Get-M365AdminCompanySetting -Name SendFromAddress -Force
} -Setter {
    param($Value)
    Set-M365AdminCompanySetting -Name SendFromAddress -Settings @{ ServiceEnabled = $Value } -PassThru -Confirm:$false
} -PropertyName 'ServiceEnabled'

$results += Invoke-NoOpValidation -Label 'CompanyTheme' -Getter {
    Get-M365AdminCompanySetting -Name Theme -Force
} -Setter {
    param($Value)
    Set-M365AdminCompanySetting -Name Theme -Settings @{ ShowMeControl = $Value } -PassThru -Confirm:$false
} -PropertyName 'ShowMeControl'

$results += Invoke-NoOpValidation -Label 'CompanyTile' -Getter {
    Get-M365AdminCompanySetting -Name Tile -Force
} -Setter {
    param($Value)
    Set-M365AdminCompanySetting -Name Tile -Settings @{ Tiles = $Value } -PassThru -Confirm:$false
} -PropertyName 'Tiles'

$results += Invoke-ReversibleToggleValidation -Label 'SecurityBingDataCollection' -Getter {
    Get-M365AdminSecuritySetting -Name BingDataCollection -Force
} -Setter {
    param($Value)
    Set-M365AdminSecuritySetting -Name BingDataCollection -Settings @{ IsBingDataCollectionConsented = $Value } -Confirm:$false
} -PropertyName 'IsBingDataCollectionConsented'

$results += Invoke-NoOpValidation -Label 'SecurityDataAccess' -Getter {
    Get-M365AdminSecuritySetting -Name DataAccess -Force
} -Setter {
    param($Value)
    Set-M365AdminSecuritySetting -Name DataAccess -Settings @{ RequireApproval = $Value } -PassThru -Confirm:$false
} -PropertyName 'RequireApproval'

$results += Invoke-NoOpValidation -Label 'SecurityGuestUserPolicy' -Getter {
    Get-M365AdminSecuritySetting -Name GuestUserPolicy -Force
} -Setter {
    param($Value)
    Set-M365AdminSecuritySetting -Name GuestUserPolicy -Settings @{ AllowGuestInvitations = $Value } -PassThru -Confirm:$false
} -PropertyName 'AllowGuestInvitations'

$results += Invoke-NoOpValidation -Label 'SecurityO365GuestUser' -Getter {
    Get-M365AdminSecuritySetting -Name O365GuestUser -Force
} -Setter {
    param($Value)
    Set-M365AdminSecuritySetting -Name O365GuestUser -Settings @{ AllowGuestAccess = $Value } -PassThru -Confirm:$false
} -PropertyName 'AllowGuestAccess'

$results += Invoke-NoOpValidation -Label 'SecurityPasswordPolicy' -Getter {
    Get-M365AdminSecuritySetting -Name PasswordPolicy -Force
} -Setter {
    param($Value)
    Set-M365AdminSecuritySetting -Name PasswordPolicy -Settings @{ NotificationDays = $Value } -PassThru -Confirm:$false
} -PropertyName 'NotificationDays'

$results += Invoke-NoOpValidation -Label 'SecurityPrivacyPolicy' -Getter {
    Get-M365AdminSecuritySetting -Name PrivacyPolicy -Force
} -Setter {
    param($Value)
    Set-M365AdminSecuritySetting -Name PrivacyPolicy -Settings @{ PrivacyStatement = $Value } -PassThru -Confirm:$false
} -PropertyName 'PrivacyStatement'

$results += Invoke-NoOpValidation -Label 'SecurityTenantLockbox' -Getter {
    Get-M365AdminSecuritySetting -Name TenantLockbox -Force
} -Setter {
    param($Value)
    Set-M365AdminSecuritySetting -Name TenantLockbox -Settings @{ EnabledTenantLockbox = $Value } -PassThru -Confirm:$false
} -PropertyName 'EnabledTenantLockbox'

$results += Invoke-NoOpValidation -Label 'SecurityDefaults' -Getter {
    Get-M365AdminSecuritySetting -Name SecurityDefaults -Force
} -Setter {
    param($Value)
    Set-M365AdminSecuritySetting -Name SecurityDefaults -Settings @{ isEnabled = $Value } -PassThru -Confirm:$false
} -PropertyName 'isEnabled'

$results += Invoke-ReversibleToggleValidation -Label 'PeopleNamePronunciation' -Getter {
    Get-M365AdminPeopleSetting -Name NamePronunciation -Force
} -Setter {
    param($Value)
    Set-M365AdminPeopleSetting -Name NamePronunciation -Settings @{ isEnabledInOrganization = $Value } -Confirm:$false
} -PropertyName 'isEnabledInOrganization'

$results += Invoke-ReversibleToggleValidation -Label 'PeoplePronouns' -Getter {
    Get-M365AdminPeopleSetting -Name Pronouns -Force
} -Setter {
    param($Value)
    Set-M365AdminPeopleSetting -Name Pronouns -Settings @{ isEnabledInOrganization = $Value } -Confirm:$false
} -PropertyName 'isEnabledInOrganization'

$results += Invoke-NoOpValidation -Label 'Microsoft365GroupGuestAccess' -Getter {
    Get-M365AdminMicrosoft365GroupSetting -Name GuestAccess -Force
} -Setter {
    param($Value)
    Set-M365AdminMicrosoft365GroupSetting -Name GuestAccess -Settings @{ AllowGuestAccess = $Value } -PassThru -Confirm:$false
} -PropertyName 'AllowGuestAccess'

$results += Invoke-NoOpValidation -Label 'Microsoft365GroupGuestUserPolicy' -Getter {
    Get-M365AdminMicrosoft365GroupSetting -Name GuestUserPolicy -Force
} -Setter {
    param($Value)
    Set-M365AdminMicrosoft365GroupSetting -Name GuestUserPolicy -Settings @{ AllowGuestInvitations = $Value } -PassThru -Confirm:$false
} -PropertyName 'AllowGuestInvitations'

$summary = [pscustomobject]@{
    ValidatedAt = (Get-Date).ToUniversalTime().ToString('o')
    Results = $results
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -Path $resultPath
$summary | ConvertTo-Json -Depth 10