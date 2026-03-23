Add-BuildTask HelmPushChart @{
    If   = ($script:HelmCharts)
    Jobs = "HelmPackChart", "ConnectAzACR", {
        if ($script:PushEnabled) {
            foreach ($Chart in $script:HelmCharts) {
                # If this sort turns out to not be enough, we need to split the name and cast to [semver] to sort
                $ChartToPush = Get-ChildItem (Join-Path $script:helmOutputPath $Chart.Name) -Filter *.tgz | Sort-Object LastWriteTime | Select-Object -Last 1
                Write-Build Yellow "helm push $($ChartToPush.FullName) oci://$($script:ACRName).azurecr.io/helm"
                Invoke-Native { helm push $ChartToPush.FullName "oci://$($script:ACRName).azurecr.io/helm" } -ExceptionalExit
            }
        } else {
            Write-Warning ("Skipping push: To push charts ensure that...`n" +
                "`t* You are in a known build system (Current: $BuildSystem)`n" +
                "`t* You are committing to the main or release or hotfix branch (Current: $BranchName) `n")
        }
    }
}
