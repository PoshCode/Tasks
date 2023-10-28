<#
    .SYNOPSIS
        Calculate variables that we need repeatedly in build tasks, including some paths and defaults for some preferences
    .DESCRIPTION
        My Invoke-Build tasks are convention-based, and the calculations here define most of those conventions ;)
#>
[CmdletBinding()]
param(
    # Skip importing tasks
    [switch]$NoTasks
)

$InformationPreference = "Continue"
$ErrorView = 'DetailedView'
$ErrorActionPreference = 'Stop'

if (!(Get-Variable Verbose -Scope Script -ErrorAction Ignore)) {
    $script:Verbose = $false
}
if (!(Get-Variable Debug -Scope Script -ErrorAction Ignore)) {
    $script:Debug = $false
}

Write-Information "Initializing build variables"
# BuildRoot is provided by Invoke-Build
Write-Information "  BuildRoot: $BuildRoot"

#region Constants for simpler build tasks
# Cross-platform separator character
${script:\} = ${script:/} = [IO.Path]::DirectorySeparatorChar

#endregion

#region Preference variables
# You can override any of these by just setting them in your .build.ps1:

# Our default goal is 90% code coverage
$Script:RequiredCodeCoverage ??= 0.9

# Our default build configuration is Release (probably only applies to DotNet)
$script:Configuration ??= "Release"
Write-Information "  Configuration: $script:Configuration"

#endregion

#region Calculated shared variables
# These are calculated based on the detected build system

# NOTE: this variable is currently also used for Pester formatting ...
# So we must use either "AzureDevOps", "GithubActions", or "None"
$script:BuildSystem = if (Test-Path Env:EARTHLY_BUILD_SHA) {
    "Earthly"
} elseif (Test-Path Env:GITHUB_ACTIONS) {
    "GithubActions"
} elseif (Test-Path Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI) {
    "AzureDevops"
} else {
    "None"
}
Write-Information "  BuildSystem: $script:BuildSystem"

# A little extra BuildEnvironment magic
if ($script:BuildSystem -eq "AzureDevops") {
    Set-BuildHeader { Write-Build 11 "##[group]Begin $($args[0])" }
    Set-BuildFooter { Write-Build 11 "##[endgroup]Finish $($args[0]) $($Task.Elapsed)" }
}

<#  A note about paths noted by Azure Pipeline environment variables:
    $Env:PIPELINE_WORKSPACE         - Defaults to /work/job_id and holds all the others:

    These other three are defined relative to $Env:PIPELINE_WORKSPACE
    $Env:BUILD_SOURCESDIRECTORY     - Cleaned BEFORE checkout IF: Workspace.Clean = All or Resources, or if Checkout.Clean = $True
                                        For single source, defaults to work/job_id/s
                                        For multiple, defaults to work/job_id/s/sourcename
    $Env:BUILD_BINARIESDIRECTORY    - Cleaned BEFORE build IF: Workspace.Clean = Outputs
    $Env:BUILD_STAGINGDIRECTORY     - Cleaned AFTER each Build
    $Env:AGENT_TEMPDIRECTORY        - Cleaned AFTER each Job
#>

# There are a few different environment/variables it could be, and then our fallback
$Script:OutputRoot = $script:OutputRoot ??
                        $Env:OUTPUT_ROOT ?? # I set this for earthly
                        $Env:BUILD_BINARIESDIRECTORY ?? # Azure
                        (Join-Path -Path $BuildRoot -ChildPath 'output')
New-Item -Type Directory -Path $OutputRoot -Force | Out-Null
Write-Information "  OutputRoot: $OutputRoot"

$Script:TestResultsRoot = $script:TestResultsRoot ??
                            $Env:TEST_ROOT ?? # I set this for earthly
                            $Env:COMMON_TESTRESULTSDIRECTORY ?? # Azure
                            $Env:TEST_RESULTS_DIRECTORY ??
                            (Join-Path -Path $OutputRoot -ChildPath 'tests')
New-Item -Type Directory -Path $TestResultsRoot -Force | Out-Null
Write-Information "  TestResultsRoot: $TestResultsRoot"

### IMPORTANT: Our local TempRoot does not cleaned the way the Azure one does
$Script:TempRoot = $script:TempRoot ??
                    $Env:TEMP_ROOT ?? # I set this for earthly
                    $Env:RUNNER_TEMP ?? # Github
                    $Env:AGENT_TEMPDIRECTORY ?? # Azure
                    (Join-Path ($Env:TEMP ?? $Env:TMP ?? "$BuildRoot/Tmp_$(Get-Date -f yyyyMMddThhmmss)") -ChildPath 'InvokeBuild')
New-Item -Type Directory -Path $TempRoot -Force | Out-Null
Write-Information "  TempRoot: $TempRoot"

