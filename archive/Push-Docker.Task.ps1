Add-BuildTask Push-Docker @{
    # TODO: This should NOT be using metadata files
    # TODO: This should work against GHCR (GitHub Container Registry), not require ACR
    If      = { $ACRName -and $ACRUri }
    Inputs  = {
        # Docker metadata files created by DockerBuild task
        $MetadataFiles = Get-ChildItem (Join-Path $script:OutputRoot "docker") -Filter "*-metadata.json" -ErrorAction SilentlyContinue
        if ($MetadataFiles) {
            $MetadataFiles.FullName
        }
        else {
            $BuildRoot
        }
    }
    Outputs = {
        # Create a marker file for each pushed image
        $MetadataFiles = Get-ChildItem (Join-Path $script:OutputRoot "docker") -Filter "*-metadata.json" -ErrorAction SilentlyContinue
        if ($MetadataFiles) {
            $MetadataFiles.ForEach({
                    $ProjectName = $_.BaseName -replace '-metadata$', ''
                    Join-Path $script:OutputRoot "docker/$ProjectName-pushed.txt"
                })
        }
        else {
            $BuildRoot
        }
    }
    Jobs    = "Connect-AzACR", {
        if ($script:PushEnabled) {
            $script:DockerMetadataRoot = Join-Path $script:OutputRoot "docker"

            $MetadataFiles = Get-ChildItem $script:DockerMetadataRoot -Filter "*-metadata.json" -ErrorAction SilentlyContinue

            foreach ($MetadataFile in $MetadataFiles) {
                $ProjectName = $MetadataFile.BaseName -replace '-metadata$', ''
                $Parts = $ProjectName.Split('.')
                $PathPrefix = ($Parts[0..($Parts.Length - 3)] -join '/').ToLower()
                $ImageName  = ($Parts[($Parts.Length - 2)..($Parts.Length - 1)] -join '-').ToLower()
                $Repository = "$PathPrefix/$ImageName"
                $Version = $script:Version.SemVer
                $FullImageName = "$script:ACRUri/$Repository`:$Version"

                Write-Build Yellow "docker push $FullImageName"
                Invoke-Native { docker push $FullImageName } -ExceptionalExit

                # Create marker file to indicate successful push
                $PushedMarker = Join-Path $script:DockerMetadataRoot "$ProjectName-pushed.txt"
                @"
Image: $FullImageName
Pushed: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
Registry: $script:ACRUri
Repository: $Repository
Version: $Version
"@ | Set-Content $PushedMarker
            }
        }
        else {
            Write-Warning ("Skipping push: To push images ensure that...`n" +
                "`t* You are in a known build system (Current: $BuildSystem)`n" +
                "`t* You are committing to the main or release or hotfix branch (Current: $BranchName) `n")
        }
    }
}
