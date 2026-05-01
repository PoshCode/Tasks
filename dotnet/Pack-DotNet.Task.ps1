#! If this is trying to pack a test project, you must add <IsTestProject>true</IsTestProject> to the project file.
Add-BuildTask Pack-DotNet @{
    If      = {
        [bool]$DotNetProjects.Where({ $_.IsPackable }, "First", 1)
    }
    Inputs  = {
        $DotNetProjects.Where({ $_.IsPackable }).ForEach({ Join-Path $_.OutDir $_.TargetFileName })
    }
    Outputs = {
        $DotNetProjects.Where({ $_.IsPackable }).ForEach({ Join-Path $script:DotNetPackRoot ($_.AssemblyName + ".*.nupkg") })
    }
    Jobs    = "Build-DotNet", {
        $script:DotNetPackRoot = New-Item $script:DotNetPackRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path

        $local:options = @{
            "-output" = $script:DotNetPackRoot
        }

        Write-Build Yellow "Packing $SolutionName"
        $options["p"] = "Version=$(${script:Version}.InformationalVersion)"

        Write-Build Yellow "dotnet pack $DotNetSolutionFile --no-build --include-symbols $(($options.GetEnumerator().ForEach({"$($_.key) $($_.value)"})) -join ' ')"
        dotnet pack $DotNetSolutionFile --no-build --include-symbols @options
    }
}
