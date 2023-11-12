Add-BuildTask DotNetPublish @{
    # This task should be skipped if there are no C# projects to build
    If      = $dotnetProjects
    Inputs  = {
        # Exclude generated source files in /obj/ folders
        Get-ChildItem (Split-Path $dotnetProjects) -Recurse -File -Filter *.cs |
            Where-Object FullName -NotMatch "[\\/]obj[\\/]"
    }
    Outputs = {
        foreach ($project in $dotnetProjects) {
            $Name = Split-Path $project -LeafBase
            $OutputFolder = @($dotnetProjects).Count -gt 1 ? "$DotNetPublishRoot${/}$Name" : $DotNetPublishRoot
            $Expected = Join-Path $OutputFolder -ChildPath "$Name.dll"
            Write-Host "Expected Output: $Expected"
            $Expected
        }
    }
    Jobs    = "DotNetBuild", {
        $local:options = @{} + $script:dotnetOptions

        $script:DotNetPublishRoot = New-Item $script:DotNetPublishRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path

        # We never do self-contained builds
        if ($options.ContainsKey("-runtime") -or $options.ContainsKey("-ucr")) {
            $options["-no-self-contained"] = $true
        }

        foreach ($project in $dotnetProjects) {
            $Name = Split-Path $project -LeafBase
            Write-Host "Publishing $Name"
            if (Test-Path "Variable:GitVersion.$Name") {
                $options["p"] = "Version=$((Get-Variable "GitVersion.$Name" -ValueOnly).InformationalVersion)"
            }

            Set-Location (Split-Path $project)
            $OutputFolder = @($dotnetProjects).Count -gt 1 ? "$DotNetPublishRoot${/}$Name" : $DotNetPublishRoot
            Write-Build Gray "dotnet publish $project --output $OutputFolder --no-build --configuration $configuration -p $($options["p"])"
            dotnet publish $project --output "$OutputFolder" --no-build --configuration $configuration
        }
    }
}
