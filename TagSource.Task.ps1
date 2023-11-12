Add-BuildTask TagSource @{
    If   = { $script:BranchName -match "main|master" }
    Jobs = "GitVersion", {
        foreach ($Name in $PackageNames) {
            $Version = Get-Variable "GitVersion.$Name" -ValueOnly
            git tag $Version.Tag -m "Release $($Version.InformationalVersion)"
            git push origin --tags
        }
    }
}
