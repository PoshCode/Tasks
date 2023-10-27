Add-BuildTask PSModulePublish {
    if ($BuildSystem -ne 'None' -and
        $BranchName -in "master","main" -and
        -not [string]::IsNullOrWhiteSpace($PSModulePublishKey)) {

        # If the $PSModulePublishUri is set, make sure that's where we publish....
        if ($PSModulePublishUri -and $Script:PSRepository) {
            $PackageSource = Get-PSRepository -Name $Script:PSRepository -ErrorAction Ignore
            If (-Not $PackageSource -or $PackageSource.PublishLocation -ne $PSModulePublishUri) {
                $source = @{
                    Name     = $Script:PSRepository
                    Location = $PSModulePublishUri
                    Force    = $true
                    Trusted  = $True
                    ForceBootstrap = $True
                    ProviderName = $PowerShellGet
                }
                Register-PackageSource @source
            }
        }
        $publishModuleSplat = @{
            Path        = $PSModuleOutputPath
            NuGetApiKey = $PSModulePublishKey
            Verbose     = $true
            Force       = $true
            Repository  = $Script:PSRepository
            ErrorAction = 'Stop'
        }
        "Files in module output:"
        Get-ChildItem $PSModuleOutputPath -Recurse -File |
        Select-Object -Expand FullName

        "Publishing [$PSModuleOutputPath] to [$Script:PSRepository]"

        Publish-Module @publishModuleSplat
    } else {
        Write-Warning ("Skipping publish: To publish, ensure that...`n" +
        "`t* You are in a known build system (Current: $BuildSystem)`n" +
        "`t* You are committing to the main branch (Current: $BranchName) `n" +
        "`t* The repository APIKey is defined in `$PSModulePublishKey (Current: $(![string]::IsNullOrWhiteSpace($PSModulePublishKey)))")
    }
}
