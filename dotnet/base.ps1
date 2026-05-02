<#
.SYNOPSIS
    DotNet build script -- extends common base with .NET build support.
.EXAMPLE
    Invoke-Build
#>
[CmdletBinding()]
param(
    [ValidateScript({ "../common/base.ps1" })]
    $Extends,
    # dotnet build configuration parameter (Debug or Release)
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = ($Env:IB_CONFIGURATION ?? 'Release'),

    # Solution to build -- accepts a name, a glob pattern, or a path (relative or full) to a .sln file.
    [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            # TODO: See if we can use the argument completer described here:
            # https://github.com/nightroman/Invoke-Build/blob/main/Docs/Argument-Completers.md
            # Because this doesn't work with the extends pattern
            Get-ChildItem -Path $PSScriptRoot -Filter *.sln |
                Split-Path -LeafBase |
                Where-Object { $_ -like "*$wordToComplete*" } |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        })]
    [Parameter(Position = 0)]
    [ValidateScript({
            if ($_ -match '[\\/]') {
                (Test-Path $_ -IsValid) -and ($_ -ilike '*.sln')
            } else {
                # Name or glob (e.g. "LD.EPS", "*", "*.sln")
                $true
            }
        })]
    [string]$Solution = "*",

    # Further options to pass to dotnet
    [Alias("Options")]
    [hashtable]$dotnetOptions = @{
        "-verbosity" = "minimal"
    },

    # Sets framework for solution, included in build output path
    [ValidatePattern('^net\d+\.\d+$')]
    $TargetFramework = "net10.0",

    # Sets runtime for solution, included in build output path
    [ValidateSet('linux-x64', 'win-x64', 'any')]
    $TargetRuntime
)

# Redirect $BuildRoot to the root script's directory
if ($BuildRoots.Count -gt 1) {
    $BuildRoot = $BuildRoots[-1]
}

