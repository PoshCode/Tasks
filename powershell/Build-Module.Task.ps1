Add-BuildTask Build-Module @{
    Inputs  = {
        @(
            Get-ChildItem -Path $BuildRoot -Recurse -Filter *.ps*
            Get-ChildItem -Path $BuildRoot -Recurse -Filter *.cs | Where-Object FullName -NotLike "*/obj/*"
        ) | Where-Object FullName -NotLike (Join-Path $script:OutputRoot /*)
    }
    # don't take off the script block, need to resolve AFTER init
    Outputs = {
        $InputObject = $_
        switch -regex ("$InputObject") {
            "ps1$" {
                $script:ModuleOutputRoot
            }
            "cs$" {
                if ($out -and ($Assemblies = Get-ChildItem -Path $script:OutputRoot -Recurse -Filter *.dll -ErrorAction Ignore)) {
                    $Assemblies
                } else {
                    Join-Path $script:ModuleOutputRoot lib
                }
            }
            default {
                # .psd1, .psm1, .pssc etc — use the output directory as the comparison target
                $script:OutputRoot
            }
        }
    }
    Jobs    = "Install-PowerShellModule", "Get-Version", {
        $version = @{
            # We need a PowerShellGallery / PSGet compatible version with only digits in the version, and only alphanumerics in the pre-release
            # This pattern anticipates SemVer v2 versions like:
            # 0.1.31-ldd-0123.14+Build.34865.Branch.joelbennett-gitversion.Sha.4c49c2650396e41efe0d491894a88cc3954b0ee9.Date.20211122T222522
            # 1.0.1+Branch.testing.Sha.4c49c2650396e41efe0d491894a88cc3954b0ee9
            semver = [regex]::replace($script:Version.InformationalVersion, "(?<version>\d+\.\d+\.\d+)(?:-(?<prerelease>[^+]*)\.(?<digit>\d+))?\+(?<metadata>.*)$", {
                    $g = $args[0].Groups
                    if ($g['prerelease'].Value) {
                        # If the Prerelease ends in digits, add a 'c' to separate the commit count
                        '{0}-{1}{2:d4}+{3}' -f $g['version'], ($g['prerelease'] -replace '[^a-zA-Z0-9]' -replace '(?<=\d)$', 'c'), ('{0:d4}' -f ([int]$g['digit'].value)), $g['metadata']
                    } else {
                        '{0}+{1}' -f $g['version'], $g['metadata']
                    }
                })
        }

        $Module = Build-Module -Output $script:OutputRoot -UnversionedOutputDirectory @version -Passthru -Verbose:($VerbosePreference -eq "Continue")

        # If there's output from a DotNetPublish task, copy it into a "lib" folder in the module output
        if ($DotNetPublishRoot -and (Test-Path $DotNetPublishRoot)) {
            $Libraries = New-Item (Join-Path $Module.ModuleBase lib) -Type Directory -Force | Convert-Path
            Write-Build Yellow "Copying dotnet publish output from $DotNetPublishRoot to module lib $Libraries"
            Get-ChildItem $DotNetPublishRoot -Filter *.dll -Recurse -ErrorAction Ignore
            | Where-Object { $_.BaseName -notmatch "System.*" -and $_.Extension -notin ".nupkg" }
            | Copy-Item -Destination $Libraries -Recurse
        } else {
            Write-Build Yellow "No assemblies to copy $DotNetPublishRoot"
        }

        $script:ModuleName = $Module.Name
        $script:ManifestPath = $Module.Path
        $script:ModuleOutputRoot = Split-Path $Module.Path
    }
}
