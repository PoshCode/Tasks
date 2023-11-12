Add-BuildTask DotNetPush @{
    # This task should be skipped if there are no C# projects to build
    If      = $dotnetProjects
    Jobs    = "DotNetPack", {
        $local:options = @{} # + $script:dotnetOptions

        $script:DotNetPublishRoot = New-Item $script:DotNetPublishRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path

        foreach ($project in $dotnetProjects) {
            $Name = Split-Path $project -LeafBase
            $options["p"] = "Version=$($GitVersion.$Name.InformationalVersion)"

            Write-Host "Publishing $name"

            Set-Location (Split-Path $project)
            $OutputFolder = @($dotnetProjects).Count -gt 1 ? "$DotNetPublishRoot${/}$Name" : $DotNetPublishRoot

            $Package = Get-ChildItem $OutputFolder -Recurse -Filter "*$Name*$($GitVersion.$Name.MajorMinorPatch).nupkg"

            if ($BuildSystem -ne 'None' -and
                $BranchName -in "master", "main" -and
                -not [string]::IsNullOrWhiteSpace($NuGetPublishKey)) {
                    Write-Host "$OutputFolder" "-Recurse" "-Filter" "*$Name*$($GitVersion.$Name.MajorMinorPatch).nupkg"
                    Write-Build Gray "dotnet nuget push $package --api-key $NuGetPublishKey --source $NuGetPublishUri"
                    dotnet nuget push $package --api-key $NuGetPublishKey --source $NuGetPublishUri
            } else {
                Write-Warning ("Skipping push: To push $Package ensure that...`n" +
                    "`t* You are in a known build system (Current: $BuildSystem)`n" +
                    "`t* You are committing to the main branch (Current: $BranchName) `n" +
                    "`t* The repository APIKey is defined in `$NuGetPublishKey (Current: $(![string]::IsNullOrWhiteSpace($NuGetPublishKey)))")
            }
        }
    }
}
