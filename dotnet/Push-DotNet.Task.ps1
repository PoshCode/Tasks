Add-BuildTask Push-DotNet @{
    Jobs    = "Pack-DotNet", {
        $Package = Get-ChildItem $script:DotNetPackRoot -Recurse -Filter "*.nupkg"

        if ($script:PushEnabled -and "$NuGetPublishKey") {
            foreach ($nupkg in $Package) {
                Write-Build Yellow "dotnet nuget push $nupkg --api-key $NuGetPublishKey --source $NuGetPublishUri"
                dotnet nuget push $nupkg --api-key $NuGetPublishKey --source $NuGetPublishUri
            }
        } else {
            Write-Warning ("Skipping push: To push $Package ensure that...`n" +
                "`t* You are in a known build system (Current: $BuildSystem)`n" +
                "`t* You are committing to the main branch (Current: $BranchName) `n" +
                "`t* The repository APIKey is defined in `$NuGetPublishKey (Current: $(!!"$NuGetPublishKey"))")
        }
    }
}
