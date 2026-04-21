<#
.SYNOPSIS
    Restore dotnet tools specified in the manifest file.
.DESCRIPTION
    We use a few core dotnet tools as part of every build. Therefore, if there is no dotnet-tools.json manifest file in your repository, one will be copied from the BuildTasks repo.

    Then `dotnet tool restore` will be run to ensure the tools are installed.
#>
Add-BuildTask Install-DotNetTool @{
    Jobs = {
        $DotNetToolManifest = @(
            Join-Path $BuildRoot .config/dotnet-tools.json
            Join-Path $BuildRoot dotnet-tools.json
        ) | Resolve-Path -ErrorAction Ignore | Select-Object -First 1
        if (-not $DotNetToolManifest) {
            New-Item -ItemType Directory -Path "$BuildRoot/.config" -Force -ErrorAction Ignore
            Copy-Item "$PSScriptRoot/../dotnet-tools.json" "$BuildRoot/.config/dotnet-tools.json" -Force
        }
        dotnet tool restore
    }
}
