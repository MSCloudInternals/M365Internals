function New-FixtureSession([string]$Product) {
    $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    if ($Product -ceq 'purview') {
        $session.Cookies.Add([Net.Cookie]::new('sccauth','fixture-secret','/','purview.microsoft.com'))
    }
    else {
        foreach ($name in @('RootAuthToken','SPAAuthCookie','OIDCAuthCookie')) {
            $session.Cookies.Add([Net.Cookie]::new($name,'fixture-secret','/','admin.cloud.microsoft'))
        }
    }
    $session
}
function Connect-PurviewPortal {
    param($ProfilePath,$BrowserPath,$TimeoutSeconds,$TenantId)
    Write-Host 'fixture diagnostic canary'
    if ($ProfilePath -and (Test-Path -LiteralPath $ProfilePath)) { throw 'fixture connection error canary' }
    $script:purviewPortalSession = New-FixtureSession purview
    $script:purviewConnectionRevision = [object]::new()
    $script:purviewPortalConnection = @{TenantId='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'}
}
function Get-PurviewConnection {
    param([switch]$VerifyIdentity,[switch]$Status)
    @{ AccountVerification='Verified';ResourceTenantVerification='Verified' }
}
function Get-PurviewDeviceHealth {
    @{
        UpdatedLast1DayCount=1;Last1DayCount=2;Last3DayCount=3;Last7DayCount=4;Last30DayCount=5
        Raw = 'fixture-secret'
    }
}
function Get-PurviewAuditSearchResult {
    param($PageSize,$ContinuationToken)
    if ($ContinuationToken -and ($ContinuationToken -cne 'fixture-secret+/%=' -or $PageSize -ne 1)) { throw 'fixture request mismatch' }
    if ($ContinuationToken) {
        @{ Records=@(@{jobId='second';searchName='second';createdTimeUtc='2026-01-01';Raw='fixture-secret'});HasMorePages=$false;PageNumber=0 }
    } else {
        @{ Records=@(@{jobId='first';searchName='first';createdTimeUtc='2026-01-02';Raw='fixture-secret'});HasMorePages=$true;ContinuationToken='fixture-secret+/%=';PageNumber=0 }
    }
}
function Get-PurviewEDiscoveryCase {
    param($Id)
    if ($Id -eq 'drift') {
        $script:purviewPortalSession = New-FixtureSession purview
    }
    @{id='case-one';displayName='Case One';status='Active';caseType='Standard';Raw='fixture-secret'}
}
function Connect-M365PortalBySoftwarePasskey {
    param($KeyFilePath,$TenantId)
    Write-Host 'fixture passkey canary'
    $script:m365PortalSession = New-FixtureSession m365
    $script:m365PortalConnection = @{TenantId='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'}
}
function Test-M365PortalIdentity {
    @{ AccountVerification='Verified';ResourceTenantVerification='Verified' }
}
function Get-M365AdminUserSetting {
    param($Name,[switch]$Force,[switch]$Raw)
    # The actual M365 module republishes metadata during normal refresh.
    $script:m365PortalConnection = @{TenantId=$script:m365PortalConnection.TenantId}
    @{ UserInfo=@{ObjectId='fixture-admin';UserPrincipalName='admin@example.test';DisplayName='Lab Admin';Raw='fixture-secret'} }
}
function Invoke-M365PortalRequest {
    param($Path,$WebSession,[switch]$SkipConnectionRefresh,[switch]$SkipAutoHeal,[switch]$RawResponse)
    if ($Path -ne '/admin/api/Domains/List' -or -not $RawResponse -or -not $SkipAutoHeal -or -not $SkipConnectionRefresh) {
        throw 'unexpected fixture endpoint'
    }
    $script:fixtureDomainReads++
    if ($script:fixtureDomainReads -gt 1) {
        @{ Content = '[]' }
    } else {
        @{ Content = '[{"Name":"example.test","Raw":"fixture-secret"}]' }
    }
}
