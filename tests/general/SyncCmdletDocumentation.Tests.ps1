Describe "Validating cmdlet documentation sync automation" {
	BeforeAll {
		$repoRoot = (Resolve-Path (Join-Path $global:testroot '..')).Path
		$syncScriptPath = Join-Path (Join-Path $repoRoot 'build') 'Sync-CmdletDocumentation.ps1'
		$tempBasePath = [System.IO.Path]::GetTempPath()
		$tempRoot = Join-Path $tempBasePath ("M365Internals-SyncCmdletDocumentation-" + [Guid]::NewGuid().Guid)
		$copyItems = @(
			'M365Internals',
			'M365Ray',
			'M365Ray Firefox',
			'README.md'
		)
		$targets = @(
			'README.md',
			'M365Internals/README.md',
			'M365Internals/M365Internals.psd1',
			'M365Ray/CmdletApiMapping.json',
			'M365Ray Firefox/CmdletApiMapping.json'
		)

		$null = New-Item -Path $tempRoot -ItemType Directory -Force
		foreach ($item in $copyItems) {
			Copy-Item -Path (Join-Path $repoRoot $item) -Destination (Join-Path $tempRoot $item) -Recurse -Force
		}

		$fileStates = foreach ($target in $targets) {
			[pscustomobject]@{
				Target = $target
				BeforeHash = (Get-FileHash -Path (Join-Path $tempRoot $target) -Algorithm SHA256).Hash
				AfterHash = $null
			}
		}

		$syncError = $null
		try {
			& $syncScriptPath -RepositoryRoot $tempRoot
		}
		catch {
			$syncError = $_
		}

		foreach ($state in $fileStates) {
			$state.AfterHash = (Get-FileHash -Path (Join-Path $tempRoot $state.Target) -Algorithm SHA256).Hash
		}
	}

	AfterAll {
		if ($tempRoot -and (Test-Path $tempRoot)) {
			Remove-Item -Path $tempRoot -Recurse -Force
		}
	}

	It "Runs successfully against a synchronized repo snapshot" {
		if ($syncError) {
			$details = @(
				$syncError.Exception.Message
				$syncError.ScriptStackTrace
			) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

			throw ($details -join [Environment]::NewLine)
		}

		$syncError | Should -BeNullOrEmpty
	}

	It "Leaves <Target> byte-for-byte unchanged when no sync is needed" -ForEach $fileStates {
		$AfterHash | Should -Be $BeforeHash
	}
}