Add-BuildTask MonoRepoTagSource @{
    If   = {
        if ($script:BuildSystem -eq 'None') {
            Write-Warning "Skipping MonoRepoTagSource: not running in a known build system"
            return $false
        }
        if ($script:BranchName -notmatch "^main") {
            Write-Warning "We should only tag main, not $script:BranchName"
            return $false
        }
        if (!$script:MonoRepoChangedProjects) {
            Write-Warning "No changed projects detected, nothing to tag"
            return $false
        }
        return $true
    }
    Jobs = {
        foreach ($Project in $script:MonoRepoChangedProjects) {
            $gitVersion = Get-Content (Join-Path $Project.Path "version.json") | ConvertFrom-Json
            # Convention: each project tag is the project name (lowercased folder name) + MajorMinorPatch
            New-GitTag -TagName ($Project.Name + $gitVersion.MajorMinorPatch) -Sha $gitVersion.Sha
        }
    }
}
