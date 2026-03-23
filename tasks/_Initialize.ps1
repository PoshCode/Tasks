#Requires -PSEdition Core
# TODO: Figure out what the Harness equiv is too all the github/ado build env vars
Write-Verbose "Initializing build variables" -Verbose
$script:ErrorView = "DetailedView"
$script:InformationPreference = "Continue"
$script:ErrorActionPreference = "Stop"
$PSStyle.OutputRendering = "ANSI"
# We're going to treat "DIAGNOSTIC" as "VERBOSE" + "DEBUG" and hope it rarely happens! ;)
if ($ENV:AGENT_DIAGNOSTIC -eq 'True' -or $ENV:SYSTEM_DEBUG -eq 'True') {
    # TODO: What is the harness equivalent for the env var
    $script:VerbosePreference = "Continue"
    $script:DebugPreference = "Continue"

    Get-ChildItem Env:* | ForEach-Object {
        Write-Verbose "  Env:$($_.Name) = $($_.Value)" -Verbose
    }
}

# Force different colors for Verbose and Debug
if ($PSStyle.Formatting.Verbose -eq $PSStyle.Formatting.Warning) {
    $PSStyle.Formatting.Verbose = $PSStyle.Foreground.BrightCyan
}
if ($PSStyle.Formatting.Debug -eq $PSStyle.Formatting.Warning) {
    $PSStyle.Formatting.Debug = $PSStyle.Foreground.BrightGreen
}

# Our goal is 90% code coverage, but this can be overriden by defining it lower in the .build.ps1 file
$Script:RequiredCodeCoverage ??= 0.9 # TODO: Only used by invoke-pester wrapper, not needed

# Our default build configuration is Release (probably only applies to DotNet)
$script:Configuration ??= "Release"
Write-Verbose "  Configuration: $script:Configuration" -Verbose

$script:BuildTasksDirectory = $PSScriptRoot
$script:BuildTaskScriptsDirectory = Join-Path (Split-Path $PSScriptRoot) "scripts"
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

Write-Verbose "  BuildSystem [$BuildSystem]" -Verbose
Write-Verbose "  Information [$InformationPreference]" -Verbose
Write-Verbose "  Verbose [$VerbosePreference]" -Verbose
Write-Verbose "  Debug [$DebugPreference]" -Verbose


# In CI builds you have a BranchName
$script:BranchName = if ($Env:BUILD_SOURCEBRANCHNAME) {
    $Env:BUILD_SOURCEBRANCHNAME
} elseif (Get-Command git -CommandType Application -ErrorAction SilentlyContinue) {
    git branch --show-current
}

$script:PushEnabled ??= $BuildSystem -ne 'None' -and ($BranchName -match "^main|^release/|^hotfix/")

# In PR Builds you have a SourceBranch and a TargetBranch
[bool]$script:IsPullRequest = $script:IsPullRequest ?? ($Env:BUILD_REASON -eq "PullRequest" -or $Env:DRONE_BUILD_EVENT -eq "pull_request")
[long]$script:PullRequestId = $script:PullRequestId ?? $Env:SYSTEM_PULLREQUEST_PULLREQUESTID ?? $Env:DRONE_PULL_REQUEST
[string]$script:SourceBranch = $script:SourceBranch ?? $Env:SYSTEM_PULLREQUEST_SOURCEBRANCH ?? $Env:BUILD_SOURCEBRANCH ?? $Env:DRONE_SOURCE_BRANCH ?? $Env:CI_COMMIT_BRANCH ?? $script:BranchName
[string]$script:TargetBranch = $script:TargetBranch ?? $ENV:SYSTEM_PULLREQUEST_TARGETBRANCH ?? $Env:DRONE_TARGET_BRANCH ?? $script:MainBranch
# These SonarQube variables are settable from script or environment
[string]$script:SonarProjectKey = $script:SonarProjectKey ?? $Env:SONARQUBE_PROJECTKEY ?? $Env:SONAR_PROJECTKEY
[string]$script:SonarToken = $script:SonarToken ?? $Env:SONARQUBE_PAT ?? $Env:SONAR_TOKEN
[string]$script:SonarHostURL = $script:SonarHostURL ?? $Env:SONARQUBE_URL ?? $Env:SONAR_URL
# If the SonarProjectKey is set, we have to collect coverage
[switch]$script:CollectCoverage = $script:CollectCoverage -or $script:SonarProjectKey

[string]$script:ProductName = $script:ProductName ?? $Env:PRODUCT_NAME ?? $Env:PIPELINE_NAME ?? $Env:DRONE_REPO_NAME ?? $Env:CI_REPO ?? $script:SonarProjectKey
[string]$script:PipelineId = $script:PipelineId ?? $Env:PIPELINE_ID ?? $Env:HARNESS_PIPELINE_ID ?? $Env:PLUGIN_PIPELINE ?? "local build"
[string]$script:PipelineExecutionId = $script:PipelineExecutionId ?? $Env:PIPELINE_EXECUTION_ID ?? $Env:BUILD_ID ?? $Env:HARNESS_EXECUTION_ID ?? $Env:HARNESS_BUILD_ID ?? $Env:DRONE_BUILD_NUMBER ?? "0"