#region DotNet task variables -- initialized in Enter-Build (runs only when actually building)
Enter-Build {

    # Resolve $Solution to a full path -- path separators indicate a direct path, otherwise search $BuildRoot
    $script:DotNetSolutionFile = if ($Solution -match '[\\/]') {
        $solutionPath = if ([System.IO.Path]::IsPathRooted($Solution)) {
            $Solution
        } else {
            Join-Path $BuildRoot $Solution
        }
        if (-not (Test-Path $solutionPath)) {
            throw "Solution file not found: $solutionPath"
        }
        Convert-Path $solutionPath
    } else {
        $filter = if ($Solution -ilike '*.sln') { $Solution } else { "${Solution}.sln" }
        $found = Get-ChildItem -Path $BuildRoot -Filter $filter -ErrorAction Ignore
        if (-not $found) {
            throw "No solution file matching '$filter' found in $BuildRoot"
        }
        if ($found.Count -gt 1) {
            Write-Warning "Multiple solution files found:`n- $($found.FullName -join "`n- ")`nBuilding only the first one: $($found[0].FullName)"
        }
        $found[0] | Convert-Path
    }
    $script:SolutionName = Split-Path $script:DotNetSolutionFile -LeafBase
    # This is used in Directory.build.props to configure the root output directory for dotnet
    $Env:IB_OUTPUT_ROOT ??= $script:OutputRoot

    $script:DotNetPublishRoot ??= Join-Path $script:OutputRoot publish
    $script:DotNetPackRoot ??= Join-Path $script:OutputRoot nuget
    $script:SolutionOutputRoot ??= Join-Path $script:OutputRoot $script:SolutionName

    $script:SolutionTestResultsRoot = Join-Path $Script:TestResultsRoot $script:SolutionName
    $script:DotNetVersion ??= $Env:DOTNET_VERSION ?? (dotnet --version)
    $script:TargetFramework ??= $Env:DOTNET_TARGET_FRAMEWORK ?? ("net" + $script:DotNetVersion.Split(".")[0..1] -join ".")
    $script:TargetRuntime ??= $ENV:DOTNET_TARGET_RUNTIME ?? ($IsLinux ? "linux-x64" : "win-x64")

    $ENV:IB_TARGET_RUNTIME = $script:TargetRuntime
    $ENV:IB_CONFIGURATION = $script:Configuration

    $script:DotNetProjects = dotnet sln $script:DotNetSolutionFile list |
        Where-Object { $_ -like "*.*proj" } |
        Join-Path $script:BuildRoot -ChildPath { $_ } |
        ForEach-Object {
            $BaseName = Split-Path $_ -LeafBase
            [PSCustomObject]@{
                PSTypeName                 = "DotNet.Project"
                Path                       = $_
                # The rest of these properties MUST BE populated by getProperty in the Restore task
                BaseIntermediateOutputRoot = Join-Path $script:SolutionOutputRoot "obj/$BaseName"
                AssemblyName               = $BaseName
                IsPackable                 = [Nullable[bool]]$null
                IsPublishable              = [Nullable[bool]]$null
                IsTestProject              = [Nullable[bool]]$null
                TargetFileName             = [NullString]::Value
                OutDir                     = [NullString]::Value
                PublishDir                 = [NullString]::Value
            }
        }


    $script:dotnetTestProjects = @($script:DotNetProjects | Where-Object { $_ -like "*Test*.*proj" })
    $script:dotnetOptions ??= @{}

    $script:NuGetPublishKey ??= $Env:NUGET_API_KEY
    $script:NuGetPublishUri ??= $Env:NUGET_API_URI
    $script:UPackPublishKey ??= $Env:UPACK_API_KEY
    $script:UPackPublishUri ??= $Env:UPACK_PUBLISH_URI
    $script:UPackFeed ??= $Env:UPACK_FEED_NAME ?? "build-output"

    Write-Build Cyan "Initializing DotNet task variables (Solution: $script:DotNetSolutionFile)"
    Write-Build Cyan "  Configuration: $script:Configuration"
    Write-Build Cyan "  TargetFramework: $script:TargetFramework"
    Write-Build Cyan "  TargetRuntime: $script:TargetRuntime"
    Write-Build Cyan "  DotNetSolutionFile: $script:DotNetSolutionFile"
    Write-Build Cyan "  SolutionOutputRoot: $script:SolutionOutputRoot"
    Write-Build Cyan "  DotNetPublishRoot: $DotNetPublishRoot"
    Write-Build Cyan "  DotNetPackRoot: $DotNetPackRoot"
    Write-Build Cyan "  SolutionTestResultsRoot: $SolutionTestResultsRoot"
    Write-Build Cyan "  DotNetProjects: $(($script:DotNetProjects).Count)"
    Write-Build Cyan "  DotNetTestProjects: $(($script:dotnetTestProjects).Count)"
    Write-Build Cyan "  NuGetPublishUri: $NuGetPublishUri"
    Write-Build Cyan "  UPackPublishUri: $UPackPublishUri"
    Write-Build Cyan "  UPackFeed: $UPackFeed"

    # If the only (or last) task is "Clean-Output" then add on Clean-DotNet
    if (@($BuildTask)[-1] -eq "Clean-Output") {
        $BuildTask = @("Clean-Output", "Clean-DotNet")
    }

}
#endregion

# Add the dotnet tasks to the common tasks
$script:InitializeTasks += @("Restore-DotNet")
$script:BuildTasks += @("Build-DotNet")
$script:PublishTasks += @("Pack-DotNet", "Publish-DotNet")
$script:TestTasks += $script:BuildSystem -eq "None" ? @("Test-DotNet") : @("Test-DotNet", "Convert-Trx2JUnit", "Convert-Coverage")
$script:PushTasks += @("Push-DotNet")
$script:CheckpointTasks += @()

foreach ($taskfile in Get-ChildItem -Path $PSScriptRoot -Filter *.Task.ps1) {
    # Write-Information "$($PSStyle.Foreground.BrightBlue)    $($taskfile.FullName)$($PSStyle.Reset)"
    . $taskfile.FullName
}