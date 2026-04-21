
#requires -Module @{ ModuleName = "Pester"; ModuleVersion = "5.6.0" }
Add-BuildTask Test-PowerShell @{
    Inputs  = {
        Get-ChildItem $ModuleOutputPath -Recurse -File
        $Tests = Join-Path $BuildRoot [Tt]ests | Resolve-Path
        Get-ChildItem $Tests -Recurse -File -Filter *.tests.ps1
    }
    Outputs = {
        if ($Clean) {
            $BuildRoot # guaranteed to be old
        } else {
            Join-Path $ModuleTestResultsRoot "results.xml"
        }
    }
    Jobs    = {
        $script:OldModulePath = $Env:PSModulePath
    }, {

        # For PowerShell Modules with classes to work in tests:
        # 1. The $OutputPath directory must be first on Env:PSModulePath
        # 2. The $ModuleName directory must be in $OutputPath directory
        # 3. The $ModuleName.psd1 file must be in the $ModuleName directory
        if (Test-Path $script:ManifestPath) {
            $Env:PSModulePath = @($script:OutputPath) + @($Env:PSModulePath -split [IO.Path]::PathSeparator -ne $script:OutputPath) -join ([IO.Path]::PathSeparator)
            Write-Output (@(
                    "Set PSModulePath:"
                    $Env:PSModulePath
                    ""
                    "Module Under Test at: $ManifestPath"
                    Get-Module $ModuleName -ListAvailable | Format-Table Version, Path | Out-String
                    ""
                    "Module Imported:"
                    Get-Module $ModuleName -ErrorAction SilentlyContinue | Format-Table Version, Path | Out-String
                ) -join "`n")
        }

        # But we don't need all that to run PowerShell tests ...
        $Configuration = @{
            Run          = @{
                Path     = "$BuildRoot/[Tt]ests"
                Passthru = $true
            }
            Filter       = $PesterFilter
            TestResult   = @{
                Enabled    = $true
                OutputPath = Join-Path $ModuleTestResultsRoot "results.xml"
            }
            Debug        = @{
                ShowNavigationMarkers = $Host.Name -match "Visual Studio Code"
            }
            Output       = @{
                Verbosity  = if ($VerbosePreference -eq "Continue") { "Detailed" } else { "Normal" }
                RenderMode = "Ansi"
                CIFormat   = $BuildSystem
            }
            CodeCoverage = @{
                Enabled               = !$SkipCoverage
                Path                  = Get-Item $ModuleOutputPath\*.psm1, $ModuleOutputPath\*.ps1
                OutputPath            = Join-Path $ModuleTestResultsRoot "coverage.xml"
                CoveragePercentTarget = $CodeCoveragePercentTarget * 100
                UseBreakpoints        = $false
            }
        }

        $results = Invoke-Pester -Configuration (New-PesterConfiguration $Configuration)

        if ($null -eq $results -or $results.FailedCount -gt 0 -or $results.FailedContainersCount -gt 0) {
            throw "##[error]Failed Pester tests."
        }

        if (!$SkipCoverage -and $Script:PassingCodeCoverage -gt 0.00) {
            $ExecutedPercent = if ($results.CodeCoverage.NumberOfCommandsExecuted) {
                $results.CodeCoverage.NumberOfCommandsExecuted / $results.CodeCoverage.NumberOfCommandsAnalyzed
            } else {
                $results.CodeCoverage.CommandsExecutedCount / $results.CodeCoverage.CommandsAnalyzedCount
            }
            if ($ExecutedPercent -lt $CodeCoveragePercentTarget) {
                throw ("##[error]Failed {0:P} code coverage is below {1:P}." -f $ExecutedPercent, $CodeCoveragePercentTarget)
            }
        }

    }, {
        Write-Verbose "Restoring PSModulePath to $OldModulePath" -Verbose
        $Env:PSModulePath = $script:OldModulePath
    }
}