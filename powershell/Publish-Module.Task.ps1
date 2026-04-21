Add-BuildTask Publish-Module {
    if ($BuildSystem -ne 'None' -and
        $BranchName -in "master", "main", "release", "production" -and
        -not [string]::IsNullOrWhiteSpace($Script:PowerShellModulePublishKey)) {

        $publishModuleSplat = @{
            Path        = $Script:ModuleOutputPath
            NuGetApiKey = $Script:PowerShellModulePublishKey
            Verbose     = $true
            Force       = $true
            Repository  = $Script:PSRepository
            ErrorAction = 'Stop'
        }
        "Files in module output:"
        Get-ChildItem $Script:ModuleOutputPath -Recurse -File |
            Select-Object -Expand FullName

        "Publishing [$Script:ModuleOutputPath] to [$Script:PSRepository]"

        Publish-Module @publishModuleSplat
    } else {
        Write-Warning ("Skipping deployment: To deploy, ensure that...`n" +
            "`t* You are in a known build system (Current: $BuildSystem)`n" +
            "`t* You are committing to the main branch (Current: $BranchName) `n" +
            "`t* The repository APIKey is defined in `$Script:PowerShellModulePublishKey (Current: $(![string]::IsNullOrWhiteSpace($Script:PowerShellModulePublishKey))) `n" +
            "`t* This is not a pull request")
    }
}
