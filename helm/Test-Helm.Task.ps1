Add-BuildTask Test-Helm @{
    Inputs  = { Get-ChildItem $script:HelmCharts -File -Recurse }
    Outputs = {
        foreach ($chart in $script:HelmCharts) {
            Join-Path $script:HelmOutputRoot "$($Chart.Name)-compiled.yaml"
        }
    }
    Jobs    = {
        # helm lint requires the chart directory, not the chart.yaml file
        Set-Location $script:HelmChartRoot
        New-Item $script:HelmOutputRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        # each $chart is a directory object
        foreach ($chart in $script:HelmCharts) {
            $TestValues = Join-Path $chart values.yaml
            $CompiledOutput = Join-Path $script:HelmOutputRoot "$($Chart.Name)-compiled.yaml"

            Write-Build Yellow "helm lint $($Chart.FullName) --values $TestValues"
            Invoke-Native { helm lint $chart.FullName --values $TestValues } -ExceptionalExit

            Write-Build Yellow "helm template $($chart.FullName) --values $TestValues --generate-name"
            Invoke-Native { helm template $chart.FullName --values $TestValues --generate-name } -ExceptionalExit > $CompiledOutput

            # Shouldn't this be taken care of elsewhere as a pre-requisite?
            if (-not (Get-Command kubeconform -ErrorAction SilentlyContinue)) {
                Write-Build Yellow "kubeconform not found, attempting installation..."
                &(Join-Path $script:BuildTasksRoot "scripts" "Install-FromGitHub.ps1") -Org "yannh" -Repo "kubeconform" -Verbose -ErrorAction SilentlyContinue
            }

            Write-Build Yellow "kubeconform -strict -ignore-missing-schemas -schema-location default -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' "-verbose" -output pretty $CompiledOutput"
            Invoke-Native {
                kubeconform -strict -ignore-missing-schemas -schema-location default -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' "-verbose" -output pretty $CompiledOutput
            } -ExceptionalExit
        }
    }
}
