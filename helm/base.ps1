<#
.SYNOPSIS
    Helm build script -- extends common base with Helm chart support.
.EXAMPLE
    Invoke-Build
#>
[CmdletBinding()]
param(
    [ValidateScript({ "../common/base.ps1" })]
    $Extends,

    # Path to the Helm charts directory -- defaults to $BuildRoot/charts
    [string]$HelmChartRoot,

    # Build specific charts by name, e.g. -ChartName "macpublicservice"
    [string[]]$ChartName,

    [string]$ACRName = ($ENV:IB_ACR_NAME ?? "crazusw2dvosl1"),

    [string]$HelmRepository = ($Env:IB_HELM_REPOSITORY ?? "oci://$ACRName.azurecr.io/helm")

)

# Redirect $BuildRoot to the derived (root) script's directory
if ($BuildRoots.Count -gt 1) {
    $BuildRoot = $BuildRoots[-1]
}

#region Helm task variables -- initialized in Enter-Build (runs only when actually building)
Enter-Build {
    # Resolve $HelmChartRoot -- default to $BuildRoot/charts if not specified
    if (-not $HelmChartRoot) { $HelmChartRoot = Join-Path $BuildRoot "charts" }
    $script:HelmChartRoot = if (Test-Path $HelmChartRoot) { Convert-Path $HelmChartRoot }

    if ($script:HelmChartRoot) {
        $script:HelmOutputRoot = Join-Path $Script:OutputRoot "charts"
        $script:ChartName ??= Get-ChildItem -Path $script:HelmChartRoot -File -Filter Chart.yaml -Recurse -Depth 1 | ForEach-Object { $_.Directory.Name }
        $script:HelmCharts = $script:ChartName | Join-Path -Path $script:HelmChartRoot -ChildPath { $_ } | Get-Item
        $script:GHTools.add("kubeconform", "https://github.com/yannh/kubeconform/releases/tag/v0.7.0")

        Write-Build Cyan "Initializing Helm task variables (HelmChartRoot: $script:HelmChartRoot)"
        Write-Build Cyan "  HelmChartRoot: $script:HelmChartRoot"
        Write-Build Cyan "  HelmOutputRoot: $script:HelmOutputRoot"
        Write-Build Cyan "  HelmCharts: $(($script:HelmCharts).Count)"
        Write-Build Cyan "  HelmRepository: $script:HelmRepository"
    }
}
#endregion


# Add the helm tasks to the common tasks
$script:InitializeTasks += @("Install-Helm", "Restore-Helm")
$script:BuildTasks += @("Build-Helm")
$script:PackTasks += @("Package-Helm")
$script:TestTasks += @("Test-Helm")
$script:PushTasks += @("Push-Helm")
$script:CheckpointTasks += @()

foreach ($taskfile in Get-ChildItem -Path $PSScriptRoot -Filter *.Task.ps1) {
    # Write-Information "$($PSStyle.Foreground.BrightBlue)    $($taskfile.FullName)$($PSStyle.Reset)"
    . $taskfile.FullName
}