# Git variables that we could probably use:
$Script:GitSha = $script:GitSha ?? $Env:EARTHLY_BUILD_SHA ?? $Env:GITHUB_SHA ?? $Env:BUILD_SOURCEVERSION
if (!$Script:GitSha) {
    $Script:GitSha = git rev-parse HEAD
}
Write-Information "  GitSha: $Script:GitSha"

$script:BranchName = $script:BranchName ?? $Env:EARTHLY_GIT_BRANCH ?? $Env:BUILD_SOURCEBRANCHNAME
if (!$script:BranchName -and (Get-Command git -CommandType Application -ErrorAction Ignore)) {
    $script:BranchName = (git branch --show-current) -replace ".*/"
}
Write-Information "  BranchName: $script:BranchName"
#endregion

#region DotNet task variables. Find the DotNet projects once.
if (([bool]$DotNet = $dotnetProjects -or $DotNetPublishRoot)) {
    Write-Information "Initializing DotNet build variables (dotnetProjects: $dotnetProjects, DotNetPublishRoot: $DotNetPublishRoot)"
    # The DotNetPublishRoot is the "publish" folder within the OutputRoot (used for dotnet publish output)
    $script:DotNetPublishRoot ??= Join-Path $script:OutputRoot publish

    # Our $buildProjects are either:
    # - Just the name
    # - The full path to a csproj file
    # We're going to normalize to the full csproj path
    $script:dotnetProjects = @(
        if (!$dotnetProjects) {
            Write-Information "  No `$DotNetProjects specified"
            Get-ChildItem -Path $BuildRoot -Include *.*proj -Recurse
        } elseif (![IO.Path]::IsPathRooted(@($dotnetProjects)[0])) {
            Write-Information "  Relative `$DotNetProjects specified"
            Get-ChildItem -Path $BuildRoot -Include *.*proj -Recurse |
                Where-Object { $dotnetProjects -contains $_.BaseName }
        } else {
            $dotnetProjects
        }
    ) | Convert-Path
    Write-Information "  DotNetProjects: $($script:dotnetProjects -join ", ")"

    $script:dotnetTestProjects = @(
        if (!$dotnetTestProjects) {
            Write-Information "  No `$DotNetTestProjects specified"
            Get-ChildItem -Path $BuildRoot -Include *Test.*proj -Recurse
        } elseif (![IO.Path]::IsPathRooted(@($dotnetTestProjects)[0])) {
            Write-Information "  Relative `$DotNetTestProjects specified"
            Get-ChildItem -Path $BuildRoot -Include *.*proj -Recurse |
                Where-Object { $dotnetTestProjects -contains $_.BaseName }
        } else {
            $dotnetTestProjects
        }
    )  | Convert-Path
    Write-Information "  DotNetTestProjects: $($script:dotnetTestProjects -join ", ")"

    # In order to publish nuget packages, you need to set these before running the build
    $script:NuGetPublishKey ??= $Env:NUGET_API_KEY
    $script:NuGetPublishUri ??= $Env:NUGET_API_URI ?? "https://api.nuget.org/v3/index.json"
    Write-Information "  NuGetPublishUri: $NuGetPublishUri"

    $script:dotnetOptions ??= @{}
}
#endregion

