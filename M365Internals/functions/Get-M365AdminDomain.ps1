function Get-M365AdminDomain {
    <#
    .SYNOPSIS
        Retrieves Microsoft 365 admin center domain data.

    .DESCRIPTION
        Reads domain inventory, DNS health, records, dependency, and export data from the domain
        endpoints observed in the admin center settings HAR.

    .PARAMETER List
        Retrieves the domain list payload.

    .PARAMETER Customization
        Retrieves the domain customization payload.

    .PARAMETER BuyModel
        Retrieves the domain purchase model payload.

    .PARAMETER RegistrarsHelpInfo
        Retrieves registrar help information.

    .PARAMETER Records
        Retrieves DNS records for a domain.

    .PARAMETER ListingCategory
        Retrieves record listing categories for a domain.

    .PARAMETER DnsHealth
        Retrieves DNS health details for a domain.

    .PARAMETER TroubleshootingAllowed
        Retrieves whether troubleshooting is currently allowed for a domain.

    .PARAMETER Dependencies
        Retrieves dependency data for a domain.

    .PARAMETER ExportRecords
        Exports domain records in the requested format.

    .PARAMETER DomainName
        The domain name used by domain-specific parameter sets.

    .PARAMETER DependencyKind
        The dependency kind value used by the admin endpoint. The HAR showed values 1, 2, and 4.

    .PARAMETER OverrideSkip
        Controls the overrideSkip flag for DNS health requests.

    .PARAMETER CanRefreshCache
        Controls the canRefreshCache flag for DNS health and troubleshooting requests.

    .PARAMETER DnsHealthCheckScenario
        The DNS health scenario value sent to the admin endpoint.

    .PARAMETER Format
        The export format to request.

    .PARAMETER DomainType
        The domain type sent to the export endpoint.

    .PARAMETER DomainCapabilities
        The domain capabilities flag sent to the export endpoint.

    .PARAMETER Mode
        The export mode sent to the export endpoint.

    .PARAMETER Force
        Bypasses the cache and forces a fresh retrieval.

    .PARAMETER Raw
        Returns the raw domain payload for the selected parameter set.

    .PARAMETER RawJson
        Returns the raw domain payload serialized as formatted JSON.

    .EXAMPLE
        Get-M365AdminDomain

        Retrieves the current domain list.

    .EXAMPLE
        Get-M365AdminDomain -Records -DomainName contoso.com

        Retrieves DNS records for contoso.com.

    .EXAMPLE
        Get-M365AdminDomain -Dependencies -DomainName contoso.com -DependencyKind 1

        Retrieves domain dependency data when available. If the tenant-specific endpoint does not
        return usable data, the cmdlet returns a standardized unavailable result object.

    .OUTPUTS
        Object
        Returns the selected domain payload.
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param (
        [Parameter(ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'Customization')]
        [switch]$Customization,

        [Parameter(ParameterSetName = 'BuyModel')]
        [switch]$BuyModel,

        [Parameter(ParameterSetName = 'RegistrarsHelpInfo')]
        [switch]$RegistrarsHelpInfo,

        [Parameter(ParameterSetName = 'Records')]
        [switch]$Records,

        [Parameter(ParameterSetName = 'ListingCategory')]
        [switch]$ListingCategory,

        [Parameter(ParameterSetName = 'DnsHealth')]
        [switch]$DnsHealth,

        [Parameter(ParameterSetName = 'TroubleshootingAllowed')]
        [switch]$TroubleshootingAllowed,

        [Parameter(ParameterSetName = 'Dependencies')]
        [switch]$Dependencies,

        [Parameter(ParameterSetName = 'ExportRecords')]
        [switch]$ExportRecords,

        [Parameter(Mandatory, ParameterSetName = 'Records')]
        [Parameter(Mandatory, ParameterSetName = 'ListingCategory')]
        [Parameter(Mandatory, ParameterSetName = 'DnsHealth')]
        [Parameter(Mandatory, ParameterSetName = 'TroubleshootingAllowed')]
        [Parameter(Mandatory, ParameterSetName = 'Dependencies')]
        [Parameter(Mandatory, ParameterSetName = 'ExportRecords')]
        [string]$DomainName,

        [Parameter(ParameterSetName = 'Dependencies')]
        [ValidateSet(1, 2, 4)]
        [int]$DependencyKind = 1,

        [Parameter(ParameterSetName = 'DnsHealth')]
        [bool]$OverrideSkip = $true,

        [Parameter(ParameterSetName = 'DnsHealth')]
        [Parameter(ParameterSetName = 'TroubleshootingAllowed')]
        [bool]$CanRefreshCache,

        [Parameter(ParameterSetName = 'DnsHealth')]
        [int]$DnsHealthCheckScenario = 2,

        [Parameter(ParameterSetName = 'ExportRecords')]
        [ValidateSet('csv', 'zone')]
        [string]$Format = 'csv',

        [Parameter(ParameterSetName = 'ExportRecords')]
        [string]$DomainType = 'Partial',

        [Parameter(ParameterSetName = 'ExportRecords')]
        [int]$DomainCapabilities = 1,

        [Parameter(ParameterSetName = 'ExportRecords')]
        [int]$Mode = 0,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$RawJson
    )

    process {
        $escapedDomainName = if ($PSBoundParameters.ContainsKey('DomainName')) { [uri]::EscapeDataString($DomainName) } else { $null }
        $path = switch ($PSCmdlet.ParameterSetName) {
            'Customization' { '/admin/api/DomainList/Customization' }
            'BuyModel' { '/admin/api/Domains/GetDomainBuyModel' }
            'RegistrarsHelpInfo' { '/admin/api/Domains/GetRegistrarsHelpInfo' }
            'Records' { '/admin/api/Domains/Records?domainName={0}' -f $escapedDomainName }
            'ListingCategory' { '/admin/api/Domains/Records/ListingCategory?domainName={0}' -f $escapedDomainName }
            'DnsHealth' {
                $effectiveCanRefreshCache = if ($PSBoundParameters.ContainsKey('CanRefreshCache')) { $CanRefreshCache } else { $true }
                '/admin/api/Domains/CheckDnsHealth?domainName={0}&overrideSkip={1}&canRefreshCache={2}&dnsHealthCheckScenario={3}' -f $escapedDomainName, $OverrideSkip.ToString().ToLowerInvariant(), $effectiveCanRefreshCache.ToString().ToLowerInvariant(), $DnsHealthCheckScenario
            }
            'TroubleshootingAllowed' {
                $effectiveCanRefreshCache = if ($PSBoundParameters.ContainsKey('CanRefreshCache')) { $CanRefreshCache } else { $false }
                '/admin/api/Domains/CheckIsTroubleshootingAllowed?domainName={0}&canRefreshCache={1}' -f $escapedDomainName, $effectiveCanRefreshCache.ToString().ToLowerInvariant()
            }
            'Dependencies' { '/admin/api/Domains/Dependencies?domainName={0}&kind={1}' -f $escapedDomainName, $DependencyKind }
            'ExportRecords' {
                '/admin/api/Domains/Records/Export?format={0}&domainType={1}&domainName={2}&domainCapabilities={3}&mode={4}' -f $Format, [uri]::EscapeDataString($DomainType), $escapedDomainName, $DomainCapabilities, $Mode
            }
            default { '/admin/api/Domains/List' }
        }

        $cacheKey = 'M365AdminDomain:{0}:{1}' -f $PSCmdlet.ParameterSetName, ($path -replace '[^A-Za-z0-9:/?=&-]', '_')

        if ($PSCmdlet.ParameterSetName -eq 'Dependencies') {
            try {
                $result = Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Force:$Force
            }
            catch {
                if ($_.Exception.Message -match '400' -or $_.Exception.Message -match 'Bad Request') {
                    $result = New-M365AdminUnavailableResult -Name 'Dependencies' -Description 'The domain dependency endpoint did not return data for this domain in the current tenant.' -Reason 'TenantSpecific' -ErrorMessage $_.Exception.Message
                    $result | Add-Member -NotePropertyName DomainName -NotePropertyValue $DomainName
                    $result | Add-Member -NotePropertyName DependencyKind -NotePropertyValue $DependencyKind
                    return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
                }

                throw
            }

            return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
        }

        $result = Get-M365AdminPortalData -Path $path -CacheKey $cacheKey -Force:$Force
        return Resolve-M365AdminOutput -DefaultValue $result -Raw:$Raw -RawJson:$RawJson
    }
}