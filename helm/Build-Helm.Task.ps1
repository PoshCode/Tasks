Add-BuildTask Build-Helm @{
    # TODO: This desparately needs working inputs/outputs
    jobs = "Restore-Helm", {
        foreach ($Chart in $script:HelmCharts) {
            Set-Location $Chart
            Write-Build Yellow "helm schema"
            if ('schema' -in (helm plugin list | ForEach-Object { ($_ -split '\t')[0] })) {
                Invoke-Native { helm schema } -ExceptionalExit
            } elseif (Get-Command 'helm-schema' -ErrorAction Ignore) {
                Invoke-Native { helm-schema } -ExceptionalExit
            } else {
                Write-Error "helm schema plugin not found, can't update values-schema.json files"
            }
        }
    }
}
