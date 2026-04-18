# TODO: in pipeline environments, we should trigger the "cache" task for these to speed up using them
Add-BuildTask InstallGitHubTools @{
    If = $script:GHTools.Count -gt 0
    Jobs = {
        &(Join-Path (Split-Path $PSScriptRoot) "scripts/Install-GitHubRelease.ps1") $script:GHTools
    }
}
