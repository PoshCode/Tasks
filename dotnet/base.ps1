<#
.SYNOPSIS
    DotNet build script -- extends always.ps1 with .NET build support.
.EXAMPLE
    Invoke-Build
.NOTES
    0.6.0 - Split from build.example.ps1
#>
[CmdletBinding()]
param(
    [ValidateScript({ "../common/base.ps1" })]
    $Extends,
    # dotnet build configuration parameter (Debug or Release)
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

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
    $script:Configuration ??= "Release"

    # Resolve $Solution to a full path -- path separators indicate a direct path, otherwise search $BuildRoot
    $script:dotnetSolution = if ($Solution -match '[\\/]') {
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
    $script:SolutionName = Split-Path $script:dotnetSolution -LeafBase
    $script:SolutionOutputPath = Join-Path $script:OutputPath $script:SolutionName
    # This is used in Directory.build.props to configure the default output directory for dotnet restore and build (and publish?)
    $Env:LDBUILD_OUTPUT_ROOT = $script:OutputPath

    # The DotNetPublishRoot is the "publish" folder within the Output (used for dotnet publish output)
    $script:DotNetPublishRoot ??= Join-Path $script:OutputPath publish
    $script:DotNetPackRoot ??= Join-Path $script:OutputPath nuget

    $script:SolutionTestResultsRoot = Join-Path $Script:TestResultsRoot $script:SolutionName
    New-Item -Type Directory -Path $SolutionTestResultsRoot -Force | Out-Null
    $script:DotNetVersion ??= $Env:DOTNET_VERSION ?? (dotnet --version)
    $script:TargetFramework ??= $Env:DOTNET_TARGET_FRAMEWORK ?? ("net" + $script:DotNetVersion.Split(".")[0..1] -join ".")
    $script:TargetRuntime ??= $ENV:DOTNET_TARGET_RUNTIME ?? ($IsLinux ? "linux-x64" : "win-x64")
    $ENV:LDBUILD_TARGET_RUNTIME = $script:TargetRuntime

    $script:dotnetProjects = @(dotnet sln $script:dotnetSolution list | Where-Object { $_ -like "*.*proj" })
    $script:dotnetTestProjects = @($script:dotnetProjects | Where-Object { $_ -like "*Test*.*proj" })
    $script:dotnetOptions ??= @{}

    $script:NuGetPublishKey ??= $Env:NUGET_API_KEY
    $script:NuGetPublishUri ??= $Env:NUGET_API_URI ?? "https://nuget.loandepot.com/nuget/LDTS/v3/index.json"
    $script:UPackPublishKey ??= $Env:UPACK_API_KEY
    $script:UPackPublishUri ??= $Env:UPACK_PUBLISH_URI ?? "https://nuget.loandepot.com"
    $script:UPackFeed ??= $Env:UPACK_FEED_NAME ?? "build-output"

    Write-Build Cyan "Initializing DotNet task variables (Solution: $script:dotnetSolution)"
    Write-Build Cyan "  Configuration: $script:Configuration"
    Write-Build Cyan "  dotnetSolution: $script:dotnetSolution"
    Write-Build Cyan "  SolutionOutputPath: $script:SolutionOutputPath"
    Write-Build Cyan "  DotNetPublishRoot: $DotNetPublishRoot"
    Write-Build Cyan "  DotNetPackRoot: $DotNetPackRoot"
    Write-Build Cyan "  SolutionTestResultsRoot: $SolutionTestResultsRoot"
    Write-Build Cyan "  DotNetProjects: $(($script:dotnetProjects).Count)"
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
$script:InitializeTasks = @(
    # In CI pipelines (or if you specify $Clean)
    if ($BuildSystem -ne "None" -or $Script:Clean) {
        # Run the Clean-Output task before the rest of the build tasks
        "Clean-Output"
    }
) + $InitializeTasks + @("Restore-DotNet")

$script:BuildTasks += @("Build-DotNet")
$script:PublishTasks += @("Pack-DotNet", "Publish-DotNet")
$script:TestTasks += $script:BuildSystem -eq "None" ? @("Test-DotNet") : @("Test-DotNet", "Convert-Trx2JUnit", "Convert-Coverage")
$script:PushTasks += @("Push-DotNet")
$script:CheckpointTasks += @()

foreach ($taskfile in Get-ChildItem -Path $PSScriptRoot -Filter *.Task.ps1) {
    # Write-Information "$($PSStyle.Foreground.BrightBlue)    $($taskfile.FullName)$($PSStyle.Reset)"
    . $taskfile.FullName
}