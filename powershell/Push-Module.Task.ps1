Add-BuildTask Push-Module {
    $Package = Get-ChildItem $script:PSPackageRoot -Recurse -Filter "*.nupkg"

    $PSPushEnabled = $script:PSPublishKey -and $script:PSPublishUri -and $Package -and (
        $script:PushEnabled -or (
            $script:BuildSystem -ne "None" -and
            ($script:BranchName -eq "main" -or $script:BranchName -like "release/*")
        )
    )

    if ($PSPushEnabled) {
        foreach ($nupkg in $Package) {
            Write-Build Yellow "dotnet nuget push $nupkg --api-key $script:PSPublishKey --source $script:PSPublishUri"
            dotnet nuget push $nupkg --api-key $script:PSPublishKey --source $script:PSPublishUri
        }
    } else {
        Write-Warning ("Skipping Push for PowerShell. To push ensure that...`n" +
            "`t* You have packages to push in $script:PSPackageRoot (Current: $(@($Package).Count))`n" +
            "`t* The repository Key is defined in `$PSPublishKey (Current: $(!!"$PSPublishKey"))" +
            "`t* The repository URI is defined in `$PSPublishUri (Current: $(!!"$PSPublishUri"))" +
            "`t* You have set PushEnabled (Current: $script:PushEnabled) OR`n" +
            "`t* You are in a known build system (Current: $BuildSystem) AND`n" +
            "`t* You are committing to the main branch (Current: $BranchName)")
    }
}
