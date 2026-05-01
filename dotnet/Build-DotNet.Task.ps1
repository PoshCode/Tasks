Add-BuildTask Build-DotNet @{
    # TODO: Are these Inputs/Outputs actually ever saving us time?
    Inputs  = {
        $DotNetProjects.ForEach({ Get-ChildItem (Split-Path $_.Path) -Recurse -File -ErrorAction SilentlyContinue })
    }
    Outputs = {
        $DotNetProjects.ForEach({ Join-Path $_.OutDir $_.TargetFileName })
    }
    Jobs    = "Restore-DotNet", "Get-Version", {
        $local:options = @{} + $script:dotnetOptions
        $options["p"] = "Version=$(${script:Version}.InformationalVersion)"

        Write-Build Yellow "dotnet build $DotNetSolutionFile --no-restore $(($options.GetEnumerator().ForEach({"-$($_.key) $($_.value)"})) -join ' ')"
        # Invoke-BuildExec [-Command] ScriptBlock [[-ExitCode] Int32[]] [[-ErrorMessage] String] [-Echo] [-StdErr]

        dotnet build $DotNetSolutionFile --no-restore @options
    }
}
