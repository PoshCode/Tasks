Add-BuildTask TagSource @{
    If   = { $script:BranchName -in "main", "master", "release" }
    Jobs = "GitVersion", {
        foreach ($Name in $PackageNames) {
            git tag $Version.$Name.Tag -m "Release $($Version.$Name.InformationalVersion)"
            git push origin --tags
        }
    }
}
