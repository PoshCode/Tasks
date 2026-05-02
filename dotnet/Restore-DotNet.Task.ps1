<#
.SYNOPSIS
    Runs dotnet restore
.DESCRIPTION
    Checks to make sure the output assets.json is up to date with
    the input *proj files, and if not, runs dotnet restore
#>

Add-BuildTask Restore-DotNet @{
    # Inputs  = {
    #     $DotNetProjects.Path
    #     if (Test-Path "$BuildRoot/NuGet.config") {
    #         "$BuildRoot/NuGet.config"
    #     }
    # }
    # Outputs = {
    #     # Return corresponding project.assets.json files
    #     $Project.BaseIntermediateOutputRoot | Join-Path -ChildPath "project.assets.json"
    # }
    Jobs = "Install-DotNetTool", {
        $local:options = @{} + $script:dotnetOptions
        # We're doing this for case-sensitive reasons
        if (($NugetConfig = Get-ChildItem $BuildRoot -Filter "[Nn]u[Gg]et.config")) {
            $options["-configfile"] = $NugetConfig.FullName
        }
        Write-Build Yellow "dotnet restore $DotNetSolutionFile $(($options.GetEnumerator().ForEach({"$($_.key) $($_.value)"})) -join ' ')"

        # dotnet restore $DotNetSolutionFile @options
        foreach ($Project in $script:DotNetProjects) {
            $RestoreOutput = dotnet restore $Project.Path @options -getProperty:$($Project.PSObject.Properties.Name -ne "Path" -join ",") | ConvertFrom-Json -AsHashtable
            if (!$?) { throw "dotnet restore failed for project $($Project.Path)" }
            foreach ($Property in $Project.PSObject.Properties.Name -ne "Path") {
                if ($RestoreOutput.Properties.$Property) {
                    if ($Property -match "^Is") {
                        $Project.$Property = [bool]::Parse($RestoreOutput.Properties.$Property)
                    } else {
                        $Project.$Property = $RestoreOutput.Properties.$Property
                    }
                }
            }
        }
    }
}
