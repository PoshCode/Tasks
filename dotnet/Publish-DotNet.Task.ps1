Add-BuildTask Publish-DotNet @{
    Inputs  = {
        $DotNetProjects.Where({ $_.IsPublishable }).ForEach({ Join-Path $_.OutDir $_.TargetFileName })
    }
    Outputs = {
        $DotNetProjects.Where({ $_.IsPublishable }).ForEach({ Join-Path $_.PublishDir $_.TargetFileName })
    }
    Jobs    = "Build-DotNet", "Pack-DotNet", {
        $script:DotNetPublishRoot = New-Item $script:DotNetPublishRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path

        $local:options = @{} + $script:dotnetOptions
        $options["p"] = "Version=$(${script:Version}.InformationalVersion)"

        Set-Location (Split-Path $DotNetSolutionFile)
        Write-Build Yellow "dotnet publish $DotNetSolutionFile --no-build --no-restore $(($options.GetEnumerator().ForEach({"-$($_.key) $($_.value)"})) -join ' ')"
        dotnet publish $DotNetSolutionFile --no-build --no-restore @options
    }
}
