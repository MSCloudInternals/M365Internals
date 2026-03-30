Describe 'Get-M365AdminBookingsSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            [pscustomobject]@{
                Enabled                                        = $false
                ShowPaymentsToggle                             = $true
                PaymentsEnabled                                = $false
                ShowSocialSharingToggle                        = $true
                SocialSharingRestricted                        = $false
                ShowBookingsAddressEntryRestrictedToggle       = $true
                BookingsAddressEntryRestricted                 = $false
                ShowBookingsAuthEnabledToggle                  = $true
                BookingsAuthEnabled                            = $true
                ShowBookingsCreationOfCustomQuestionsRestrictedToggle = $false
                BookingsCreationOfCustomQuestionsRestricted    = $false
                ShowBookingsExposureOfStaffDetailsRestrictedToggle = $false
                BookingsExposureOfStaffDetailsRestricted       = $false
                ShowBookingsNotesEntryRestrictedToggle         = $false
                BookingsNotesEntryRestricted                   = $false
                ShowBookingsPhoneNumberEntryRestrictedToggle   = $false
                BookingsPhoneNumberEntryRestricted             = $false
                ShowBookingsSmsMicrosoftEnabledToggle          = $true
                BookingsSmsMicrosoftEnabled                    = $true
                ShowBookingsNamingPolicyEnabledToggle          = $false
                BookingsNamingPolicyEnabled                    = $false
                ShowBookingsBlockedWordsEnabledToggle          = $false
                BookingsBlockedWordsEnabled                    = $false
                ShowBookingsNamingPolicyPrefixEnabledToggle    = $false
                BookingsNamingPolicyPrefixEnabled              = $false
                BookingsNamingPolicyPrefix                     = ''
                ShowBookingsNamingPolicySuffixEnabledToggle    = $false
                BookingsNamingPolicySuffixEnabled              = $false
                BookingsNamingPolicySuffix                     = ''
                ShowBookingsSearchEngineIndexDisabledToggle    = $false
                BookingsSearchEngineIndexDisabled              = $false
                ShowStaffApprovalsToggle                       = $true
                StaffMembershipApprovalRequired                = $false
                ProductUrl                                     = 'https://example.test/bookings'
                LearnMoreUrl                                   = 'https://example.test/learn'
                PaymentsLearnMoreUrl                           = 'https://example.test/payments'
            }
        }
    }

    It 'returns a friendly summary by default' {
        $result = Get-M365AdminBookingsSetting

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.BookingsSetting'
        $result.BookingsEnabled | Should -Be $false
        $result.PaymentsToggleVisible | Should -Be $true
        $result.RawSettings.Enabled | Should -Be $false
    }

    It 'returns the raw payload when Raw is used' {
        $result = Get-M365AdminBookingsSetting -Raw

        $result.Enabled | Should -Be $false
        $result.PSObject.Properties.Name | Should -Contain 'ShowPaymentsToggle'
    }

    It 'returns the raw payload as JSON when RawJson is used' {
        $result = Get-M365AdminBookingsSetting -RawJson

        $result | Should -BeOfType ([string])
        $result | Should -Match '"Enabled"\s*:\s*false'
        $result | Should -Match '"ShowPaymentsToggle"\s*:\s*true'
    }
}