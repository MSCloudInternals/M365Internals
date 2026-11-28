# Resolve the public connection parameter type before web cmdlet autoloading.
if (-not ('Microsoft.PowerShell.Commands.WebRequestSession' -as [type])) {
    Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
}

foreach ($file in Get-ChildItem -Path "$PSScriptRoot/internal/functions" -Filter *.ps1 -Recurse) {
    . $file.FullName
}

foreach ($file in Get-ChildItem -Path "$PSScriptRoot/functions" -Filter *.ps1 -Recurse) {
    . $file.FullName
}

foreach ($file in Get-ChildItem -Path "$PSScriptRoot/internal/scripts" -Filter *.ps1 -Recurse) {
    . $file.FullName
}