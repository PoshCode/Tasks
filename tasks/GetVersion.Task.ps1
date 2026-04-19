$script:VersionCacheFile = "$Script:OutputPath/version.json"
$script:Version = @{}

<# NOTE: this version does not include support for multiple versions per-repo  #>
Add-BuildTask GetVersion @{
    If   = {
        $head = git rev-parse HEAD
        # If there's an existing GitVersion in output, load it
        if (${script:Version}.Sha -ne $head) {
            ${script:Version} = if (Test-Path $Script:OutputPath/version.json) {
                Get-Content $Script:OutputPath/version.json | ConvertFrom-Json
            }
        }
        # Skip if ${script:Version} is set correctly for this commit...
        # we can skip (return $false)
        return (${script:Version}.Sha -ne $head)
    }
    Jobs = "GitInit", "DotNetToolRestore", {
        # Support a config file in the repo (BuildRoot) to override the one in here (PSScriptRoot)
        [string]$VersionConfig = Resolve-Path "$BuildRoot/GitVersion.y*ml", "$PSScriptRoot/GitVersion.y*ml" -ErrorAction Ignore
        | Select-Object -First 1

        # agent temp SHOULD be cleaned after each pipeline job
        $VersionCacheFile = "$TempDirectory/version.json"

        # Delete the VersionCache so that importing it will fail if gitversion fails
        if (Test-Path $VersionCacheFile) {
            Remove-Item $VersionCacheFile
        }

        Write-Host dotnet gitversion -config $VersionConfig -nofetch -output file -outputfile $VersionCacheFile
        dotnet gitversion -config $VersionConfig -nofetch -output file -outputfile $VersionCacheFile | Out-Host

        try {
            $local:GitVersion = Get-Content $VersionCacheFile | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Warning "dotnet gitversion -config $VersionConfig -showconfig"
            dotnet gitversion -config $VersionConfig -showconfig | Out-Host
            Write-Warning "VersionTagPrefix: $($VersionTagPrefix)"
            Write-Warning "VersionMessagePrefix: $($VersionMessagePrefix)"
            Write-Warning 'git log --graph --format="%h %cr %d" --decorate --date=relative --all --remotes=* -n 100'
            git log --graph --format="%h %cr %d" --decorate --date=relative --all --remotes=* -n 100 | Out-Host
            Write-Host $VersionCacheFile
            throw $_
        }

        $local:GitVersion | Add-Member -MemberType NoteProperty -Name Tag -Value (($VersionTagPrefix -replace "\[Vv]\?", "v") + $local:GitVersion.SemVer)

        # The things we know we want on our version output object
        $script:Version = $local:GitVersion |
            Select-Object -Property InformationalVersion, MajorMinorPatch, SemVer, Sha, Tag


        # Cache the final object in output so we can skip rerunning
        ${script:Version} | ConvertTo-Json -Compress | Out-File $Script:OutputPath/version.json
    }
}
