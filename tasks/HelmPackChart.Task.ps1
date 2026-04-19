Add-BuildTask HelmPackChart @{
    If      = ($script:ChartName)
    Inputs  = { Get-ChildItem $script:HelmCharts -File -Recurse }
    Outputs = {
        foreach ($Chart in $script:HelmCharts) {
            Join-Path $Chart.FullName "$($Chart.Name)-$($script:Version.SemVer).tgz"
        }
    }
    Jobs    = "GetVersion", {
        foreach ($Chart in $script:HelmCharts) {
            $Destination = Join-Path $script:helmOutputPath $Chart.Name
            New-Item $Destination -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            $options = @(
                "--destination", $Destination,
                "--version", $script:Version.SemVer,
                "--app-version", $script:Version.SemVer
            )
            Write-Build Yellow "helm package $($Chart.FullName) $($options -join ' ')"
            helm package $Chart.FullName @options
        }
    }
}
