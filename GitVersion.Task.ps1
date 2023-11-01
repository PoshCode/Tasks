$Script:GitVersionMessagePrefix ??= "semver"
$Script:GitVersionTagPrefix ??= "v"

Add-BuildTask GitVersion @{
    Inputs  = {
        # Exclude generated source files in /obj/ folders
        Get-ChildItem $BuildRoot -Recurse -File
    }
    Outputs = {
        if ($script:BuildSystem -eq "None") {
            # Locally, we can never skip versioning, because someone could have tagged git
            $BuildRoot
        } else {
            # In the build system, run it ONCE PER BUILD PER PROJECT
            # Use a $TempRoot the build cleans
            foreach ($Name in $PackageNames) {
                if ($PackageNames.Count -gt 1) {
                    $GitVersionMessagePrefix = ($GitVersionMessagePrefix, $Name) -join "-"
                    $GitVersionTagPrefix = ($Name, $GitVersionTagPrefix) -join "-"
                }
                Join-Path $TempRoot -ChildPath "$GitVersionTagPrefix$GitSha.json"
            }
        }
    }
    Jobs    = {
        $script:GitVersionTags = @()
        $script:MultiGitVersion = @{}
        foreach ($Name in $PackageNames) {

            if ($PackageNames.Count -gt 1) {
                $GitVersionMessagePrefix = ($GitVersionMessagePrefix, $Name) -join "-"
                $GitVersionTagPrefix = ($Name, $GitVersionTagPrefix) -join "-"
            }

            # Since we know the things we need to version, let's make *sure* that we version it:
            # Write-Host git commit "--ammend" "-m" "$commitMessage`n$GitVersionMessagePrefix:patch"
            # git commit --ammend -m "$commitMessage`n$GitVersionMessagePrefix:patch"

            $GitVersionYaml = if (Test-Path (Join-Path $BuildRoot GitVersion.yml)) {
                Join-Path $BuildRoot GitVersion.yml
            } else {
                Convert-Path (Join-Path $PSScriptRoot GitVersion.yml)
            }

            Write-Verbose "Using GitVersion config $GitVersionYaml" -Verbose

            $LogFile = Join-Path $TempRoot -ChildPath "$GitVersionTagPrefix$GitSha.log"
            if (Test-Path $LogFile) {
                Remove-Item $LogFile
            }
            $VersionFile = Join-Path $TempRoot -ChildPath "$GitVersionTagPrefix$GitSha.json"
            if (Test-Path $VersionFile) {
                Remove-Item $VersionFile
            }

            # We can't splat because it's 5 copies of the same parameter, so, use line-wrapping escapes:
            # Also, the no-bump-message has to stay at .* or else every commit to main will increment all components
            # Write-Host dotnet gitversion -config $GitVersionYaml -output file -outputfile $VersionFile -verbosity verbose
            <# -output file -outputfile $VersionFile #>
            dotnet gitversion -verbosity diagnostic -config $GitVersionYaml `
                -overrideconfig tag-prefix="$($GitVersionTagPrefix)" `
                -overrideconfig major-version-bump-message="$($GitVersionMessagePrefix):\s*(breaking|major)" `
                -overrideconfig minor-version-bump-message="$($GitVersionMessagePrefix):\s*(feature|minor)" `
                -overrideconfig patch-version-bump-message="$($GitVersionMessagePrefix):\s*(fix|patch)" `
                -overrideconfig no-bump-message="$($GitVersionMessagePrefix):\s*(skip|none)" > $VersionFile 2> $LogFile

            if (Test-Path $LogFile) {
                Write-Host $PSStyle.Formatting.Error ((Get-Content $LogFile) -join "`n") $PSStyle.Reset
            }

            if (!(Test-Path $VersionFile)) {
                throw "GitVersion failed to produce a version file or a log file"
            } else {
                Get-Content $VersionFile | Out-Host
                $GitVersion = Get-Content $VersionFile | ConvertFrom-Json
            }

            Set-Variable "GitVersion.$Name" $GitVersion -Scope Script
            $MultiGitVersion.$Name = $GitVersion

            # Output for Azure DevOps
            if ($ENV:SYSTEM_COLLECTIONURI) {
                foreach ($envar in $GitVersion.PSObject.Properties) {
                    $EnvVarName = if ($Name) {
                        @($Name, $Envar.Name) -join "."
                    } else {
                        $Envar.Name
                    }
                    Write-Host "INFO [task.setvariable variable=$EnvVarName;isOutput=true]$($envar.Value)"
                    Write-Host "##vso[task.setvariable variable=$EnvVarName;isOutput=true]$($envar.Value)"
                }
            } else {
                Write-Host "GitVersion: $($GitVersion.InformationalVersion)"
            }
            # Output the expected tag
            $GitVersionTagPrefix + $GitVersion.SemVer
        }

        $MultiGitVersion | ConvertTo-Json | Set-Content $VersionFile

        # Output for Azure DevOps
        if ($ENV:SYSTEM_COLLECTIONURI) {
            $OFS = " "
            Write-Host "INFO [task.setvariable variable=Tag;isOutput=true]$GitVersionTags"
            Write-Host "##vso[task.setvariable variable=Tag;isOutput=true]$GitVersionTags"
        }
    }
}
