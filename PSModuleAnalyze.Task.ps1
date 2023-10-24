Add-BuildTask PSModuleAnalyze PSModuleBuild, {
    $ScriptAnalyzer = @{
        IncludeDefaultRules = $true
        Path                = $PSModuleManifestPath -replace "d1$","*1"
        Settings            = if (Test-Path "$BuildRoot\ScriptAnalyzerSettings.psd1") {
            "$BuildRoot\ScriptAnalyzerSettings.psd1"
        } else {
            "$PSScriptRoot\ScriptAnalyzerSettings.psd1"
        }
    }

    "Analyze $($ScriptAnalyzer.Path) -Settings $($ScriptAnalyzer.Settings)"
    $results = Invoke-ScriptAnalyzer @ScriptAnalyzer
    if ($results) {
        Write-Warning 'Please investigate and correct, or add the required SuppressMessage attribute.'
        $results | Format-Table -AutoSize | Out-String
        throw 'One or more issues were found by PSScriptAnalyzer'
    }
}