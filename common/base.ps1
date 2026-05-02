#Requires -PSEdition Core

<#
.SYNOPSIS
    Base build script -- core initialization shared by all build types.
.DESCRIPTION
    Provides shared parameters, bootstrapping, environment detection,
    output path setup, and .Task.ps1 imports. Not intended to be invoked
    directly -- use build.dotnet.ps1 or build.helm.ps1 (or both via Extends).
.NOTES
    0.6.0 - Split from build.example.ps1
#>
[CmdletBinding()]
param(
    # Add the clean task before the default build
    [switch]$Clean,

    # Default to collecting code coverage when tests are run
    [switch]$SkipCoverage,

    # The base goal is 85% code coverage
    $PassingCodeCoverage = 0.85
)

## Guard against double-initialization in diamond inheritance
## (e.g. a project extends both dotnet.ps1 and helm.ps1)
if ($script:_BuildBaseInitialized) { return }
$script:_BuildBaseInitialized = $true

## When used via Extends, redirect $BuildRoot to the derived (root) script's directory.
## This ensures all initialization below uses the project's paths, not the base script's.
## See: https://github.com/nightroman/Invoke-Build/blob/main/Tasks/Extends/README.md#build-roots
if ($BuildRoots.Count -gt 1) {
    $BuildRoot = $BuildRoots[-1]
}
$script:BuildTasksRoot = "$PSScriptRoot/.." | Convert-Path

Write-Information "$($PSStyle.Foreground.BrightBlue)Initializing task variables$($PSStyle.Reset)"

# Common PowerShell Formatting Options
$script:ErrorView = "DetailedView"
$script:InformationPreference = "Continue"
$script:ErrorActionPreference = "Stop"
$PSStyle.OutputRendering = "ANSI"
# We're going to treat "DIAGNOSTIC" as "VERBOSE" + "DEBUG" and hope it rarely happens! ;)
if ($ENV:AGENT_DIAGNOSTIC -eq 'True' -or $ENV:SYSTEM_DEBUG -eq 'True') {
    $script:VerbosePreference = "Continue"
    $script:DebugPreference = "Continue"

    Get-ChildItem Env:* | ForEach-Object {
        Write-Information "$($PSStyle.Foreground.BrightBlue)  Env:$($_.Name) = $($_.Value)$($PSStyle.Reset)"
    }
}

# Force distinct colors for Verbose and Debug
if ($PSStyle.Formatting.Verbose -eq $PSStyle.Formatting.Warning) {
    $PSStyle.Formatting.Verbose = $PSStyle.Foreground.BrightCyan
}
if ($PSStyle.Formatting.Debug -eq $PSStyle.Formatting.Warning) {
    $PSStyle.Formatting.Debug = $PSStyle.Foreground.BrightGreen
}

# NOTE: this variable is currently also used for Pester formatting ...
# We should use either "Harness", "AzureDevOps", "GithubActions", or "None"
$script:BuildSystem = if (Test-Path Env:HARNESS_STAGE_ID) {
    "Harness"
} elseif (Test-Path Env:GITHUB_ACTIONS) {
    "GithubActions"
} elseif (Test-Path Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI) {
    "AzureDevops"
} elseif (Test-Path Env:EARTHLY_BUILD_SHA) {
    "Earthly"
} else {
    "None"
}

Write-Information "$($PSStyle.Foreground.BrightBlue)  BuildSystem: $BuildSystem$($PSStyle.Reset)"
Write-Information "$($PSStyle.Foreground.BrightBlue)  Information: $InformationPreference$($PSStyle.Reset)"
Write-Information "$($PSStyle.Foreground.BrightBlue)  Verbose: $VerbosePreference$($PSStyle.Reset)"
Write-Information "$($PSStyle.Foreground.BrightBlue)  Debug: $DebugPreference$($PSStyle.Reset)"

# A little extra BuildEnvironment magic
Set-BuildHeader { Write-Build 11 "Start Task: $($args[0])" }
Set-BuildFooter { Write-Build 11 "Finish Task: $($args[0]) $($Task.Elapsed) [Total: $([DateTime]::Now - ${*}.Started)]" }


