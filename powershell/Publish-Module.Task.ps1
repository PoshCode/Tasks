Add-BuildTask Publish-Module @{
    If   = { Test-Path $script:ManifestPath }
    Jobs = {
        Get-Module -List $script:ManifestPath | Publish-PSModuleNuget -OutputPath $script:PSPackageRoot
    }
}
