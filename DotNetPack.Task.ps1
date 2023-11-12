Add-BuildTask DotNetPack @{
    # This task should be skipped if there are no C# projects to build
    If      = $dotnetProjects
    Jobs    = "DotNetBuild", {
        $local:options = @{} # + $script:dotnetOptions

        $script:DotNetPublishRoot = New-Item $script:DotNetPublishRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path

        foreach ($project in $dotnetProjects) {
            $Name = Split-Path $project -LeafBase
            if ($GitVersion.$Name) {
                $options["p"] = "Version=$($GitVersion.$Name.InformationalVersion)"
            }

            Write-Host "Publishing $Name"

            Set-Location (Split-Path $project)
            $OutputFolder = $DotNetPublishRoot
            Write-Build Gray "dotnet pack $project --output '$OutputFolder' --no-build --configuration $configuration -p $($options["p"])"
            dotnet pack $project --output "$OutputFolder" --no-build --configuration $configuration @options --include-symbols
        }
    }
}
