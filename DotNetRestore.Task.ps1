Add-BuildTask DotNetRestore @{
    # This task should be skipped if there are no C# projects to build
    If      = $dotnetProjects
    Inputs  = {
        Get-Item $dotnetProjects
    }
    Outputs = {
        $dotnetProjects.ForEach{ Join-Path (Split-Path $_) obj project.assets.json }
    }
    Jobs    = {
        $local:options = @{} + $script:dotnetOptions

        if (Test-Path "$BuildRoot/NuGet.config") {
            $options["-configfile"] = "$BuildRoot/NuGet.config"
        }
        foreach ($project in $dotnetProjects) {
            Write-Build Gray "dotnet restore $project" @options
            dotnet restore $project @options
        }
    }
}
