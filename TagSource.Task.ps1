Add-BuildTask TagSource @{
    If   = { $script:BranchName -match "main|master" }
    Jobs = "GitVersion", {
        foreach ($Name in $PackageNames) {
            git tag $GitVersion.$Name.Tag -m "Release $($GitVersion.$Name.InformationalVersion)"
            git push origin --tags
        }
    }
}
