<#
    .Synopsis
        Wrap Invoke-Pester for Invoke-Build
    .Description
        Wrap Invoke-Pester to determine the Pester version from the required module
        There is a LOT of code here because we are:
        - Handling both Pester 4 and Pester 5, and generating appropriate options for both
        - Getting code coverage requirements, and failing the build (still needed for Pester 4)
    .Notes
        Later, when we're ready to remove Pester 4 support, we should refactor to:
        1. Depend on an options file
        2. Generate or change the options file in TestModule
        3. Have default options file here, in case of missing options file
#>

Add-BuildTask PSModuleTest @{
    If      = Get-ChildItem ($PSModuleTestPath ?? "$BuildRoot${/}[Tt]ests") | Get-ChildItem -Recurse -File -Filter *.?ests.ps1
    Inputs  = {
        Get-ChildItem $PSModuleOutputPath -Recurse -File
        Get-ChildItem ($PSModuleTestPath ?? "$BuildRoot${/}[Tt]ests") | Get-ChildItem -Recurse -File -Filter *.?ests.ps1
    }
    Outputs = {
        if ($Clean) {
            $BuildRoot # guaranteed to be old
        } else {
            "$TestResultsRoot${/}TestResults.xml"
        }
    }
    Jobs    = "PSModuleImport", {
            $PSModuleTestPath ??= "$BuildRoot${/}[Tt]ests"
            # The output path, by convention: TestResults.xml in your output folder
            $TestResultOutputPath ??= Join-Path $TestResultsRoot "TestResult.xml"

            $PesterFilter ??= if ($BuildSystem -ne "None") { @{ "ExcludeTag" = 'NoCI' } }


        $Version = $GitVersion.$PSModuleName.MajorMinorPatch

        # Write-Information "Build-Module -SourcePath $PSModuleSourcePath -Destination $PSModuleOutputPath -SemVer $SemVer"
        # $Module = Build-Module -SourcePath $PSModuleSourcePath -Destination $PSModuleOutputPath -SemVer $SemVer -Verbose:$Verbose -Debug:$Debug -Passthru

        # For PowerShell Modules with classes to work in tests:
        # 1. The $OutputRoot directory must be first on Env:PSModulePath
        # 2. The $PSModuleName directory must be in $OutputRoot directory
        # 3. The $PSModuleName.psd1 file must be in the $PSModuleName directory
        if (-not ((Test-Path "$OutputRoot${/}$PSModuleName${/}$PSModuleName.psd1", "$OutputRoot${/}$PSModuleName${/}$Version${/}$PSModuleName.psd1") -contains $true)) {
            throw "Cannot test module if it's not in $OutputRoot${/}$PSModuleName"
        } else {
            $TestModulePath = @($OutputRoot) + @($Env:PSModulePath -split [IO.Path]::PathSeparator -ne $OutputRoot) -join [IO.Path]::PathSeparator
            $Env:PSModulePath, $OldModulePath = $TestModulePath, $Env:PSModulePath
            try {
                $PSModuleManifestPath = Get-ChildItem $PSModuleOutputPath -Filter "$PSModuleName.psm1" -Recurse -ErrorAction Ignore
                Write-Output (@(
                        "Set PSModulePath:"
                        $Env:PSModulePath
                        ""
                        "Module Under Test at: $PSModuleManifestPath"
                        Get-Module $PSModuleName -ListAvailable | Format-Table Version, Path | Out-String
                        ""
                        "Module Imported:"
                        Get-Module $PSModuleName -ErrorAction SilentlyContinue | Format-Table Version, Path | Out-String
                    ) -join "`n")


                if ($Script:RequiredCodeCoverage -gt 0.00) {
                    $CodeCoveragePath = $PSModuleManifestPath
                    $CodeCoverageOutputPath = "$TestResultsRoot${/}coverage.xml"
                    $CodeCoveragePercentTarget = $RequiredCodeCoverage
                }

                # The version of Pester to use (by default, reads *.requires.psd1 and supports 4.x or 5.x)
                if (!$PesterVersion) {
                    $PesterVersion = Get-Item "$Script:BuildRoot${/}*.requires.psd1", "$PSScriptRoot${/}*.requires.psd1" -ErrorAction SilentlyContinue |
                        Select-Object -First 1 |
                        Import-Metadata |
                        ForEach-Object { $_.Pester -Split "[[,]" } |
                        Where-Object { $_ -as [Version] } |
                        Select-Object -First 1
                }

                Write-Verbose "Using Pester v$PesterVersion" -Verbose

                # Force reimporting Pester
                Get-Module Pester -All | Remove-Module -Force

                $PesterModule = @{
                    Name           = "Pester"
                    MinimumVersion = $PesterVersion
                }

                # For unspecified version of Pester, assume 5.x
                if ([Version]"5.0" -le $PesterVersion -or -not $PesterVersion) {
                    $PesterModule["MinimumVersion"] = $PesterVersion ?? "5.3.0"

                    # Frankly, the Pester 5 options interface is a bit ridiculous, and we should use an options file
                    # But I'm not going to remove this until all my modules upgrade from Pester 4
                    $Configuration = @{
                        Run        = @{
                            Path     = $PSModuleTestPath
                            Passthru = $true
                        }
                        Filter     = $PesterFilter
                        TestResult = @{
                            Enabled    = $true
                            OutputPath = $TestResultOutputPath
                        }
                        Debug      = @{
                            ShowNavigationMarkers = $Host.Name -match "Visual Studio Code"
                        }
                    }
                    if ($Script:RequiredCodeCoverage -gt 0.00) {
                        $Configuration['CodeCoverage'] = @{
                            Enabled               = $true
                            Path                  = $CodeCoveragePath
                            OutputPath            = $CodeCoverageOutputPath
                            CoveragePercentTarget = $CodeCoveragePercentTarget * 100
                            UseBreakpoints        = $false
                        }
                    }
                    $PesterOptions = @{
                        Config = New-PesterConfiguration $Configuration
                    }

                    if ($Script:RequiredCodeCoverage -gt 0.00) {
                        # Work around bug in CodeCoverage Config
                        $PesterOptions.Config.CodeCoverage.CoveragePercentTarget = $CodeCoveragePercentTarget * 100
                    }
                    # Work around bug in output format. Valid values are "AzureDevOps", "None", "Auto", "GithubActions"
                    $PesterOptions.Config.Output.CIFormat = $BuildSystem -ne 'Earthly' ? $BuildSystem : 'Auto'
                } else {
                    $PesterModule["MaximumVersion"] = "4.99.99"

                    $PesterOptions = @{
                        Path         = $PSModuleTestPath
                        OutputFile   = $TestResultOutputPath
                        OutputFormat = 'NUnitXml'
                        PassThru     = $true
                        Show         = 'Failed', 'Summary', 'Header', 'All'
                        Tag          = @($PesterFilter.Tag)
                        ExcludeTag   = @($PesterFilter.ExcludeTags)
                    }
                    if ($Script:RequiredCodeCoverage -gt 0.00) {
                        $PesterOptions['CodeCoverage'] = $CodeCoveragePath
                        $PesterOptions['CodeCoverageOutputFile'] = $CodeCoverageOutputPath
                    }
                }

                Import-Module @PesterModule
                $results = Invoke-Pester @PesterOptions

                if ($null -eq $results -or $results.FailedCount -gt 0 -or $results.FailedContainersCount -gt 0) {
                    throw "##[error]Failed Pester tests."
                }

                if ($Script:RequiredCodeCoverage -gt 0.00) {
                    $ExecutedPercent = if ($results.CodeCoverage.NumberOfCommandsExecuted) {
                        $results.CodeCoverage.NumberOfCommandsExecuted / $results.CodeCoverage.NumberOfCommandsAnalyzed
                    } else {
                        $results.CodeCoverage.CommandsExecutedCount / $results.CodeCoverage.CommandsAnalyzedCount
                    }
                    if ($ExecutedPercent -lt $CodeCoveragePercentTarget) {
                        throw ("##[error]Failed {0:P} code coverage is below {1:P}." -f $ExecutedPercent, $CodeCoveragePercentTarget)
                    }
                }

            } finally {
                Write-Verbose "Restoring PSModulePath to $OldModulePath" -Verbose
                $Env:PSModulePath = $OldModulePath
            }
        }
    }
}
