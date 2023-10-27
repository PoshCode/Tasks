Add-BuildTask DotNetPack @{
    # This task should be skipped if there are no C# projects to build
    If      = $dotnetProjects
    Jobs    = "DotNetBuild", {
        $local:options = @{} # + $script:dotnetOptions

        $script:DotNetPublishRoot = New-Item $script:DotNetPublishRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path

        foreach ($project in $dotnetProjects) {
            if (Test-Path "Variable:GitVersion.$((Split-Path $project -Leaf).ToLower())") {
                $options["p"] = "Version=$((Get-Variable "GitVersion.$((Split-Path $project -Leaf).ToLower())" -ValueOnly).InformationalVersion)"
            }

            Write-Host "Publishing $project"
            $Name = Split-Path $project -Leaf

            Set-Location $project
            $OutputFolder = @($dotnetProjects).Count -gt 1 ? "$DotNetPublishRoot${/}$Name" : $DotNetPublishRoot
            Write-Build Gray "dotnet pack $project --output '$OutputFolder' --no-build --configuration $configuration -p $($options["p"])"
            dotnet pack $project --output "$OutputFolder" --no-build --configuration $configuration @options --include-symbols

            if ($BuildSystem -ne 'None' -and
                $BranchName -in "master", "main" -and
                -not [string]::IsNullOrWhiteSpace($NuGetPublishKey)) {
                    Write-Host "$OutputFolder" "-Recurse" "-Filter" "*$Name*$($GitVersion.MajorMinorPatch).nupkg"
                    $Package = Get-ChildItem $OutputFolder -Recurse -Filter "*$Name*$($GitVersion.MajorMinorPatch).nupkg"
                    Write-Build Gray "dotnet nuget push $package --api-key $NuGetPublishKey --source $NuGetPublishUri"
                    dotnet nuget push $package --api-key $NuGetPublishKey --source $NuGetPublishUri
            } else {
                Write-Warning ("Skipping push: To push, ensure that...`n" +
                    "`t* You are in a known build system (Current: $BuildSystem)`n" +
                    "`t* You are committing to the main branch (Current: $BranchName) `n" +
                    "`t* The repository APIKey is defined in `$NuGetPublishKey (Current: $(![string]::IsNullOrWhiteSpace($NuGetPublishKey)))")
            }
        }
    }
}
