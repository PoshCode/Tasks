Add-BuildTask HelmUpdateValuesSchema @{
    if   = ($script:HelmCharts)
    # TODO: This desparately needs working inputs/outputs
    jobs = "HelmInstall", "InstallGithubTools", "ConnectAzACR", {
        foreach ($Chart in $script:HelmCharts) {
            Set-Location $Chart
            Write-Build Yellow "helm dependency update $Chart"
            # If the developers have not already done so
            # This may create a `charts` subdirectory with the dependencies i.e. devops-library
            # In general, we don't care if they commit those, but we need them for the schemas to be complete
            Invoke-Native { helm dependency update . --skip-refresh }
            Write-Build Yellow "helm schema"
            Invoke-Native { helm schema }
        }
    }
}
