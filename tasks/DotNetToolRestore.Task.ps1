Add-BuildTask DotNetToolRestore @{
    Jobs = {
        $DotNetToolManifest = @(
            Join-Path $BuildRoot .config/dotnet-tools.json
            Join-Path $BuildRoot dotnet-tools.json
        ) | Resolve-Path -ErrorAction Ignore | Select-Object -First 1
        if (-not $DotNetToolManifest) {
            Copy-Item "$PSScriptRoot/../dotnet-tools.json" "$BuildRoot/.config/dotnet-tools.json" -Force 
        }
        dotnet tool restore
    }
}
