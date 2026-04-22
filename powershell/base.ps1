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
    [string]$ModuleName,

    # Name of the PSRepository to publish to
    [string]$PSRepository = "DevOpsPowerShell",

    # NuGet-compatible publish URI for the PS module repository
    [string]$PowerShellModulePublishUri,

    # API key for publishing to the PS module repository
    [string]$PowerShellModulePublishKey,

    # Pester filter hashtable (Tag, ExcludeTag, etc.)
    $PesterFilter,

    # Skip code coverage measurement
    [switch]$SkipCoverage
)

# Redirect $BuildRoot to the consuming project's directory
if ($BuildRoots.Count -gt 1) {
    $BuildRoot = $BuildRoots[-1]
}

# Assign params to script scope early -- task If conditions evaluate at definition time
$script:ModuleName ??= $ModuleName
$script:PSRepository ??= $PSRepository

Enter-Build {
    # Resolve credentials and repository from environment if not passed as parameters
    $script:PSRepository = Get-Content Variable:PSRepository, Env:PSREPOSITORY -ErrorAction Ignore |
        Select-Object -First 1
    if (-not $script:PSRepository) { $script:PSRepository = "DevOpsPowerShell" }

    $script:PowerShellModulePublishUri = Get-Content Variable:PowerShellModulePublishUri,
    Env:IB_PS_PUBLISH_URI -ErrorAction Ignore |
        Select-Object -First 1

    $script:PowerShellModulePublishKey = Get-Content Variable:PowerShellModulePublishKey,
    Env:IB_PS_PUBLISH_KEY -ErrorAction Ignore |
        Select-Object -First 1

    # Default ModuleName to the project folder name
    if (-not $script:ModuleName) {
        $script:ModuleName = Split-Path $BuildRoot -Leaf
    }

    $script:ModuleOutputPath = Join-Path $script:OutputPath $script:ModuleName
    $script:ManifestPath = Join-Path $script:ModuleOutputPath "$script:ModuleName.psd1"
    $script:ModuleTestResultsRoot = Join-Path $Script:TestResultsRoot $script:ModuleName
    New-Item -Type Directory -Path $script:ModuleTestResultsRoot -Force | Out-Null

    Write-Build Cyan "  ModuleName   [$script:ModuleName]"
    Write-Build Cyan "  ModuleOutputPath   [$script:ModuleOutputPath]"

    $script:SourcePath ??= (Join-Path $BuildRoot src), (Join-Path $BuildRoot source), (Join-Path $BuildRoot $script:ModuleName) |
        Convert-Path -ErrorAction Ignore | Select-Object -First 1

    Write-Build Cyan "  PSRepository [$script:PSRepository]"

    # Register PSRepository if a publish URI is provided and it isn't already registered correctly
    if ($script:PowerShellModulePublishUri -and $script:PSRepository) {
        $existing = Get-PSRepository -Name $script:PSRepository -ErrorAction Ignore
        if (-not $existing -or $existing.PublishLocation -ne $script:PowerShellModulePublishUri) {
            if ($existing) { Unregister-PSRepository -Name $script:PSRepository }
            Register-PSRepository -Name $script:PSRepository `
                -SourceLocation $script:PowerShellModulePublishUri `
                -PublishLocation $script:PowerShellModulePublishUri `
                -InstallationPolicy Trusted
        }
    }
}

# Add the dotnet tasks to the common tasks
$script:InitializeTasks = @(
    # In CI pipelines (or if you specify $Clean)
    if ($BuildSystem -ne "None" -or $Script:Clean) {
        # Run the Clean-Output task before the rest of the build tasks
        "Clean-Output"
    }
) + $InitializeTasks

$script:BuildTasks += @("Build-Module")
# TODO: Need to separate package & push
$script:PublishTasks += @()
$script:TestTasks += @("Import-Module", "Test-PowerShell", "Test-PowerShellSyntax")
$script:PushTasks += @("Publish-Module")
$script:CheckpointTasks += @()

foreach ($taskfile in Get-ChildItem -Path $PSScriptRoot -Filter *.Task.ps1) {
    # Write-Information "$($PSStyle.Foreground.BrightBlue)    $($taskfile.FullName)$($PSStyle.Reset)"
    . $taskfile.FullName
}