Add-BuildTask Tag-Source @{
    If   = { $script:BuildSystem -ne 'None' -and $script:BranchName -match "^main" }
    Jobs = "Get-Version", {
        $tag = $script:Version.Tag
        $sha = $script:Version.Sha

        if (-not $tag -or -not $sha) {
            throw "Version.Tag ('$tag') or Version.Sha ('$sha') is missing. Cannot tag."
        }

        Write-Build Gray "Tag: $tag"
        Write-Build Gray "Sha: $sha"

        # Ensure git user is configured for the annotated tag
        if (-not (git config get user.email)) {
            git config user.name 'GitVersion'
            git config user.email 'DevOps@loandepot.com'
        }
        Write-Build Yellow "New-GitTag -TagName $tag -Sha $sha"
        New-GitTag -TagName $tag -Sha $sha
    }
}
