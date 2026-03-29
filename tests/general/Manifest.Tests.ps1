Describe "Validating the module manifest" {
	$moduleRoot = (Resolve-Path (Join-Path (Join-Path $global:testroot '..') 'M365Internals')).Path
	$manifest = Import-PowerShellDataFile (Join-Path $moduleRoot 'M365Internals.psd1')
	Context "Basic resources validation" {
		It "Exports all functions in the public folder" -TestCases @{ moduleRoot = $moduleRoot; manifest = $manifest } {
			$publicFunctionPath = Join-Path $moduleRoot 'functions'
			$files = Get-ChildItem $publicFunctionPath -Recurse -File | Where-Object Name -like "*.ps1"
			$fileBaseNames = @($files | ForEach-Object BaseName)
			$exportedFunctions = @($manifest.FunctionsToExport)
			if ($fileBaseNames.Count -eq 0 -and $exportedFunctions.Count -eq 0) {
				$functions = @()
			} else {
				$functions = (Compare-Object -ReferenceObject $fileBaseNames -DifferenceObject $exportedFunctions | Where-Object SideIndicator -Like '<=').InputObject
			}
			$functions | Should -BeNullOrEmpty
		}
		It "Exports no function that isn't also present in the public folder" -TestCases @{ moduleRoot = $moduleRoot; manifest = $manifest } {
			$publicFunctionPath = Join-Path $moduleRoot 'functions'
			$files = Get-ChildItem $publicFunctionPath -Recurse -File | Where-Object Name -like "*.ps1"
			$fileBaseNames = @($files | ForEach-Object BaseName)
			$exportedFunctions = @($manifest.FunctionsToExport)
			if ($fileBaseNames.Count -eq 0 -and $exportedFunctions.Count -eq 0) {
				$functions = @()
			} else {
				$functions = (Compare-Object -ReferenceObject $fileBaseNames -DifferenceObject $exportedFunctions | Where-Object SideIndicator -Like '=>').InputObject
			}
			$functions | Should -BeNullOrEmpty
		}
		
		It "Exports none of its internal functions" -TestCases @{ moduleRoot = $moduleRoot; manifest = $manifest } {
			$internalFunctionPath = Join-Path (Join-Path $moduleRoot 'internal') 'functions'
			$files = Get-ChildItem $internalFunctionPath -Recurse -File -Filter "*.ps1"
			$files | Where-Object BaseName -In $manifest.FunctionsToExport | Should -BeNullOrEmpty
		}
	}
	
	Context "Individual file validation" {
		It "The root module file exists" -TestCases @{ moduleRoot = $moduleRoot; manifest = $manifest } {
			Test-Path (Join-Path $moduleRoot $manifest.RootModule) | Should -Be $true
		}
		
		foreach ($format in $manifest.FormatsToProcess)
		{
			It "The file $format should exist" -TestCases @{ moduleRoot = $moduleRoot; format = $format } {
				Test-Path (Join-Path $moduleRoot $format) | Should -Be $true
			}
		}
		
		foreach ($type in $manifest.TypesToProcess)
		{
			It "The file $type should exist" -TestCases @{ moduleRoot = $moduleRoot; type = $type } {
				Test-Path (Join-Path $moduleRoot $type) | Should -Be $true
			}
		}
		
		foreach ($assembly in $manifest.RequiredAssemblies)
		{
            if ($assembly -like "*.dll") {
                It "The file $assembly should exist" -TestCases @{ moduleRoot = $moduleRoot; assembly = $assembly } {
                    Test-Path (Join-Path $moduleRoot $assembly) | Should -Be $true
                }
            }
            else {
                It "The file $assembly should load from the GAC" -TestCases @{ moduleRoot = $moduleRoot; assembly = $assembly } {
                    { Add-Type -AssemblyName $assembly } | Should -Not -Throw
                }
            }
        }
		
		foreach ($tag in $manifest.PrivateData.PSData.Tags)
		{
			It "Tags should have no spaces in name" -TestCases @{ tag = $tag } {
				$tag -match " " | Should -Be $false
			}
		}
	}
}
