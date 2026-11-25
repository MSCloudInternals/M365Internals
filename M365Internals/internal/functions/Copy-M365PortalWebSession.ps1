function Copy-M365PortalWebSession {
    <#
    .SYNOPSIS
        Creates an independent working copy of a portal web session.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.PowerShell.Commands.WebRequestSession])]
    param (
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
    )

    $sourceCookies = $WebSession.Cookies
    if ($sourceCookies.PSObject.Methods['GetAllCookies']) {
        $cookies = @($sourceCookies.GetAllCookies())
    }
    else {
        $cookies = @(Get-M365LegacyCookieCollection -CookieContainer $sourceCookies)
    }

    Add-Type -AssemblyName System.Runtime.Serialization
    $serializer = [System.Runtime.Serialization.DataContractSerializer]::new([System.Net.Cookie])
    $cookieCopy = [System.Net.CookieContainer]::new($sourceCookies.Capacity, $sourceCookies.PerDomainCapacity, $sourceCookies.MaxCookieSize)
    foreach ($cookie in $cookies) {
        $stream = [System.IO.MemoryStream]::new()
        try {
            $serializer.WriteObject($stream, $cookie)
            $stream.Position = 0
            $cookieCopy.Add([System.Net.Cookie]$serializer.ReadObject($stream))
        }
        finally {
            $stream.Dispose()
        }
    }

    $copy = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    $copy.Cookies = $cookieCopy
    foreach ($propertyName in @('Credentials', 'Proxy', 'UseDefaultCredentials', 'UserAgent', 'MaximumRedirection', 'MaximumRetryCount', 'RetryIntervalInSeconds')) {
        if ($WebSession.PSObject.Properties[$propertyName] -and $copy.PSObject.Properties[$propertyName]) {
            $copy.$propertyName = $WebSession.$propertyName
        }
    }
    foreach ($header in $WebSession.Headers.GetEnumerator()) {
        $copy.Headers[$header.Key] = $header.Value
    }
    if ($WebSession.Certificates) {
        $copy.Certificates = [System.Security.Cryptography.X509Certificates.X509CertificateCollection]::new()
        $copy.Certificates.AddRange($WebSession.Certificates)
    }
    foreach ($property in @($WebSession.PSObject.Properties | Where-Object MemberType -eq NoteProperty)) {
        $copy | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force
    }

    return $copy
}

function Get-M365LegacyCookieCollection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Net.CookieContainer]$CookieContainer
    )

    # Windows PowerShell's .NET Framework has no public all-cookie enumerator.
    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $domainField = $CookieContainer.GetType().GetField('m_domainTable', $flags)
    if (-not $domainField) {
        throw 'Cannot safely copy the active web session on this runtime; use a different WebSession for reconnecting.'
    }
    foreach ($pathList in $domainField.GetValue($CookieContainer).Values) {
        $listField = $pathList.GetType().GetField('m_list', $flags)
        if (-not $listField) {
            throw 'Cannot safely copy the active web session on this runtime; use a different WebSession for reconnecting.'
        }
        foreach ($collection in $listField.GetValue($pathList).Values) {
            foreach ($cookie in $collection) { $cookie }
        }
    }
}
