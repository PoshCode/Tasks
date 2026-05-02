# The actual helm command is helm package
# But we alias it as pack and publish for consistency with other frameworks
Add-BuildTask Pack-Helm Package-Helm
Add-BuildTask Publish-Helm Pack-Helm

Add-BuildTask Package-Helm @{
    Inputs  = { Get-ChildItem $script:HelmCharts -File -Recurse }
    Outputs = {
        foreach ($Chart in $script:HelmCharts) {
            Join-Path $Chart.FullName "$($Chart.Name)-$($script:Version.SemVer).tgz"
        }
    }
    Jobs    = "Get-Version", "Test-Helm", {
        foreach ($Chart in $script:HelmCharts) {
            $Destination = Join-Path $script:helmOutputRoot $Chart.Name
            New-Item $Destination -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            $options = @(
                "--destination", $Destination,
                "--version", $script:Version.SemVer,
                "--app-version", $script:Version.SemVer
            )
            Write-Build Yellow "helm package $($Chart.FullName) $($options -join ' ')"
            Invoke-Native { helm package $Chart.FullName @options } -ExceptionalExit
        }
    }
}