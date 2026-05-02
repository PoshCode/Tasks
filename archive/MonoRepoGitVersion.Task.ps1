<#
Return child folders/files from paths listed in MonoRepoConfig.psd1, run a git diff to find files
that have changed in that path. For each of the folders containing changed files, run gitversion
and export to version.json in the same folder.

Supports an override setting $script:ForceVersionAllProjects = $true to calculate a version for
every single project.
#>
Add-BuildTask MonoRepoGitVersion @{
    If     = {
        # MonoRepoGitVersion requires MonoRepoConfig.psd1
        (Test-Path $script:BuildRoot/MonoRepoConfig.psd1) -and $(
            # If that's present, then we check for changes in those subfolders
            $MonoRepo = Import-Metadata $script:BuildRoot/MonoRepoConfig.psd1

            $Projects = $MonoRepo.Projects.GetEnumerator().ForEach{
                Write-Verbose "Searching $($_.Key)"
                foreach ($Path in Get-ChildItem $_.Key | Resolve-Path -Relative) {
                    $VersionPath = Join-Path $Path version.json
                    [PSCustomObject]@{
                        Name       = ($_.Value -f ($Path | Split-Path -Leaf)).ToLower()
                        Path       = $Path
                        GitVersion = if (Test-Path $VersionPath) { Get-Content $VersionPath | ConvertFrom-Json }
                    }
                }
            }

            # In builds, the checkout is frequently shallow with no cloned origin/HEAD
            # Trying and failing this is many times faster than `git remote show`
            git remote set-head origin main 2>$null
            if ($LASTEXITCODE) { git remote set-head origin master }
            # the full output would be refs/remotes/origin/main
            $MainBranch = (git symbolic-ref refs/remotes/origin/HEAD) -replace 'refs/remotes/'

            # If we are on the main branch, compare against previous commit, otherwise, against the main branch
            $commitish = if ((git branch -a --contains) -match "$MainBranch$") {
                'HEAD~1'
            } else {
                "$MainBranch..HEAD"
            }

            $gitChanges = git diff --name-only --diff-filter=CMARTUX $commitish
            $fileChanges = $gitChanges | Resolve-Path -Relative -OutVariable script:MonoRepoGitVersionInput

            $script:MonoRepoChangedProjects = $Projects.Foreach({
                    $Project = $_
                    $projectFiles = $fileChanges.Where({ $_.StartsWith($Project.Path + '\') -or $_.StartsWith($Project.Path + '/') })
                    if ($script:ForceVersionAllProjects -or $projectFiles) {
                        $Project | Add-Member NoteProperty changedFiles $projectFiles -PassThru
                    }
                })
            @($script:MonoRepoChangedProjects).Count -gt 0
        )
    }
    Input  = {
        $script:MonoRepoGitVersionInput
    }
    Output = {
        $script:MonoRepoChangedProjects.Path | Join-Path -ChildPath version.json
    }
    Jobs   = "Install-DotNetTool", {

        # Configure git identity so that `git commit --amend` can succeed on CI agents
        # that have no global git identity configured (e.g. ephemeral Linux build agents).
        git config user.email "gitversion@pipeline.local"
        git config user.name "GitVersion Pipeline"

        # If this is a PR build, fetch the "description" which will go into the commit later
        if ($Env:SYSTEM_PULLREQUEST_PULLREQUESTID -and $Env:SYSTEM_ACCESSTOKEN -and $Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI -and $Env:BUILD_REPOSITORY_URI -notmatch "github.com") {
            $BaseUri = "$($Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI)$($Env:SYSTEM_TEAMPROJECTID)/_apis"
            # The highest our on-prem can handle is 5.1-preview.1
            $ApiVersion = 'api-version=5.1-preview.1'
            $PullRequest = Invoke-RestMethod "$($BaseUri)/git/pullrequests/${Env:SYSTEM_PULLREQUEST_PULLREQUESTID}?$($ApiVersion)" -Headers @{
                Authorization = "Bearer $Env:SYSTEM_ACCESSTOKEN"
            }

            $commitMessage = $PullRequest.title + "`n`n" + $PullRequest.description
            # change the PR merge message so that gitversion can do it's thing
            git commit --amend -m "Merged PR $($Env:SYSTEM_PULLREQUEST_PULLREQUESTID): $($commitMessage)"
        } elseif ($Env:SYSTEM_PULLREQUEST_PULLREQUESTID -and $Env:BUILD_REPOSITORY_URI -match "github.com") {
            # GitHub-hosted repo: extract token from git credentials and fetch PR via GitHub API
            $extraHeaderLine = git config --get-regexp 'http\.https://github\.com.*\.extraheader' 2>$null | Select-Object -First 1
            if ($extraHeaderLine) {
                $base64Auth = (($extraHeaderLine -split '\s+', 2)[1] -replace '^AUTHORIZATION:\s*basic\s*', '').Trim()
                $githubToken = ([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($base64Auth)) -split ':', 2)[1]
            }
            if ($githubToken) {
                Write-Host "getting PR information from url:"
                Write-Host "  https://api.github.com/repos/$($Env:BUILD_REPOSITORY_NAME)/pulls/$($Env:SYSTEM_PULLREQUEST_PULLREQUESTNUMBER)" -ForegroundColor Cyan
                $PullRequest = Invoke-RestMethod "https://api.github.com/repos/$($Env:BUILD_REPOSITORY_NAME)/pulls/$($Env:SYSTEM_PULLREQUEST_PULLREQUESTNUMBER)" -Headers @{
                    Authorization = "Bearer $githubToken"
                    Accept        = 'application/vnd.github.v3+json'
                }
                $commitMessage = $PullRequest.title + "`n`n" + $PullRequest.body
                git commit --amend -m "Merged PR $($Env:SYSTEM_PULLREQUEST_PULLREQUESTNUMBER): $($commitMessage)"
            } else {
                throw "Unable to extract GitHub token from git config. Please ensure your pipeline is configured correctly to provide access tokens for GitHub API calls. In a pipeline make sure 'persistCredentials: true'."
            }
        } elseif ($script:SemverTrailer) {
            # If SemverTrailer is set, alter the commit message so gitversion follows...
            $originalCommitMessage = (git log -1 --format=%B) -join "`n"
            $commitMessage = $originalCommitMessage + "`n`n" + $script:SemverTrailer
            git commit --amend -m $commitMessage
        } else {
            # %B is for the raw "Body" of the commit message. See https://git-scm.com/docs/git-show#_pretty_formats
            $commitMessage = (git log -1 --format=%B) -join "`n"
        }

        # In PR pipelines for MonoRepos we are very strict about PR commit message incrementing
        if ($PullRequest -and $commitMessage -notmatch 'semver-[-a-z]+:\s*(breaking|major|feature|minor|fix|patch|none|skip)') {
            throw "In a MonoRepo, you must specify a semantic version increment in your merge request descriptions.`nPlease add a line like: `"semver-$($script:MonoRepoChangedProjects[0].Name):patch`" for each module to indicate the type of change.`nAllowed changes are:`n- 'breaking' or 'major' for the first number`n- 'feature' or 'minor' for the middle number`n- 'fix' or 'patch' for the last number`n`nYour Commit Message:`n$commitMessage"
        }

        foreach ($Project in $script:MonoRepoChangedProjects) {
            $semverMessagePattern = "semver-$($Project.Name):\s*(breaking|major|feature|minor|fix|patch|none|skip)"
            if ($commitMessage -notmatch $semverMessagePattern) {
                if ($PullRequest) {
                    throw "You changed $($Project.Name) but did not specify the semantic version increment for it.`nPlease add a line like: `"semver-$($Project.Name):patch`" to indicate the type of change.`nAllowed increments are:`n- 'breaking' or 'major' for the first number`n- 'feature' or 'minor' for the middle number`n- 'fix' or 'patch' for the last number`n`nYour Commit Message:`n$commitMessage"
                } else {
                    Write-Warning "You changed $($Project.Name), assuming: `"semver-$($Project.Name):patch`""
                }
            }

            # For the sake of other MonoRepo tasks, we must calculate a VersionChange
            # When building locally, if you have not specified one _in this commit_ our default is "patch"
            $VersionChange = if (($increment = (($commitMessage | Select-String -Pattern $semverMessagePattern).Matches.Value -split ':')[-1].trim())) {
                switch -regex ($increment) {
                    'major|breaking' { 'Major' }
                    'minor|feature' { 'Minor' }
                    'fix|patch' { 'Patch' }
                    'none|skip' { 'Skip' }
                }
            } else { "Patch" }

            $GitVersionYaml = if (Test-Path "$($Project.Path)/GitVersion.yml") {
                "$($Project.Path)/GitVersion.yml"
            } else {
                "$PSScriptRoot/GitVersion.yml"
            }

            $ProjectVersionFile = "$($Project.Path)/version.json"
            # NOTE: tag-prefix is NOT overridden here - each module's GitVersion.yml sets it correctly
            # (e.g. 'BicepFlex/v', 'LDAzOps/v') to match actual git tags. Overriding with the
            # lowercased project name would cause TaggedCommitVersionStrategy to find no tags.
            dotnet tool execute gitversion.tool -config $GitVersionYaml -output file -outputfile $ProjectVersionFile `
                -overrideconfig major-version-bump-message="semver-$($Project.Name):\s*(breaking|major)" `
                -overrideconfig minor-version-bump-message="semver-$($Project.Name):\s*(feature|minor)" `
                -overrideconfig patch-version-bump-message="semver-$($Project.Name):\s*(fix|patch)" `
                -overrideconfig no-bump-message=".*" `
                -overrideconfig commit-message-incrementing=MergeMessageOnly

            # prepend the VersionChange to the gitversion output and save
            Get-Content $ProjectVersionFile | ConvertFrom-Json | Add-Member NoteProperty VersionChange $VersionChange -PassThru -OutVariable versionJson | ConvertTo-Json | Set-Content $ProjectVersionFile

            $Project.GitVersion = $versionJson
            "  Updated $($Project.Name) $($VersionChange) version: $($versionJson.InformationalVersion)"
        }
        if ($script:SemverTrailer -and $originalCommitMessage) {
            # Put back the commit message before we added the SemverTrailer
            git commit --amend -m $originalCommitMessage
        }
    }
}
