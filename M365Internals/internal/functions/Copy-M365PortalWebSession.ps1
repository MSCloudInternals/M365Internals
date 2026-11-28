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
    $cookies = $sourceCookies.GetAllCookies()

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
