<#
.SYNOPSIS
    ./build.build.ps1
.EXAMPLE
    Invoke-Build
.NOTES
    0.5.0 - Parameterize
    Add parameters to this script to control the build
#>
[CmdletBinding()]
param(
    # dotnet build configuration parameter (Debug or Release)
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    # Add the clean task before the default build
    [switch]$Clean,

    # Collect code coverage when tests are run
    [switch]$CollectCoverage,

    # Which solution to build
    [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            Get-ChildItem -Path $PSScriptRoot -Filter *.sln |
                Split-Path -LeafBase |
                Where-Object { $_ -like "*$wordToComplete*" } |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        })]
    [Alias("Project")]
    [Parameter(Position = 0)]
    [string]$Solution = "*",

    # Which projects to build
    [Alias("Projects")]
    $dotnetSolution = @(
        # By default build the EPS solution file in the root
        if (Get-ChildItem -Filter "${Solution}.sln" -ErrorAction Ignore -OutVariable sln) {
            if ($sln.Count -gt 1) {
                Write-Warning "Multiple solution files found: `n- $($sln.FullName -join '`n- ')`nBuilding only the first one: $($sln[0].FullName)"
            }
            $sln[0] | Convert-Path
        }
    )[0],

    # Further options to pass to dotnet
    [Alias("Options")]
    $dotnetOptions = @{
        "-verbosity" = "minimal"
    },

    # Sets framework for solution, included in build output path
    $TargetFramework = "net8.0",

    # Sets runtime for solution, included in build output path
    [ValidateSet('linux-x64','win-x64')]
    $TargetRuntime,

    # The Key to use for reporting to SonarQube
    [string]$SonarProjectKey = $($Solution -ne "*" ? $Solution : ""),

    # Helm charts
    [string]$HelmChartRoot = @(
        if (Get-ChildItem -Path "$PSScriptRoot/charts" -File -Recurse  -Filter "Chart.yaml" -ErrorAction Ignore) {
            Resolve-Path "$PSScriptRoot/charts" | Convert-Path
        }
    )[0]
)

$ScriptsFolder = "../LD.Platform.BuildTasks/scripts", "../BuildTasks/scripts", "../tasks/scripts" | Convert-Path -ErrorAction Ignore
. $ScriptsFolder/PSFormatting.ps1
# The name of the solution
$script:SolutionName = $Solution
# Use Env because Earthly can override it
$Env:OUTPUT_ROOT ??= Join-Path $PSScriptRoot output

$Tasks = "../LD.Platform.BuildTasks/tasks", "../BuildTasks/tasks", "../tasks/tasks", "tasks" | Convert-Path -ErrorAction Ignore
Write-Information "$($PSStyle.Foreground.BrightCyan)Found shared tasks in $Tasks" -Tag "InvokeBuild"

## Self-contained build script - can be invoked directly or via Invoke-Build
if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    foreach ($taskDir in $Tasks) {
        $bootstrap = Join-Path $taskDir "_BootStrap.ps1"
        Write-Information "Check for $bootstrap" -Tag "InvokeBuild"
        if (Test-Path $bootstrap) {
            Write-Information "Dotsource $bootstrap" -Tag "InvokeBuild"
            . $bootstrap
        }
    }

    Invoke-Build -File $MyInvocation.MyCommand.Path @PSBoundParameters -Result Result

    if ($Result.Error) {
        $Error[-1].ScriptStackTrace | Out-Host
        exit 1
    }
    exit 0
}

## Initialize the build variables, and import shared tasks, including DotNet tasks
foreach($taskDir in $Tasks) {
    $initialize = Join-Path $taskDir "_Initialize.ps1"
    if (Test-Path $initialize) {
        Write-Information ". $initialize"
        . $initialize
    }
}

Add-BuildTask HelmBuild InstallRequiredModules, GetVersion, HelmUpdateValuesSchema
Add-BuildTask HelmTest HelmBuild,HelmTestChart
Add-BuildTask HelmPack HelmTest,HelmPackChart
Add-BuildTask HelmPush HelmPack,HelmPushChart
