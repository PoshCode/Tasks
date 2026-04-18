Add-BuildTask DotNetRestore @{
    If      = $dotnetSolution
    Inputs  = {
        $Projects = $dotnetProjects | ForEach-Object { Join-Path (Split-Path $dotnetSolution) $_ }
        $Projects
        if (Test-Path "$BuildRoot/NuGet.config") {
            "$BuildRoot/NuGet.config"
        }
    }
    Outputs = {
        $Projects = $dotnetProjects | ForEach-Object { Join-Path (Split-Path $dotnetSolution) $_ }        
        # Return corresponding project.assets.json files
        foreach ($Proj in $Projects) {
            $ProjectName = [IO.Path]::GetFileNameWithoutExtension($Proj)
            Join-Path $script:OutputPath "obj/$ProjectName/project.assets.json"
        }
    }
    Jobs = "DotNetToolRestore", {
        $local:options = @{} + $script:dotnetOptions
        if (Test-Path "$BuildRoot/NuGet.config") {
            $options["-configfile"] = "$BuildRoot/NuGet.config"
        }
        
        # Pass SolutionName so Directory.Build.props can calculate correct paths (I think?)
        $SolutionName = if ($dotnetSolution -match '\.sln') {
            Split-Path $dotnetSolution -LeafBase
        } else {
            "shared"
        }
        
        Write-Build Gray "dotnet restore $dotnetSolution $(($options.GetEnumerator().ForEach({"$($_.key) $($_.value)"})) -join ' ') -p:SolutionName=$SolutionName"
        dotnet restore $dotnetSolution @options "-p:SolutionName=$SolutionName"
    }
}