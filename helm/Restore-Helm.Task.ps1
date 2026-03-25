Add-BuildTask Restore-Helm @{
    jobs = "Install-Helm", "Connect-AzACR", {
        foreach ($Chart in $script:HelmCharts) {
            Set-Location $Chart
            # If the developers have not already done so
            # This may create a `charts` subdirectory with the dependencies i.e. devops-library
            # In general, we don't care if they commit those, but we need them for the schemas to be complete
            Write-Build Yellow "helm dependency build $Chart"
            Invoke-Native { helm dependency build . } -ExceptionalExit
        }
    }
}
