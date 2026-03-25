Add-BuildTask Build-Helm @{
    # TODO: This desparately needs working inputs/outputs
    jobs = "Restore-Helm", {
        foreach ($Chart in $script:HelmCharts) {
            Set-Location $Chart
            Write-Build Yellow "helm schema"
            Invoke-Native { helm schema } -ExceptionalExit
        }
    }
}
