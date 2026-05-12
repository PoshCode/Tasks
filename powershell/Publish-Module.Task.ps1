Add-BuildTask Publish-Module @{
    If   = { Test-Path $script:ManifestPath }
    Jobs = {
        $Package = Get-ChildItem $script:PSPackageRoot -Recurse -Filter "*.nupkg"

        $PSPushEnabled = $script:PSPublishKey -and $script:PSPublishUri -and $Package -and (
            $script:PushEnabled -or (
                $script:BuildSystem -ne "None" -and
                ($script:BranchName -eq "main" -or $script:BranchName -like "release/*")
            )
        )

        if ($PSPushEnabled) {
            # The need to register a PSRepository is why we don't use this anymore
            $Repo = (Get-PSRepository -ErrorAction Ignore).Where({ $_.PublishLocation -eq $script:PSPublishUri })
            $PSRepository = if ($Repo) {
                $Repo.Name
            } else {
                $PSRepository = [IO.Path]::GetRandomFileName()
                Register-PSRepository -Name $PSRepository $script:PSPublishUri
            }

            $publishModuleSplat = @{
                Path        = $Script:ModuleOutputRoot
                NuGetApiKey = $Script:PSPublishKey
                Verbose     = $true
                Force       = $true
                Repository  = $PSRepository
                ErrorAction = 'Stop'
            }
            "Publishing [$Script:ModuleOutputRoot] to [$Script:PSPublishUri]"
            Get-ChildItem $Script:ModuleOutputRoot -Recurse -File |
                Select-Object -Expand FullName

            Publish-Module @publishModuleSplat
        } else {
            Write-Warning ("Skipping Publish-Module: To publish, ensure that...`n" +
                "`t* You have packages to push in $script:PSPackageRoot (Current: $(@($Package).Count))`n" +
                "`t* The repository Key is defined in `$PSPublishKey (Current: $(!!"$PSPublishKey"))" +
                "`t* The repository URI is defined in `$PSPublishUri (Current: $(!!"$PSPublishUri"))" +
                "`t* You have set PushEnabled (Current: $script:PushEnabled) OR`n" +
                "`t* You are in a known build system (Current: $BuildSystem) AND`n" +
                "`t* You are committing to the main branch (Current: $BranchName)")
        }
    }
}
