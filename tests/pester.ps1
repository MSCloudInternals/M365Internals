param (
	$TestGeneral = $true,
	
	$TestFunctions = $true,
	
	[ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
	[Alias('Show')]
	$Output = "None",
	
	$Include = "*",
	
	$Exclude = "",

	[switch]$PassThru
)

Write-Host "Starting Tests"

Write-Host "Importing Module"

$global:testroot = $PSScriptRoot
$global:__pester_data = @{ }
$repositoryRoot = Join-Path $PSScriptRoot '..'
$moduleRoot = Join-Path $repositoryRoot 'M365Internals'
$testResultsPath = Join-Path $repositoryRoot 'TestResults'
$generalTestPath = Join-Path $PSScriptRoot 'general'
$functionTestPath = Join-Path $PSScriptRoot 'functions'

Remove-Module M365Internals -ErrorAction Ignore
Import-Module (Join-Path $moduleRoot 'M365Internals.psd1')
Import-Module (Join-Path $moduleRoot 'M365Internals.psm1') -Force

# Need to import explicitly so we can use the configuration class
Import-Module Pester

Write-Host  "Creating test result folder"
$null = New-Item -Path $testResultsPath -ItemType Directory -Force

$totalFailed = 0
$totalRun = 0
$suiteResults = New-Object System.Collections.Generic.List[object]

$testresults = @()
$config = [PesterConfiguration]::Default
$config.TestResult.Enabled = $true

#region Run General Tests
if ($TestGeneral)
{
	Write-Host  "Modules imported, proceeding with general tests"
	foreach ($file in (Get-ChildItem $generalTestPath | Where-Object Name -like "*.Tests.ps1"))
	{
		if ($file.Name -notlike $Include) { continue }
		if ($file.Name -like $Exclude) { continue }

		Write-Host  "  Executing $($file.Name)"
		$config.TestResult.OutputPath = Join-Path $testResultsPath "TEST-$($file.BaseName).xml"
		$config.Run.Path = $file.FullName
		$config.Run.PassThru = $true
		$config.Output.Verbosity = $Output
    	$results = Invoke-Pester -Configuration $config
		foreach ($result in $results)
		{
			$totalRun += $result.TotalCount
			$totalFailed += $result.FailedCount
			$suiteResults.Add([pscustomobject]@{
				Category = 'General'
				FileName = $file.Name
				Path = $file.FullName
				TotalCount = $result.TotalCount
				PassedCount = $result.PassedCount
				FailedCount = $result.FailedCount
				SkippedCount = $result.SkippedCount
			})
			$result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
				$testresults += [pscustomobject]@{
					Block    = $_.Block
					Name	 = "It $($_.Name)"
					Result   = $_.Result
					Message  = $_.ErrorRecord.DisplayErrorMessage
				}
			}
		}
	}
}
#endregion Run General Tests

$global:__pester_data.ScriptAnalyzer | Out-Host

#region Test Commands
if ($TestFunctions)
{
	Write-Host "Proceeding with individual tests"
	foreach ($file in (Get-ChildItem $functionTestPath -Recurse -File | Where-Object Name -like "*Tests.ps1"))
	{
		if ($file.Name -notlike $Include) { continue }
		if ($file.Name -like $Exclude) { continue }
		
		Write-Host "  Executing $($file.Name)"
		$config.TestResult.OutputPath = Join-Path $testResultsPath "TEST-$($file.BaseName).xml"
		$config.Run.Path = $file.FullName
		$config.Run.PassThru = $true
		$config.Output.Verbosity = $Output
    	$results = Invoke-Pester -Configuration $config
		foreach ($result in $results)
		{
			$totalRun += $result.TotalCount
			$totalFailed += $result.FailedCount
			$suiteResults.Add([pscustomobject]@{
				Category = 'Function'
				FileName = $file.Name
				Path = $file.FullName
				TotalCount = $result.TotalCount
				PassedCount = $result.PassedCount
				FailedCount = $result.FailedCount
				SkippedCount = $result.SkippedCount
			})
			$result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
				$testresults += [pscustomobject]@{
					Block    = $_.Block
					Name	 = "It $($_.Name)"
					Result   = $_.Result
					Message  = $_.ErrorRecord.DisplayErrorMessage
				}
			}
		}
	}
}
#endregion Test Commands

$testresults | Sort-Object Describe, Context, Name, Result, Message | Format-List

$summary = [pscustomobject]@{
	RepositoryRoot = $repositoryRoot
	TestResultsPath = $testResultsPath
	TotalCount = $totalRun
	FailedCount = $totalFailed
	PassedCount = ($totalRun - $totalFailed)
	Suites = [object[]]$suiteResults.ToArray()
	ScriptAnalyzer = $global:__pester_data.ScriptAnalyzer
}

if ($totalFailed -eq 0) { Write-Host  "All $totalRun tests executed without a single failure!" }
else { Write-Host "$totalFailed tests out of $totalRun tests failed!" }

if ($totalFailed -gt 0)
{
	throw "$totalFailed / $totalRun tests failed!"
}

if ($PassThru)
{
	return $summary
}
