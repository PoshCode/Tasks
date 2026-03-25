# TODO: Where is the repository name coming from?
Add-BuildTask DotNetDockerBuild @{
    Inputs  = {
        $PublishedDockerfiles = Get-ChildItem $script:DotNetPublishRoot -Recurse -File -Filter "Dockerfile" -ErrorAction SilentlyContinue
        $PublishedDockerfiles.ForEach({
                Get-ChildItem $_.Directory -File
            })
    }
    Outputs = {
        $PublishedDockerfiles = Get-ChildItem $script:DotNetPublishRoot -Recurse -File -Filter "Dockerfile" -ErrorAction SilentlyContinue
        if ($PublishedDockerFiles) {
            $PublishedDockerfiles.ForEach({
                    $Project = $_.DirectoryName
                    Join-Path $script:OutputPath "docker/$Project-metadata.json"
                })
        } else {
            $BuildRoot
        }
    }
<<<<<<<< HEAD:common/DockerBuild.Task.ps1
    Jobs    = "GetVersion", "DotNetPublish", {
|||||||| parent of c4aeb6a (Move Tasks and Update Documentation (#29)):tasks/DotNetDockerBuild.Task.ps1
    Jobs    = "GetVersion", "DotNetPublish", "ConnectAzACR", {
========
    Jobs    = "Get-Version", "Publish-DotNet", "Connect-AzACR", {
>>>>>>>> c4aeb6a (Move Tasks and Update Documentation (#29)):archive/DotNetDockerBuild.Task.ps1
        $script:DockerMetadataRoot = New-Item (Join-Path $script:OutputPath "docker") -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path
        $PublishedDockerfiles = Get-ChildItem $script:DotNetPublishRoot -Recurse -File -Filter "Dockerfile" -ErrorAction SilentlyContinue

        foreach ($Dockerfile in $PublishedDockerfiles) {
            $ProjectName = $DockerFile.Directory.Name
            $Parts = $ProjectName.Split('.')
            $PathPrefix = ($Parts[0..($Parts.Length - 3)] -join '/').ToLower()
            $ImageName  = ($Parts[($Parts.Length - 2)..($Parts.Length - 1)] -join '-').ToLower()
            $Repository = "$PathPrefix/$ImageName"
            $Context = Join-Path $script:DotNetPublishRoot $ProjectName
            $Version = $script:Version.SemVer
            $FullImageName = "$script:ACRUri/$Repository`:$Version"

            $MetadataFile = Join-Path $script:DockerMetadataRoot "$ProjectName-metadata.json"

            $BuildArgs = @(
                "buildx", "build"
                "--rm=true"
                "-f", $Dockerfile
                "-t", $FullImageName
                "--metadata-file", $MetadataFile
            )


            if ($Version.Sha) {
                $BuildArgs += "--label", "org.opencontainers.image.revision=$($Version.Sha)"
            }

            if ($Version.CommitDate) {
                $BuildArgs += "--label", "org.opencontainers.image.created=$($Version.CommitDate)"
            }

            $RepoUrl = if ($Env:BUILD_REPOSITORY_URI) {
                $Env:BUILD_REPOSITORY_URI
            } elseif ($Env:GITHUB_REPOSITORY) {
                "https://github.com/$($Env:GITHUB_REPOSITORY).git"
            } else {
                git config --get remote.origin.url
            }

            if ($RepoUrl) {
                $BuildArgs += "--label", "org.opencontainers.image.source=$RepoUrl"
                $RepoUrlWithoutGit = $RepoUrl -replace '\.git$', ''
                $BuildArgs += "--label", "org.opencontainers.image.url=$RepoUrlWithoutGit"
            }

            if ($dockerProject.Labels) {
                foreach ($label in $dockerProject.Labels.GetEnumerator()) {
                    $BuildArgs += "--label", "$($label.Key)=$($label.Value)"
                }
            }

            if ($dockerProject.BuildArgs) {
                foreach ($arg in $dockerProject.BuildArgs.GetEnumerator()) {
                    $BuildArgs += "--build-arg", "$($arg.Key)=$($arg.Value)"
                }
            }

            $BuildArgs += $Context

            Write-Build Cyan "Building Docker image: $FullImageName"
            Write-Build Yellow "docker $($BuildArgs -join ' ')"

            & docker @BuildArgs
        }
    }
}
