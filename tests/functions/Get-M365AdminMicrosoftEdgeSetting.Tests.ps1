Describe 'Get-M365AdminMicrosoftEdgeSetting' {
    BeforeEach {
        Mock -ModuleName M365Internals Get-M365AdminPortalData {
            switch ($Path) {
                '/fd/OfficePolicyAdmin/v1.0/edge/policies' { [pscustomobject]@{ value = @('policy') } }
                '/fd/edgeenterpriseextensionsmanagement/api/featureManagement/profiles' { [pscustomobject]@{ value = @('profile') } }
                '/fd/edgeenterpriseextensionsmanagement/api/policies' { [pscustomobject]@{ value = @('extensionPolicy') } }
                '/fd/edgeenterpriseextensionsmanagement/api/extensions/extensionFeedback' { [pscustomobject]@{ value = @('feedback') } }
                default { throw "Unexpected path: $Path" }
            }
        }

        Mock -ModuleName M365Internals Get-M365AdminEdgeSiteList {
            [pscustomobject]@{ SiteLists = @('list') }
        }

        Mock -ModuleName M365Internals Invoke-M365AdminRestMethod {
            [pscustomobject]@{
                '@odata.count' = 42
                value          = @([pscustomobject]@{ id = 'device-1' })
            }
        }
    }

    It 'returns a device summary by default' {
        $result = Get-M365AdminMicrosoftEdgeSetting -Name DeviceCount

        $result.PSObject.TypeNames | Should -Contain 'M365Admin.MicrosoftEdgeSetting.DeviceCount'
        $result.Count | Should -Be 42
        $result.RawSettings.'@odata.count' | Should -Be 42
    }

    It 'returns the raw graph payload for device counts when Raw is used' {
        $result = Get-M365AdminMicrosoftEdgeSetting -Name DeviceCount -Raw

        $result.'@odata.count' | Should -Be 42
        $result.value[0].id | Should -Be 'device-1'
    }

    It 'returns the raw graph payload as JSON when RawJson is used' {
        $result = Get-M365AdminMicrosoftEdgeSetting -Name DeviceCount -RawJson

        $result | Should -BeOfType ([string])
        $result | Should -Match '"@odata.count"\s*:\s*42'
        $result | Should -Match '"device-1"'
    }
}