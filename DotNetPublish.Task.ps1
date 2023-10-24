Add-BuildTask DotNetPublish @{
    # This task should be skipped if there are no C# projects to build
    If      = $dotnetProjects
    Inputs  = {
        # Exclude generated source files in /obj/ folders
        Get-ChildItem $dotnetProjects -Recurse -File -Filter *.cs |
            Where-Object FullName -NotMatch "[\\/]obj[\\/]"
    }
    Outputs = {
        Split-Path $dotnetProjects -Leaf |
            Join-Path -Path { "$DotNetPublishRoot${/}$_" } -ChildPath { "$_.dll" }
    }
    Jobs    = "DotNetBuild", {
        $local:options = @{} + $script:dotnetOptions

        $script:DotNetPublishRoot = New-Item $script:DotNetPublishRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path

        # We never do self-contained builds
        if ($options.ContainsKey("-runtime") -or $options.ContainsKey("-ucr")) {
            $options["-no-self-contained"] = $true
        }

        foreach ($project in $dotnetProjects) {
            $Name = Split-Path $project -Leaf
            if (Test-Path "Variable:GitVersion.$((Split-Path $project -Leaf).ToLower())") {
                $options["p"] = "Version=$((Get-Variable "GitVersion.$((Split-Path $project -Leaf).ToLower())" -ValueOnly).InformationalVersion)"
            }

            Set-Location $project
            $OutputFolder = @($dotnetProjects).Count -gt 1 ? "$DotNetPublishRoot${/}$Name" : $DotNetPublishRoot
            Write-Build Gray "dotnet publish --output $OutputFolder --no-build --configuration $configuration -p $($options["p"])"
            dotnet publish --output "$OutputFolder" --no-build --configuration $configuration
        }
    }
}
