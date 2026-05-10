Add-BuildTask Push-DotNet {
    $Package = Get-ChildItem $script:DotNetPackRoot -Recurse -Filter "*.nupkg"

    $DotNetPushEnabled = $script:NuGetPublishKey -and $script:NuGetPublishUri -and $Package -and (
        $script:PushEnabled -or (
            $script:BuildSystem -ne "None" -and
            ($script:BranchName -eq "main" -or $script:BranchName -like "release/*")
        )
    )

    if ($DotNetPushEnabled) {
        foreach ($nupkg in $Package) {
            Write-Build Yellow "dotnet nuget push $nupkg --api-key $script:NuGetPublishKey --source $script:NuGetPublishUri"
            dotnet nuget push $nupkg --api-key $script:NuGetPublishKey --source $script:NuGetPublishUri
        }
    } else {
        Write-Warning ("Skipping Push for DotNet. To push ensure that...`n" +
            "`t* You have packages to push in $script:DotNetPackRoot (Current: $(@($Package).Count))`n" +
            "`t* The repository Key is defined in `$NuGetPublishKey (Current: $(!!"$NuGetPublishKey"))" +
            "`t* The repository URI is defined in `$NuGetPublishUri (Current: $(!!"$NuGetPublishUri"))" +
            "`t* You have set PushEnabled (Current: $script:PushEnabled) OR`n" +
            "`t* You are in a known build system (Current: $BuildSystem) AND`n" +
            "`t* You are committing to the main branch (Current: $BranchName)")
    }
}