# Cross-platform separator character
${script:/} = [IO.Path]::DirectorySeparatorChar

# BuildRoot is provided by Invoke-Build
Write-Information "$($PSStyle.Foreground.BrightBlue)  BuildRoot: $BuildRoot$($PSStyle.Reset)"

# Enter-Build runs only when actually building (not during ??, ?, or WhatIf).
# Each script in the Extends tree gets its own Enter-Build invoked with its $BuildRoot.
Enter-Build {
    # In CI builds you have a BranchName
    $script:BranchName = $Env:BUILD_SOURCEBRANCHNAME ?? $Env:EARTHLY_GIT_BRANCH ?? $(
        if ((Test-Path ".git") -and (Get-Command git -CommandType Application -ErrorAction Ignore)) {
            git branch --show-current
        }
    ) ?? "dirty"

    <# ? None of this information is being used except to print it out here...
    [bool]$script:IsPullRequest = $script:IsPullRequest ?? ($Env:BUILD_REASON -eq "PullRequest" -or $Env:DRONE_BUILD_EVENT -eq "pull_request")
    [long]$script:PullRequestId = $script:PullRequestId ?? $Env:SYSTEM_PULLREQUEST_PULLREQUESTID ?? $Env:DRONE_PULL_REQUEST
    [string]$script:SourceBranch = $script:SourceBranch ?? $Env:SYSTEM_PULLREQUEST_SOURCEBRANCH ?? $Env:BUILD_SOURCEBRANCH ?? $Env:DRONE_SOURCE_BRANCH ?? $Env:CI_COMMIT_BRANCH ?? $script:BranchName
    [string]$script:TargetBranch = $script:TargetBranch ?? $ENV:SYSTEM_PULLREQUEST_TARGETBRANCH ?? $Env:DRONE_TARGET_BRANCH ?? $script:MainBranch
    [string]$script:ProductName = $script:ProductName ?? $Env:PRODUCT_NAME ?? $Env:PIPELINE_NAME ?? $Env:DRONE_REPO_NAME ?? $Env:CI_REPO
    [string]$script:PipelineId = $script:PipelineId ?? $Env:PIPELINE_ID ?? $Env:HARNESS_PIPELINE_ID ?? $Env:PLUGIN_PIPELINE ?? "local build"
    [string]$script:PipelineExecutionId = $script:PipelineExecutionId ?? $Env:PIPELINE_EXECUTION_ID ?? $Env:BUILD_ID ?? $Env:HARNESS_EXECUTION_ID ?? $Env:HARNESS_BUILD_ID ?? $Env:DRONE_BUILD_NUMBER ?? "0"

    Write-Information "$($PSStyle.Foreground.BrightBlue)  BranchName: $BranchName$($PSStyle.Reset)"
    Write-Information "$($PSStyle.Foreground.BrightBlue)  IsPullRequest: $IsPullRequest$($PSStyle.Reset)"
    if ($IsPullRequest) {
        Write-Information "$($PSStyle.Foreground.BrightBlue)  PullRequestId: $PullRequestId$($PSStyle.Reset)"
        Write-Information "$($PSStyle.Foreground.BrightBlue)  SourceBranch: $SourceBranch$($PSStyle.Reset)"
        Write-Information "$($PSStyle.Foreground.BrightBlue)  TargetBranch: $TargetBranch$($PSStyle.Reset)"
    }
    if ($BuildSystem -ne "None") {
        Write-Information "$($PSStyle.Foreground.BrightBlue)  ProductName: $ProductName$($PSStyle.Reset)"
        Write-Information "$($PSStyle.Foreground.BrightBlue)  PipelineId: $PipelineId$($PSStyle.Reset)"
        Write-Information "$($PSStyle.Foreground.BrightBlue)  PipelineExecutionId: $PipelineExecutionId$($PSStyle.Reset)"
    }
    #>

    #?# Note about Azure Pipeline environment variables:
    # $Env:PIPELINE_WORKSPACE      - Defaults to work/job
    ### These other three are defined relative to $Env:PIPELINE_WORKSPACE
    # $Env:BUILD_SOURCESDIRECTORY  - Cleaned BEFORE checkout IF: Workspace.Clean = All or Resources, or if Checkout.Clean = $True
    #                                Importantly, defaults to work/job/s BUT when there are multiple sources, can be work/job/s/sourcename
    # $Env:BUILD_BINARIESDIRECTORY - Cleaned BEFORE build IF: Workspace.Clean = Outputs
    # $Env:BUILD_STAGINGDIRECTORY  - Cleaned after each Build
    ### Additionally, these two are cleaned after each Job:
    # $Env:AGENT_TEMPDIRECTORY
    # $Env:COMMON_TESTRESULTSDIRECTORY

    # Build-system information. There are a few different sources for the information
    # But each variable should have a default here:
    $Script:OutputRoot = $Env:BUILD_BINARIESDIRECTORY ??
    $Env:IB_OUTPUT_ROOT ??
    (Join-Path $BuildRoot 'Output')
    New-Item -Type Directory -Path $OutputRoot -Force | Out-Null

    $Script:TestResultsRoot = $script:TestResultsRoot ?? # An override for build script parameters
    $Env:IB_TEST_RESULTS_ROOT ?? # An override for machine-level settings
    $Env:TEST_RESULTS_DIRECTORY ??
    (Join-Path $OutputRoot testresults)

    $Script:TempRoot = @(Get-Content Env:IB_TEMP_ROOT, Env:AGENT_TEMPDIRECTORY, Env:TEMP, Env:TMP -ErrorAction Ignore) |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1
    if (-not $Script:TempRoot) { $Script:TempRoot = if ($IsLinux) { "/tmp" } else { [System.IO.Path]::GetTempPath() } }

    # If you need to install additional tools, we use Install-GitHubRelease
    # Set the Tools hashtable to @{ exe = "org", "project" }
    # For example:
    # $Script:Tools = @{
    #   yq   = "mikefarah", "yq"
    #   flux = "fluxcd", "flux2"
    # }
    [hashtable]$Script:GHTools = @{} + ($Script:GHTools ?? @{})

    $script:UniversalPackageRoot ??= Join-Path $script:OutputRoot universal

    # Allow a -Clean switch to add the "Clean-Output" task on the front
    if ($Clean -and -not ($BuildTask -eq "Clean-Output")) {
        $BuildTask = @("Clean-Output") + $BuildTask
    }
    $script:NugetConfigFile = Get-ChildItem $BuildRoot -Filter "[Nn]u[Gg]et.config" | Convert-Path

    Write-Build Cyan "  OutputRoot: $OutputRoot"
    Write-Build Cyan "  TestResultsRoot: $TestResultsRoot"
    Write-Build Cyan "  TempRoot: $TempRoot"
    Write-Build Cyan "  UniversalPackageRoot: $UniversalPackageRoot"

    # If we're skipping coverage, make sure there are no demands on passing
    if ($SkipCoverage) {
        $Script:PassingCodeCoverage = -1.0
    }
}

# Our common task definitions
$script:InitializeTasks = @(
    # In CI pipelines (or if you specify $Clean)
    if ($BuildSystem -ne "None" -or $Script:Clean) {
        # Run the Clean-Output task before the rest of the build tasks
        "Clean-Output"
    }
    # Note that we run *all* of the Install tasks via the alias which must be kept up to date
    "Install-All"
    # Skip Get-Version if we're not in a git repo (yet -- e.g. initialize dependencies in a container)
    if (Test-Path ".git") {
        "Get-Version"
    }
)
$script:BuildTasks = @()
$script:PublishTasks = @()
$script:TestTasks = @()
$script:PushTasks = @("Push-Docker")
$script:CheckpointTasks = @("Tag-Source")


# Initially define the CI task as Get-Version...Tag-Source using virtual task names
Add-BuildTask CI @(
    "Initialize"
    "Build"
    "Test"
    "Publish"
    "Push"
    "Tag-Source"
)

foreach ($taskfile in Get-ChildItem -Path $PSScriptRoot -Filter *.Task.ps1) {
    # Write-Information "$($PSStyle.Foreground.BrightBlue)    $($taskfile.FullName)$($PSStyle.Reset)"
    . $taskfile.FullName
}
