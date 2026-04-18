function ConvertTo-M365AdminResult {
    <#
    .SYNOPSIS
        Builds a stable default output object for admin-center leaf results.

    .DESCRIPTION
        Shapes raw admin-center payloads into a consistent object contract by adding stable
        metadata, preserving the original payload under RawData, and stamping both a generic
        and a specific PowerShell type name.

    .PARAMETER InputObject
        The raw admin-center payload to shape.

    .PARAMETER TypeName
        The specific PowerShell type name to add to the shaped result.

    .PARAMETER Category
        The functional category for the result, such as App settings or User settings.

    .PARAMETER ItemName
        The friendly leaf name represented by the payload.

    .PARAMETER Endpoint
        The backing admin-center endpoint path, when known.

    .PARAMETER AdditionalProperties
        Optional properties to add before the payload is merged into the shaped result.

    .EXAMPLE
        ConvertTo-M365AdminResult -InputObject $rawPayload -TypeName 'M365Admin.UserSetting.CurrentUser' -Category 'User settings' -ItemName 'CurrentUser' -Endpoint '/admin/api/users/currentUser'

        Wraps the raw payload in the standard typed result contract used by default output.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$TypeName,

        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$ItemName,

        [Parameter()]
        [string]$Endpoint,

        [Parameter()]
        [hashtable]$AdditionalProperties
    )

    process {
        if ($null -eq $InputObject) {
            $result = [pscustomobject]@{
                ItemName = $ItemName
                Category = $Category
                Endpoint = $Endpoint
                RawData  = $null
            }

            $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.GenericResult'
            return Add-M365TypeName -InputObject $result -TypeName $TypeName
        }

        if ($InputObject.PSObject.TypeNames -contains 'M365Admin.UnavailableResult') {
            return $InputObject
        }

        $properties = [ordered]@{
            ItemName = $ItemName
            Category = $Category
        }

        if (-not [string]::IsNullOrWhiteSpace($Endpoint)) {
            $properties.Endpoint = $Endpoint
        }

        if ($PSBoundParameters.ContainsKey('AdditionalProperties') -and $null -ne $AdditionalProperties) {
            foreach ($entry in @($AdditionalProperties.GetEnumerator())) {
                if (-not $properties.Contains($entry.Key)) {
                    $properties[$entry.Key] = $entry.Value
                }
            }
        }

        $mergedPayload = $false
        if ($InputObject -is [System.Collections.IDictionary]) {
            foreach ($entry in @($InputObject.GetEnumerator())) {
                $propertyName = if ($properties.Contains($entry.Key)) { '{0}Data' -f $entry.Key } else { $entry.Key }
                $properties[$propertyName] = $entry.Value
            }

            $mergedPayload = $true
        }
        else {
            $noteProperties = @($InputObject.PSObject.Properties | Where-Object MemberType -eq 'NoteProperty')
            if (($InputObject -is [pscustomobject]) -or ($noteProperties.Count -gt 0)) {
                foreach ($property in @($InputObject.PSObject.Properties | Where-Object MemberType -in @('NoteProperty', 'Property'))) {
                    $propertyName = if ($properties.Contains($property.Name)) { '{0}Data' -f $property.Name } else { $property.Name }
                    $properties[$propertyName] = $property.Value
                }

                $mergedPayload = $true
            }
        }

        if (-not $mergedPayload) {
            if (($InputObject -is [System.Collections.IEnumerable]) -and -not ($InputObject -is [string])) {
                $properties.Items = @($InputObject)
            }
            else {
                $properties.Value = $InputObject
            }
        }

        $properties.RawData = $InputObject

        $result = [pscustomobject]$properties
        $result = Add-M365TypeName -InputObject $result -TypeName 'M365Admin.GenericResult'
        return Add-M365TypeName -InputObject $result -TypeName $TypeName
    }
}