Add-BuildTask TagSource @{
    If   = { $script:BranchName -match "main|master" }
    Jobs = "GitVersion", {
        git tag ("v" + $script:GitVersion.MajorMinorPatch) -m "Release $($script:GitVersion.InformationalVersion)"
        git push origin --tags
    }
}