# A little extra BuildEnvironment magic
Set-BuildHeader { Write-Build 11 "Start Task: $($args[0])" }
Set-BuildFooter { Write-Build 11 "Finish Task: $($args[0]) $($Task.Elapsed) [Total: $([DateTime]::Now - ${*}.Started)]" }


# Cross-platform separator character
${script:/} = [IO.Path]::DirectorySeparatorChar

# BuildRoot is provided by Invoke-Build
Write-Verbose "  BuildRoot [$BuildRoot]" -Verbose

### Note about Azure Pipeline environment variables:
# $Env:PIPELINE_WORKSPACE      - Defaults to work/job
### These other three are defined relative to $Env:PIPELINE_WORKSPACE
# $Env:BUILD_SOURCESDIRECTORY  - Cleaned BEFORE checkout IF: Workspace.Clean = All or Resources, or if Checkout.Clean = $True
#                                Importantly, defaults to work/job/s BUT when there are multiple sources, can be work/job/s/sourcename
# $Env:BUILD_BINARIESDIRECTORY - Cleaned BEFORE build IF: Workspace.Clean = Outputs
# $Env:BUILD_STAGINGDIRECTORY  - Cleaned after each Build

### Additionally, these two are cleaned after each Job:
# $Env:AGENT_TEMPDIRECTORY
# $Env:COMMON_TESTRESULTSDIRECTORY

# There are a few different environment/variables it could be, and then our fallback
$Script:OutputPath = if ($Env:BUILD_BINARIESDIRECTORY) {
    $Env:BUILD_BINARIESDIRECTORY
} else {
    Join-Path $BuildRoot 'Output'
}

Write-Verbose "  Output [$OutputPath]" -Verbose
New-Item -Type Directory -Path $OutputPath -Force | Out-Null

$Script:TestResultsRoot = $script:TestResultsRoot ??
$Env:TEST_ROOT ?? # I set this for earthly
$Env:COMMON_TESTRESULTSDIRECTORY ?? # Azure
$Env:TEST_RESULTS_DIRECTORY ??
(Join-Path $OutputPath testresults)

New-Item -Type Directory -Path $TestResultsRoot -Force | Out-Null
Write-Verbose "  TestResultsRoot: $TestResultsRoot" -Verbose

$Script:TempDirectory = @(Get-Content Env:AGENT_TEMPDIRECTORY, Env:COMMON_TESTRESULTSDIRECTORY, Env:TEMP, Env:TMP -ErrorAction Ignore) |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1
if (-not $Script:TempDirectory) { $Script:TempDirectory = if ($IsLinux) { "/tmp" } else { [System.IO.Path]::GetTempPath() } }

# If you need to install additional tools, we use Install-GitHubRelease
# Set the Tools hashtable to @{ exe = "org", "project" }
# For example:
# $Script:Tools = @{
#   yq   = "mikefarah", "yq"
#   flux = "fluxcd", "flux2"
# }
[hashtable]$Script:GHTools = @{} + ($Script:GHTools ?? @{})

$script:UniversalPackageRoot ??= Join-Path $script:OutputPath universal