#region PowerShell Module task variables. Find the PowerShell module once.
if ($PSModuleName) {
    Write-Information "Initializing PSModule build variables"
    # We're looking for either a build.psd1 or the module manifest:
    #   ./src/ModuleName.psd1
    #   ./source/ModuleName.psd1
    #   ./ModuleName/ModuleName.psd1
    if ($PSModuleName -eq "*" -or !$PSModuleSourceRoot -or !$PSModuleName  -or !(Test-Path $PSModuleSourceRoot -PathType Container)) {
        Write-Information "  Looking for PSModule source"
        # look for a build.psd1 for ModuleBuilder. It should be in the root, but it might be in a subfolder
        if (($BuildModule = Get-ChildItem -Recurse -Filter build.psd1 -ErrorAction Ignore | Select-Object -First 1)) {
            Write-Information "  Found build.psd1: $($BuildModule.FullName)"

            $script:PSModuleSourcePath = $BuildModule.FullName
            # Import it, and figure out the path to the actual module
            $Data = Import-PowerShellDataFile -LiteralPath $BuildModule.FullName
            $SourcePath = ($Data.ModuleManifest ?? $Data.Path ?? $Data.SourcePath)

            # Find the actual source. Either a folder or a manifest
            Push-Location $BuildModule.Root.FullName
            $script:PSModuleSourceRoot = Resolve-Path $SourcePath
            Pop-Location
            if (Test-Path $PSModuleSourceRoot -PathType Container) {
                Write-Information "  Found PSModule source folder: $PSModuleSourceRoot"
                # If it's a folder, look for a manifest
                $script:PSModuleSourceRoot = Get-ChildItem $PSModuleSourceRoot -Filter "$PSModuleName.psd1" -File |
                    Where-Object Name -ne "build.psd1" |
                    Select-Object -First 1 |
                    Convert-Path
            }
            if (Test-Path $PSModuleSourceRoot -PathType Leaf) {
                Write-Information "  Found PSModule source manifest: $PSModuleSourceRoot"
                $script:PSModuleName = [IO.Path]::GetFileNameWithoutExtension($PSModuleSourceRoot)
                $script:PSModuleSourceRoot = Split-Path $PSModuleSourceRoot
            }
        } else {
            Write-Information "  No build manifest, searching for module source"
            # Look for a module manifest
            $ModuleManifest = Get-ChildItem "src","source",$PSModuleName,"." -Filter "$PSModuleName.psd1" -File -ErrorAction Ignore |
                    Where-Object Name -ne "build.psd1" |
                    Select-Object -First 1 |
                    Convert-Path
            if (Test-Path $ModuleManifest -PathType Leaf) {
                Write-Information "  Found PSModule source manifest: $ModuleManifest"
                $script:PSModuleName = [IO.Path]::GetFileNameWithoutExtension($ModuleManifest)
                $script:PSModuleSourceRoot = Split-Path $ModuleManifest
                $script:PSModuleSourcePath = $ModuleManifest
            }
        }

        # As part of giving up, set ModuleName empty
        if ($script:PSModuleName.Length -le 1) {
            Write-Information "  Could not find PSModule $PSModuleName"
            $script:PSModuleName = ""
        }
    }

    Write-Information "  PSModuleName: $PSModuleName"
    if (!$script:PSModuleName) {
        throw "Could not identify module to build. Please set `$PSModuleSourceRoot to point at the manifest, or add a build.psd1 in the root"
    }

    Write-Information "  PSModuleSourceRoot: $PSModuleSourceRoot"
    if (!(Test-Path $PSModuleSourceRoot -PathType Container -ErrorAction Ignore)) {
        throw "Can't perform module build for '$PSModuleName', can't find source folder '$PSModuleSourceRoot'"
    }

    # THESE variables can be overridden in a devops pipeline or $module.build.ps1
    $script:PSModuleOutputPath ??= $Env:PSMODULE_OUTPUT_PATH ?? (Join-Path $OutputRoot $PSModuleName)
    Write-Information "  PSModuleOutputPath: $PSModuleOutputPath"

    $script:PSRepository ??= $Env:PSREPOSITORY ?? "PSGallery"
    Write-Information "  PSRepository: $PSRepository"

    # In order to publish modules, you may need to set these before running the build
    $script:PSModulePublishUri ??= $Env:PSMODULE_PUBLISH_URI ?? "https://www.powershellgallery.com/api/v2"
    $script:PSModulePublishKey ??= $Env:PSMODULE_PUBLISH_KEY
    Write-Information "  PSModulePublishUri: $PSModulePublishUri"
}
#endregion

# PackageNames allows you to build and tag multiple packages from the same repository
$script:PackageNames = $script:PackageNames ?? @(
if ($dotnetProjects) {
    (Split-Path $dotnetProjects -LeafBase).ToLower()
} elseif ($PSModuleName) {
    @($PSModuleName)
} else {
    @("PSModule")
})


## The first task defined is the default task. Default to build and test.
if ($PSModuleName -and $dotnetProjects -or $DotNetPublishRoot) {
    Add-BuildTask Test Build, DotNetTest, PSModuleAnalyze, PSModuleTest
    Add-BuildTask Build DotNetRestore, PSModuleRestore, GitVersion, DotNetBuild, DotNetPublish, PSModuleBuild #, PSModuleBuildHelp
    Add-BuildTask Publish TagSource, DotNetPack, DotNetPush, PSModulePublish
} elseif ($PSModuleName) {
    Add-BuildTask Test Build, PSModuleAnalyze, PSModuleTest
    Add-BuildTask Build PSModuleRestore, GitVersion, PSModuleBuild #, PSModuleBuildHelp
    Add-BuildTask Publish Test, TagSource, PSModulePublish
} elseif ($dotnetProjects) {
    Add-BuildTask Test Build, DotNetTest
    Add-BuildTask Build DotNetRestore, GitVersion, DotNetBuild, DotNetPublish
    Add-BuildTask Publish Test, TagSource, DotNetPack, DotNetPush
}


# Finally, import all the Task.ps1 files in this folder
if (!$NoTasks) {
    Write-Information "Import Shared Tasks"
    foreach ($taskfile in Get-ChildItem -Path $PSScriptRoot -Filter *.Task.ps1) {
        if (!$DotNet -and $taskfile.Name -match "DotNet") { continue }
        if (!$PSModuleName -and $taskfile.Name -match "PSModule") { continue }
        Write-Information "  $($taskfile.FullName)"
        . $taskfile.FullName
    }
}
