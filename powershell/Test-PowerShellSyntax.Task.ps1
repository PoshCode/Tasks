Add-BuildTask Test-PowerShellSyntax @{
    Outputs = {
        if ($Clean) {
            $BuildRoot # guaranteed to be old
        } else {
            "$script:ModuleTestResultsRoot/results.sarif"
        }
    }
    Inputs  = {
        # Build Output
        Get-ChildItem $ModuleOutputRoot -Recurse -File
        # Test Source
        $Tests = Join-Path $BuildRoot [Tt]ests | Resolve-Path
        Get-ChildItem $Tests -Recurse -File -Filter *.tests.ps1
    }
    Jobs    = {
        $ScriptAnalyzer = @{
            IncludeDefaultRules = $true
            Settings            = Get-Item -ErrorAction SilentlyContinue @(
                "$BuildRoot/PSScriptAnalyzerSettings.psd1",
                # This is a little bit of a weird hack for monorepo structure
                "$BuildRoot/../PSScriptAnalyzerSettings.psd1",
                "$BuildTasksRoot/PSScriptAnalyzerSettings.psd1"
            ) | Select-Object -First 1 -ExpandProperty FullName
        }
        $Files = Get-ChildItem $ModuleOutputRoot -Recurse -File -Filter *.ps*1

        "Analyzing $($Files -join "`n          ")"
        $results = $Files | Invoke-ScriptAnalyzer @ScriptAnalyzer
        if (Get-Module ConvertToSARIF -List) {
            Write-Verbose "Converting ScriptAnalyzer results to SARIF..."
            $results | ConvertToSARIF\ConvertTo-SARIF -FilePath "$script:ModuleTestResultsRoot/results.sarif"
        } else {
            Write-Warning "ConvertToSARIF module not found. Sarif results will not be generated. Please add ConvertToSARIF to your build.requires.psd1 file."
        }

        if ($results) {
            'One or more PSScriptAnalyzer errors/warnings were found.'
            'Please investigate or add the required SuppressMessage attribute.'
            $results | Format-Table -AutoSize
        }
    }
}
