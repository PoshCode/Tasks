<#
.SYNOPSIS
    Runs dotnet restore
.DESCRIPTION
    Checks to make sure the output assets.json is up to date with
    the input *proj files, and if not, runs dotnet restore
#>

Add-BuildTask Restore-DotNet @{
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
            Join-Path $script:SolutionOutputPath "obj/$ProjectName/project.assets.json"
        }
    }
    Jobs    = "Install-DotNetTool", {
        $local:options = @{} + $script:dotnetOptions
        $NugetConfig = Get-ChildItem $BuildRoot -File | Where-Object { $_.Name -ieq "NuGet.config" }
        if ($NugetConfig) {
            $options["-configfile"] = "$BuildRoot/$($NugetConfig.Name)"
        }

        Write-Build Yellow "dotnet restore $dotnetSolution $(($options.GetEnumerator().ForEach({"$($_.key) $($_.value)"})) -join ' ')"
        dotnet restore $dotnetSolution @options
    }
}