#region DotNet task variables.
# When we have DotNet projects, we just need to set one of these variables:
if ($dotnetSolution -or $DotNetPublishRoot) {
    Write-Information "Initializing DotNet build variables (dotnetSolution: $dotnetSolution, DotNetPublishRoot: $DotNetPublishRoot)"

    $script:dotnetSolution = $dotnetSolution
    $script:dotnetSolutionName = Split-Path $dotnetSolution -LeafBase
    Write-Verbose "  Solution project: $dotnetSolution" -Verbose
    $script:dotnetOutputPath = Join-Path $script:OutputPath $script:dotnetSolutionName
    # This is used in Directory.build.props to configure the default output directory for dotnet restore and build (and publish?)
    $Env:LDBUILD_BINARIESDIRECTORY = $script:OutputPath
    Write-Verbose "  dotnetOutputPath: $script:dotnetOutputPath" -Verbose

    # The DotNetPublishRoot is the "publish" folder within the Output (used for dotnet publish output)
    $script:DotNetPublishRoot ??= Join-Path $script:dotnetOutputPath publish
    $script:DotNetPackRoot ??= Join-Path $script:dotnetOutputPath nuget
    $script:UniversalPackageRoot ??= Join-Path $script:dotnetOutputPath universal
    $script:DotNetVersion ??= $Env:DOTNET_VERSION ?? (dotnet --version)
    $script:TargetFramework ??= $Env:DOTNET_TARGET_FRAMEWORK ?? ("net" + $script:DotNetVersion.Split(".")[0..1] -join ".")
    $script:TargetRuntime ??= $ENV:DOTNET_TARGET_RUNTIME ?? ($IsLinux ? "linux-x64" : "win-x64")
    $ENV:LDBUILD_TARGET_RUNTIME = $script:TargetRuntime

    Write-Verbose "  DotNetPublishRoot: $DotNetPublishRoot" -Verbose
    Write-Verbose "  DotNetPackRoot: $DotNetPackRoot" -Verbose
    Write-Verbose "  UniversalPackageRoot: $UniversalPackageRoot" -Verbose

    $script:dotnetProjects = @(dotnet sln $dotnetSolution list | Where-Object { $_ -like "*.*proj" })
    Write-Verbose "  DotNetProjects: $(($script:dotnetProjects).Count)" -Verbose
    $script:dotnetTestProjects = @($script:dotnetProjects | Where-Object { $_ -like "*Test*.*proj" })
    Write-Verbose "  DotNetTestProjects: $(($script:dotnetTestProjects).Count)" -Verbose
    $script:dotnetOptions ??= @{}

    $script:NuGetPublishKey ??= $Env:NUGET_API_KEY
    $script:NuGetPublishUri ??= $Env:NUGET_API_URI ?? "https://nuget.loandepot.com/nuget/LDTS/v3/index.json"
    Write-Verbose "  NuGetPublishUri: $NuGetPublishUri" -Verbose
    $script:UPackPublishKey ??= $Env:UPACK_API_KEY
    $script:UPackPublishUri ??= $Env:UPACK_PUBLISH_URI ?? "https://nuget.loandepot.com"
    $script:UPackFeed ??= $Env:UPACK_FEED_NAME ?? "build-output"
    Write-Verbose "  UPackPublishUri: $UPackPublishUri" -Verbose
    Write-Verbose "  UPackFeed: $UPackFeed" -Verbose

    # If the only (or last) task is "Clean" then add on DotNetClean
    if (@($BuildTask)[-1] -eq "Clean") {
        $BuildTask = @("Clean", "DotNetClean")
    }
}
#endregion

#region Helm task variables
$HelmChartRoot ??= Join-Path $BuildRoot "charts"
if (Test-Path $HelmChartRoot) {
    $script:HelmChartRoot = $HelmChartRoot
    $script:ACRName = $script:ACRName ?? $ENV:ACR_URI ?? "crazusw2dvosl1"
    $script:helmOutputPath = Join-Path $Script:OutputPath "charts"
    Write-Verbose "  HelmChartRoot: $script:HelmChartRoot" -Verbose
    Write-Verbose "  ACRName: $script:ACRName" -Verbose
    Write-Verbose "  helmOutputPath: $script:helmOutputPath" -Verbose
    $script:ChartName ??= Get-ChildItem -Path $script:HelmChartRoot -File -Filter Chart.yaml -Recurse -Depth 1 | ForEach-Object { $_.Directory.Name }
    $script:HelmCharts = $script:ChartName | Join-Path -Path $HelmChartRoot -ChildPath { $_ } | Get-Item
    Write-Verbose "  HelmCharts: $(($script:HelmCharts).Count)" -Verbose
    $script:GHTools.add("kubeconform", "https://github.com/yannh/kubeconform/releases/tag/v0.7.0")
}
#endregion

## The first task defined is the default task. Put the right values for your project type here...
Add-BuildTask CI @(
    # In CI pipelines (or if you specify $Clean)
    # Run the Clean task before the rest of the build tasks
    if ($BuildSystem -ne "None" -or $Script:Clean) {
        "Clean"
    }
    "DotNetRestore"
    "DotNetToolRestore"
    "GetVersion"
    "DotNetBuild"
    "DotNetTest"
    "DotNetTrx2JUnit"
    "ReportGenerator"
    "DotNetPack"
    "DotNetPush"
    "DotNetPublish"
)

Add-BuildTask Restore @(
    # Dependencies include restore and version
    "DotNetRestore"
)

Add-BuildTask Version @(
    # Dependencies include tool restore
    "GetVersion"
)

Add-BuildTask Build @(
    # Dependencies include restore and version
    "DotNetBuild"
)

Add-BuildTask Test @(
    # Depends on Build
    "DotNetTest"
)


Add-BuildTask Pack @(
    # Dependencies include build, restore and version -- but not test
    "DotNetPack"
)

# "DotNetPublish" is for websites, but needs testing
Add-BuildTask Publish @(
    # Depends on Build
    "DotNetPublish"
)
# "DotNetPush" is only valid in CI

# Allow a -Clean switch to add the "Clean" task on the front
if ($Clean -and -not ($BuildTask -eq "Clean")) {
    $BuildTask = @("Clean") + $BuildTask
}

Write-Verbose "  Import Shared Tasks" -Verbose
foreach ($taskfile in Get-ChildItem -Path $PSScriptRoot -Filter *.Task.ps1) {
    Write-Verbose "    $($taskfile.FullName)"
    . $taskfile.FullName
}
