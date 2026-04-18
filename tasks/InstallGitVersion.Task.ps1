# This exist for repos that don't have a dotnettools.json file
Add-BuildTask InstallGitVersion @{
    Jobs = "DotNetToolRestore", {
        # If there's no local gitversion tool, always update|install the global one
        if (!((dotnet tool list GitVersion.Tool --format json | ConvertFrom-Json).data)) {
            $ENV:PATH += ([IO.Path]::PathSeparator) + (Convert-Path ~/.dotnet/tools)
            dotnet tool update GitVersion.Tool --global --version 6.* --verbosity diagnostic
        }
    }
}