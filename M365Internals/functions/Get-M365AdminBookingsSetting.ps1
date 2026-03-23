function Get-M365AdminBookingsSetting {
    <#
    .SYNOPSIS
        Retrieves Microsoft Bookings settings from the Microsoft 365 admin center.

    .DESCRIPTION
        Reads the Bookings flyout payload exposed by the Microsoft 365 admin center at
        /admin/api/settings/apps/bookings. By default, the cmdlet returns a summarized object
        with friendly property names that align with the Bookings controls shown under
        Settings > Org settings > Bookings.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw Bookings settings payload from the admin center without applying the
        friendly property mapping.

    .EXAMPLE
        Get-M365AdminBookingsSetting

        Retrieves the current Bookings settings as a summarized object.

    .EXAMPLE
        Get-M365AdminBookingsSetting -Raw

        Retrieves the raw Bookings settings payload from the admin center.

    .OUTPUTS
        Object
        Returns either the summarized Bookings settings view or the raw payload.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $settings = Get-M365AdminPortalData -Path '/admin/api/settings/apps/bookings' -CacheKey 'M365AdminAppSetting:Bookings' -Force:$Force

        if ($Raw) {
            return $settings
        }

        $result = [pscustomobject]@{
            BookingsEnabled                = $settings.Enabled
            PaymentsToggleVisible          = $settings.ShowPaymentsToggle
            PaymentsEnabled                = $settings.PaymentsEnabled
            SocialSharingToggleVisible     = $settings.ShowSocialSharingToggle
            SocialSharingBlocked           = $settings.SocialSharingRestricted
            AddressEntryToggleVisible      = $settings.ShowBookingsAddressEntryRestrictedToggle
            AddressEntryBlocked            = $settings.BookingsAddressEntryRestricted
            SignInRequiredToggleVisible    = $settings.ShowBookingsAuthEnabledToggle
            SignInRequired                 = $settings.BookingsAuthEnabled
            CustomQuestionsToggleVisible   = $settings.ShowBookingsCreationOfCustomQuestionsRestrictedToggle
            CustomQuestionsBlocked         = $settings.BookingsCreationOfCustomQuestionsRestricted
            StaffDetailsToggleVisible      = $settings.ShowBookingsExposureOfStaffDetailsRestrictedToggle
            StaffDetailsBlocked            = $settings.BookingsExposureOfStaffDetailsRestricted
            NotesEntryToggleVisible        = $settings.ShowBookingsNotesEntryRestrictedToggle
            NotesEntryBlocked              = $settings.BookingsNotesEntryRestricted
            PhoneNumberToggleVisible       = $settings.ShowBookingsPhoneNumberEntryRestrictedToggle
            PhoneNumberBlocked             = $settings.BookingsPhoneNumberEntryRestricted
            SmsToggleVisible               = $settings.ShowBookingsSmsMicrosoftEnabledToggle
            SmsNotificationsEnabled        = $settings.BookingsSmsMicrosoftEnabled
            NamingPolicyToggleVisible      = $settings.ShowBookingsNamingPolicyEnabledToggle
            NamingPolicyEnabled            = $settings.BookingsNamingPolicyEnabled
            BlockedWordsToggleVisible      = $settings.ShowBookingsBlockedWordsEnabledToggle
            BlockedWordsEnabled            = $settings.BookingsBlockedWordsEnabled
            PrefixToggleVisible            = $settings.ShowBookingsNamingPolicyPrefixEnabledToggle
            PrefixEnabled                  = $settings.BookingsNamingPolicyPrefixEnabled
            Prefix                         = $settings.BookingsNamingPolicyPrefix
            SuffixToggleVisible            = $settings.ShowBookingsNamingPolicySuffixEnabledToggle
            SuffixEnabled                  = $settings.BookingsNamingPolicySuffixEnabled
            Suffix                         = $settings.BookingsNamingPolicySuffix
            SearchEngineIndexToggleVisible = $settings.ShowBookingsSearchEngineIndexDisabledToggle
            SearchEngineIndexBlocked       = $settings.BookingsSearchEngineIndexDisabled
            StaffApprovalToggleVisible     = $settings.ShowStaffApprovalsToggle
            StaffApprovalRequired          = $settings.StaffMembershipApprovalRequired
            ProductUrl                     = $settings.ProductUrl
            LearnMoreUrl                   = $settings.LearnMoreUrl
            PaymentsLearnMoreUrl           = $settings.PaymentsLearnMoreUrl
            RawSettings                    = $settings
        }
        $result.PSObject.TypeNames.Insert(0, 'M365Admin.BookingsSetting')

        return $result
    }
}