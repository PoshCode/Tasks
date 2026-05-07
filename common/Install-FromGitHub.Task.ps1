# TODO: in pipeline environments, we should trigger the "cache" task for these to speed up using them
Add-BuildTask Install-FromGitHub @{
    If = { $script:GHTools.keys.Count -gt 0 }
    Jobs = {
        foreach ($tool in $script:GHTools.keys) {
            if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
                Write-Build Gray "Installing $tool..."
                $script:GHTools[$tool] | &(Join-Path (Split-Path $PSScriptRoot) "scripts" "Install-FromGitHub.ps1") -ErrorAction SilentlyContinue
            }
        }
    }
}
