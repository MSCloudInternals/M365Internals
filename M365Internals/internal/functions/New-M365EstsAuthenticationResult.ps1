function New-M365EstsAuthenticationResult {
    <#
    .SYNOPSIS
        Creates a normalized ESTS authentication result object.

    .DESCRIPTION
        Packages the authenticated ESTS web session and the best ESTS cookie value into a single
        object that downstream portal bootstrap helpers can consume consistently.

    .PARAMETER WebSession
        The authenticated ESTS web session.

    .PARAMETER EstsAuthCookieValue
        The ESTS authentication cookie value captured from the session.

    .EXAMPLE
        New-M365EstsAuthenticationResult -WebSession $session -EstsAuthCookieValue $cookie

        Returns a normalized ESTS authentication result for later portal bootstrap steps.

    .OUTPUTS
        PSCustomObject
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory result object only.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [string]$EstsAuthCookieValue
    )

    [pscustomobject]@{
        EstsAuthCookieValue = $EstsAuthCookieValue
        WebSession          = $WebSession
    }
}
