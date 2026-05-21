<#
.SYNOPSIS
    PowerShell module build script -- extends common base with PowerShell module build support.
.DESCRIPTION
    Extends common base to provide PowerShell module build, test, analysis, and publishing.
.EXAMPLE
    Invoke-Build
#>
[CmdletBinding()]
param(
    [ValidateScript({ "../common/base.ps1" })]
    $Extends,

    # Name of the PowerShell module (defaults to the directory/project name)
    [string]$ModuleName = $Env:IB_MODULE_NAME,

    # NuGet-compatible publish URI for the PS module repository
    [string]$PSPublishUri = ($Env:IB_PS_PUBLISH_URI ?? "https://www.powershellgallery.com/api/v2/package/"),

    # API key for publishing to the PS module repository
    [string]$PSPublishKey = $Env:IB_PS_PUBLISH_KEY,

    # Pester filter hashtable (Tag, ExcludeTag, etc.)
    $PesterFilter,

    # Skip code coverage measurement
    [switch]$SkipCoverage
)

# Redirect $BuildRoot to the consuming project's directory
if ($BuildRoots.Count -gt 1) {
    $BuildRoot = $BuildRoots[-1]
}

Enter-Build {
    # Default ModuleName to the project folder name
    if (-not $script:ModuleName) {
        $script:ModuleName = Split-Path $BuildRoot -Leaf
    }

    $script:ModuleOutputRoot = Join-Path $script:OutputRoot $script:ModuleName
    New-Item -Type Directory -Path $script:ModuleOutputRoot -Force | Out-Null
    $script:PSPackageRoot = Join-Path $script:OutputRoot pspkg
    New-Item -Type Directory -Path $script:PSPackageRoot -Force | Out-Null
    $script:ModuleTestResultsRoot = Join-Path $Script:TestResultsRoot $script:ModuleName
    New-Item -Type Directory -Path $script:ModuleTestResultsRoot -Force | Out-Null
    $script:ManifestPath = Join-Path $script:ModuleOutputRoot "$script:ModuleName.psd1"

    Write-Build Cyan "  ModuleName: $script:ModuleName"
    Write-Build Cyan "  ModuleOutputRoot: $script:ModuleOutputRoot"

    $script:SourcePath ??= (Join-Path $BuildRoot src), (Join-Path $BuildRoot source), (Join-Path $BuildRoot $script:ModuleName) |
        Convert-Path -ErrorAction Ignore | Select-Object -First 1
}

# Add the PowerShell tasks to the common tasks
$script:InitializeTasks += @()

# When we have dotnet combined in a PowerShell module
# We need to Build-Module AFTER Publish-DotNet
# So that we can include the output assemblies in the module
$script:BuildTasks += $BuildTasks -contains "Build-DotNet" ?
                    @("Publish-DotNet", "Build-Module") :
                    @("Build-Module")
$script:PackTasks += @("Pack-Module")
$script:TestTasks += @("Import-Module", "Test-PowerShell", "Test-PowerShellSyntax")
$script:PushTasks += @("Push-Module")
$script:CheckpointTasks += @()

foreach ($taskfile in Get-ChildItem -Path $PSScriptRoot -Filter *.Task.ps1) {
    # Write-Information "$($PSStyle.Foreground.BrightBlue)    $($taskfile.FullName)$($PSStyle.Reset)"
    . $taskfile.FullName
}