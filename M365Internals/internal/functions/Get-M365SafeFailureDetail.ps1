function Get-M365SafeFailureDetail {
    <#
    .SYNOPSIS
        Formats non-sensitive details from a failed portal or authentication operation.

    .DESCRIPTION
        Retains only recognized HTTP status, service code, or transport category. It never
        returns the original exception text, headers, request URL, or response body.

    .PARAMETER ErrorRecord
        The error record from a transport or provider operation.

    .PARAMETER Message
        An existing provider error message to summarize without returning its text.

    .PARAMETER HttpStatusCode
        A known HTTP status code.

    .PARAMETER ServiceCode
        A numeric identity-service error code.

    .EXAMPLE
        Get-M365SafeFailureDetail -ErrorRecord $_

        Produces a safe detail for a portal error message.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [string]$Message,

        [nullable[int]]$HttpStatusCode,

        [string]$ServiceCode
    )

    if ($PSBoundParameters.ContainsKey('ServiceCode')) {
        if ($ServiceCode -match '\A-?[0-9]{1,8}\z') {
            return "Service error code: $ServiceCode."
        }
        return 'No recognized service error code was returned.'
    }

    $exception = $null
    if ($ErrorRecord) {
        $exception = $ErrorRecord.Exception
        $Message = $exception.Message

        if ($exception -is [Microsoft.PowerShell.Commands.HttpResponseException] -and $exception.Response) {
            $HttpStatusCode = [int]$exception.Response.StatusCode
        }
        elseif ($exception -is [System.Net.Http.HttpRequestException] -and $exception.StatusCode) {
            $HttpStatusCode = [int]$exception.StatusCode
        }
    }

    if (-not $HttpStatusCode) {
        if ($Message -match '(?i)\b(?:HTTP(?:\s+error)?\s+|status code(?: does not indicate success)?\s*:\s*)(?<Status>[1-5][0-9]{2})\b') {
            $HttpStatusCode = [int]$Matches.Status
        }
        elseif ($Message -eq 'Unauthorized') {
            $HttpStatusCode = 401
        }
        elseif ($Message -eq 'Forbidden') {
            $HttpStatusCode = 403
        }
    }

    if ($HttpStatusCode -ge 100 -and $HttpStatusCode -le 599) {
        $statusName = [System.Net.HttpStatusCode][int]$HttpStatusCode
        return "HTTP $HttpStatusCode ($statusName)."
    }
    if ($exception -is [System.TimeoutException] -or $exception -is [System.OperationCanceledException]) {
        return 'The operation timed out or was canceled.'
    }
    if ($exception -is [System.UriFormatException]) {
        return 'The request URL was invalid.'
    }

    return 'No HTTP status was available.'
}
