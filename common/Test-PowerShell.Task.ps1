
Add-BuildTask Test-PowerShell @{
    Inputs  = {
        if ($ModuleOutputRoot) {
            Get-ChildItem $ModuleOutputRoot -Recurse -File
        }
        if ($Tests = Join-Path $BuildRoot [Tt]ests | Resolve-Path -ErrorAction Ignore) {
            Get-ChildItem $Tests -Recurse -File -Filter *.tests.ps1
        }
    }
    Outputs = {
        if ($Clean) {
            $BuildRoot # guaranteed to be old
        } else {
            Join-Path ($script:ModuleTestResultsRoot ?? $script:TestResultsRoot) "results.xml"
        }
    }
    Jobs    = {
        $script:OldModulePath = $Env:PSModulePath
    }, {
        # We can't use `requires` because installing dependencies is one of the build steps...
        Import-Module Pester -MinimumVersion 5.6 -ErrorAction Stop

        # For PowerShell Modules with classes to work in tests:
        # 1. The $OutputRoot directory must be first on Env:PSModulePath
        # 2. The $ModuleName directory must be in $OutputRoot directory
        # 3. The $ModuleName.psd1 file must be in the $ModuleName directory
        if (Test-Path $script:ManifestPath) {
            $Env:PSModulePath = @($script:OutputRoot) + @($Env:PSModulePath -split [IO.Path]::PathSeparator -ne $script:OutputRoot) -join ([IO.Path]::PathSeparator)
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

        # Wvoid depending on the PowerShell/base variables (but respect them if they are set)
        $local:ModuleTestResultsRoot = $script:ModuleTestResultsRoot ?? $script:TestResultsRoot
        $local:CoverageRoot = $script:ModuleOutputRoot ?? $script:OutputRoot
        $local:SkipCoverage = $script:SkipCoverage -or -not $script:ModuleOutputRoot

        # But we don't need all that to run PowerShell tests ...
        $Configuration = @{
            Run          = @{
                Path     = "$BuildRoot/[Tt]ests"
                Passthru = $true
            }
            Filter       = $PesterFilter
            TestResult   = @{
                Enabled    = $true
                OutputPath = Join-Path $local:ModuleTestResultsRoot "results.xml"
            }
            Debug        = @{
                ShowNavigationMarkers = $Host.Name -match "Visual Studio Code"
            }
            Output       = @{
                Verbosity  = if ($VerbosePreference -eq "Continue") { "Detailed" } else { "Normal" }
                RenderMode = "Ansi"
                CIFormat   = $BuildSystem -ne "Earthly" ? $BuildSystem : "Auto"
            }
            CodeCoverage = @{
                Enabled               = !$SkipCoverage
                Path                  = Get-Item $local:CoverageRoot\*.psm1, $local:CoverageRoot\*.ps1
                OutputPath            = Join-Path $local:ModuleTestResultsRoot "coverage.xml"
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