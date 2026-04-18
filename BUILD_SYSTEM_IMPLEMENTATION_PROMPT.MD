# Monorepo Build System Implementation Guide

## Context and Purpose

This document provides comprehensive instructions for implementing a standardized Invoke-Build monorepo build system in .NET repositories. The build system consolidates multiple solution files from subdirectories into root-level solution files, implements centralized output management, and provides automated versioning with GitVersion.

## Prerequisites

Before implementing this build system, ensure:

1. The repository contains one or more .NET solutions in subdirectories
2. Each subdirectory has its own solution file (e.g., `SubFolder/ProjectName.sln`)
3. You have identified which projects need to be published (web apps, services) vs packed (libraries)

## Implementation Guidance

**Approach:** Implement steps sequentially, checking in after each step completion for review.

**Solution Scope Determination:** Before implementing any changes, identify which solution file(s) in the repository root define the scope of work. Only apply build system changes to subdirectories and projects that are referenced by the root-level solution file(s). Subdirectories not referenced by any root solution file should be left unchanged, as they may be independent projects with their own build systems or may be legacy code not part of the current build scope.

**Repository Structure:** Use Step 1 to discover all solution files and their locations in subdirectories.

**Project Classification:** Use Step 5 instructions to identify:
- **Publishable projects** (web apps, services): Look for `<Project Sdk="Microsoft.NET.Sdk.Web">`, Docker support, or entry points
- **Packable projects** (libraries): Look for `<Project Sdk="Microsoft.NET.Sdk">` with reusable code
- **Neither** (test projects): Projects with test frameworks or internal utilities

**Dockerfiles:** Follow Step 6 to simplify any existing Dockerfiles found in publishable project directories.

**Testing:** Developer will handle manual testing after implementation is complete.

---

## Implementation Steps

### Step 0: Create or Merge Root Directory.Build.props

**Action:** Ensure the repository has a properly configured root `Directory.Build.props` file for centralized output management.

**Instructions:**

1. **Check if `Directory.Build.props` exists in the repository root**

2. **If NO `Directory.Build.props` exists:**
   - Create a new `Directory.Build.props` file in the repository root with the following content:

```xml
<Project>
  <PropertyGroup>
    <SolutionName Condition="'$(SolutionName)' == ''">shared</SolutionName>

    <RootOutputPath Condition="'$(LDBUILD_BINARIESDIRECTORY)' == ''">$(MSBuildThisFileDirectory)Output/$(SolutionName)/</RootOutputPath>
    <RootOutputPath Condition="'$(LDBUILD_BINARIESDIRECTORY)' != ''">$(LDBUILD_BINARIESDIRECTORY)/$(SolutionName)/</RootOutputPath>

    <BaseOutputPath>$(RootOutputPath)bin/$(MSBuildProjectName)</BaseOutputPath>
    <BaseIntermediateOutputPath>$(RootOutputPath)obj/$(MSBuildProjectName)</BaseIntermediateOutputPath>
    <PublishDir>$(RootOutputPath)publish/$(MSBuildProjectName)</PublishDir>
    <!-- <RuntimeIdentifier>linux-x64</RuntimeIdentifier> -->
    <!-- <AppendRuntimeIdentifierToOutputPath>False</AppendRuntimeIdentifierToOutputPath> -->
    <RuntimeIdentifier Condition="'$(LDBUILD_TARGET_RUNTIME)' != ''">$(LDBUILD_TARGET_RUNTIME)</RuntimeIdentifier>
    <IsPackable>False</IsPackable>
    <IsPublishable>False</IsPublishable>
  </PropertyGroup>
</Project>
```

3. **If `Directory.Build.props` ALREADY EXISTS:**
   - Read the existing file and identify any custom properties or settings
   - Attempt to merge the required build system properties with existing content:
     - Add the `SolutionName` property if not present
     - Add the `RootOutputPath` conditional properties for output management
     - Add the `BaseOutputPath`, `BaseIntermediateOutputPath`, and `PublishDir` properties
     - Add the `RuntimeIdentifier` conditional property
     - Add the `IsPackable` and `IsPublishable` default properties if not present
     - Preserve any existing custom properties (e.g., `<Nullable>enable</Nullable>`, `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`)
   - **Present the merged version to the user for approval** before making changes
   - Ask: "I've merged the build system properties with your existing Directory.Build.props. Please review the merged content below. Is this acceptable?"

**Why This Matters:**
- The `Directory.Build.props` file is the foundation of centralized output management
- It ensures all projects build to a consistent `Output/<SolutionName>/` directory structure
- The `RuntimeIdentifier` property enables the build system to correctly locate test DLLs
- The `IsPackable` and `IsPublishable` defaults prevent accidental packaging of test projects

### Step 0a: Update .gitignore to Exclude Output Directory

**Action:** Add the `Output/` directory to `.gitignore` to prevent build artifacts from being committed.

**Instructions:**

1. **Open the `.gitignore` file in the repository root**

2. **Add the following line to exclude the Output directory:**
   ```
   Output/
   ```

3. **Placement:** Add this line in the appropriate section (typically near other build output exclusions like `bin/`, `obj/`, etc.)

**Why This Matters:**
- The centralized build system creates all build artifacts in the `Output/` directory
- Build artifacts should never be committed to source control
- This prevents accidentally committing:
  - Compiled binaries (`Output/<SolutionName>/bin/`)
  - Intermediate build files (`Output/<SolutionName>/obj/`)
  - Published applications (`Output/<SolutionName>/publish/`)
  - NuGet packages (`Output/<SolutionName>/nuget/`)
  - Test results (`Output/<SolutionName>/TestResults/`)

**Example Merge Scenario:**

Existing `Directory.Build.props`:
```xml
<Project>
  <PropertyGroup>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>
</Project>
```

Merged `Directory.Build.props`:
```xml
<Project>
  <PropertyGroup>
    <SolutionName Condition="'$(SolutionName)' == ''">shared</SolutionName>

    <RootOutputPath Condition="'$(LDBUILD_BINARIESDIRECTORY)' == ''">$(MSBuildThisFileDirectory)Output/$(SolutionName)/</RootOutputPath>
    <RootOutputPath Condition="'$(LDBUILD_BINARIESDIRECTORY)' != ''">$(LDBUILD_BINARIESDIRECTORY)/$(SolutionName)/</RootOutputPath>

    <BaseOutputPath>$(RootOutputPath)bin/$(MSBuildProjectName)</BaseOutputPath>
    <BaseIntermediateOutputPath>$(RootOutputPath)obj/$(MSBuildProjectName)</BaseIntermediateOutputPath>
    <PublishDir>$(RootOutputPath)publish/$(MSBuildProjectName)</PublishDir>
    <RuntimeIdentifier Condition="'$(LDBUILD_TARGET_RUNTIME)' != ''">$(LDBUILD_TARGET_RUNTIME)</RuntimeIdentifier>
    <IsPackable>False</IsPackable>
    <IsPublishable>False</IsPublishable>
    
    <!-- Existing custom properties preserved -->
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>
</Project>
```

### Step 0b: Create Root build.build.ps1 (If Not Present)

**Action:** Ensure the repository has a `build.build.ps1` file in the root for orchestrating builds.

**Instructions:**

1. **Check if `build.build.ps1` exists in the repository root**

2. **If `build.build.ps1` DOES NOT exist:**
   - Create a new `build.build.ps1` file in the repository root with the following content:

```powershell
<#
.SYNOPSIS
    ./project.build.ps1
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

            Get-ChildItem -Path $PSScriptRoot/*/* -Filter *.sln |
                Split-Path -LeafBase |
                Where-Object { $_ -like "*$wordToComplete*" } |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        })]
    [Alias("Project")]
    [Parameter(Position = 0)]
    [string]$Solution = "*",

    # The Key to use for reporting to SonarQube
    [string]$SonarProjectKey = $($Solution -ne "*" ? $Solution : ""),

    # [string[]]$MonoRepoVersionNames = @(""),

    # Which projects to build
    [Alias("Projects")]
    $solutionProject = @(
        # By default build the first solution file in the root
        if (Get-ChildItem -Filter "${Solution}.sln" -ErrorAction Ignore -OutVariable sln) {
            if ($sln.Count -gt 1) {
                Write-Warning "Multiple solution files found: `n- $($sln.FullName -join '`n- ')`Building only the first one: $($sln[0].FullName)"
            }
            $sln[0] | Convert-Path
        }         
    )[0],
    
    # This should always be calculated automagically if you have docker files. If not, you'll need to specify these. 
    $DotNetPublishProjects = @(),

    # Which projects are test projects
    [Alias("TestProjects")]
    $dotnetTestProjects = @(
        $dotnetProjects | Where-Object {
            $_ -match "\.slnx?$" -or
            $_ -match "Test[^\\/]*\..*proj$"
        }
    ),

    # Further options to pass to dotnet
    [Alias("Options")]
    $dotnetOptions = @{
        "-verbosity" = "minimal"
        # "-runtime" = "linux-x64"
    },

    $TargetFramework = "net8.0",
    [ValidateSet('linux-x64','win-x64')]
    $TargetRuntime
)

. $PSScriptRoot/../LD.Platform.BuildTasks/scripts/PSFormatting.ps1

# The name of the module to publish
$script:PSModuleName = "TerminalBlocks"
# Use Env because Earthly can override it
$Env:OUTPUT_ROOT ??= Join-Path $PSScriptRoot output

$Tasks = "../LD.Platform.BuildTasks/tasks", "tasks", "../tasks", "../../tasks" | Convert-Path -ErrorAction Ignore
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
```

3. **If `build.build.ps1` ALREADY EXISTS:**
   - **Do nothing** - leave the existing file as-is
   - The developer has already customized this file for their repository

**Why This Matters:**
- The `build.build.ps1` file is the entry point for all build operations
- It defines parameters for controlling builds (Configuration, Solution, Clean, etc.)
- The `$TargetFramework` parameter must match the framework used by projects in the repository (commonly `net8.0` or `net9.0`)
- **Critical:** If `$TargetFramework` doesn't match the actual project target frameworks, tests will be skipped with "Skipping empty input" because the build system won't find the compiled test DLLs in the expected paths
- The `$dotnetTestProjects` parameter enables automatic test project discovery by pattern matching

**Important Configuration Notes:**
- **TargetFramework:** Set to `net8.0` or `net9.0` based on your projects' target framework. This must match or tests won't run.
- **Solution Discovery:** The script auto-discovers solution files in the root directory
- **Test Project Discovery:** Automatically finds projects matching `Test[^\\/]*\..*proj$` pattern
- **Task Paths:** Looks for shared tasks in `../LD.Platform.BuildTasks/tasks` and local `tasks/` directories

### Step 1: Analyze Repository Structure

**Action:** Identify all solution files and their locations.

**Instructions:**
1. Search for all `.sln` files in the repository
2. For each solution file found in a subdirectory (not in root), note:
   - The subdirectory name (e.g., `LD.JV.Builder`)
   - The solution file name (e.g., `LD.JV.Builder.sln`)
   - The projects contained in that solution
3. Create a mapping of subdirectory → new root-level solution name:
   - Pattern: If subdirectory is `LD.JV.Builder` and solution is `LD.JV.Builder.sln`, create root-level `LD.JV.Builder.sln`
   - Pattern: If subdirectory is `LD.JV.BuilderAsync` and solution is `LD.JV.BuilderAsync.sln`, create root-level `LD.JV.BuilderAsync.sln`
   - Pattern: If subdirectory is `LD.JV.PlatformEvent.Common` and solution is `LD.JV.PlatformEvent.Common.sln`, create root-level `LD.JV.PlatformEvent.Common.sln`

**Expected Output Format:**

After completing Step 1, provide a summary in this format:

```
## Step 1 Complete: Repository Structure Analysis

### Solution Files Found

**1. [Solution Name]**
- **Location:** [Full path to current solution file]
- **Subdirectory:** [Subdirectory name]
- **New root-level name:** [Name for root solution file]

**Projects contained ([count] total):**
- **Main/API Projects:**
  - [Project names that are web apps or APIs]
  
- **Library Projects:**
  - [Project names that are libraries]

- **Test Projects:**
  - [Project names that are test projects]

[Repeat for each solution found]

### Summary

- **[N] solution files** found in subdirectories
- **[Solution1.sln]** will be moved from `[SubDir]/` to root with updated paths (prefix: `[SubDir]\`)
- **[Solution2.sln]** will be moved from `[SubDir]/` to root with updated paths (prefix: `[SubDir]\`)
```

### Step 2: Create Root-Level Solution Files

**Action:** For each subdirectory solution one level deep from the root, move the solution file to the root and update the project paths.

**Instructions:**
1. Read the original solution file from the subdirectory
2. Update all project paths in the solution file to be relative from the repository root:
   - **Original path pattern:** `ProjectName\ProjectName.csproj` (relative to subdirectory)
   - **New path pattern:** `SubdirectoryName\ProjectName\ProjectName.csproj` (relative to root)
4. Preserve all project GUIDs, configurations, and solution items
5. Update any solution items paths (like NuGet.config) to reference the subdirectory:
   - **Original:** `NuGet.config = NuGet.config`
   - **New:** `NuGet.config = SubdirectoryName\NuGet.config`

**Example Transformation:**

Original solution in `LD.JV.Builder/LD.JV.Builder.sln`:
```
Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "LD.JV.Builder.Host.Web", "LD.JV.Builder.Host.Web\LD.JV.Builder.Host.Web.csproj", "{GUID}"
```

New solution in root `LD.JV.Builder.sln`:
```
Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "LD.JV.Builder.Host.Web", "LD.JV.Builder\LD.JV.Builder.Host.Web\LD.JV.Builder.Host.Web.csproj", "{GUID}"
```

### Step 3: Delete Original Subdirectory Solution Files

**Action:** Remove the old solution files from subdirectories.

**Instructions:**
1. For each solution file that was in a subdirectory (e.g., `LD.JV.Builder/LD.JV.Builder.sln`), delete it using `git rm`
2. **Do not delete:**
   - Project files (.csproj, .fsproj, etc.)
   - Source code
   - Tests
   - Docker files
   - Any other non-solution files

**Why:** The root-level solution files replace the subdirectory solutions. Keeping both would cause confusion and maintenance issues.

### Step 4: Update Subdirectory Directory.Build.props Files

**Action:** Modify existing `Directory.Build.props` files in subdirectories to import the root-level `Directory.Build.props`.

**Instructions:**
1. Search for existing `Directory.Build.props` files in subdirectories
2. For each file found, add the following import statement as the **first line** after the opening `<Project>` tag:

```xml
<Project>
    <Import Project="$([MSBuild]::GetPathOfFileAbove('Directory.Build.props', '$(MSBuildThisFileDirectory)../'))" Condition="'' != $([MSBuild]::GetPathOfFileAbove('Directory.Build.props', '$(MSBuildThisFileDirectory)../'))" />
    <!-- Existing content continues here -->
```

**Why:** This ensures that the centralized output path configuration from the root `Directory.Build.props` is inherited by all projects, while still allowing subdirectory-specific properties.

**Example:**

Before:
```xml
<Project>
    <PropertyGroup>
        <Nullable>enable</Nullable>
        <WarningsAsErrors>$(WarningsAsErrors);CS8600</WarningsAsErrors>
    </PropertyGroup>
</Project>
```

After:
```xml
<Project>
    <Import Project="$([MSBuild]::GetPathOfFileAbove('Directory.Build.props', '$(MSBuildThisFileDirectory)../'))" Condition="'' != $([MSBuild]::GetPathOfFileAbove('Directory.Build.props', '$(MSBuildThisFileDirectory)../'))" />
    <PropertyGroup>
        <Nullable>enable</Nullable>
        <WarningsAsErrors>$(WarningsAsErrors);CS8600</WarningsAsErrors>
    </PropertyGroup>
</Project>
```

### Step 5: Mark Projects as Publishable or Packable

**Action:** Update .csproj files to explicitly declare their packaging/publishing intent.

**Instructions:**

1. **For projects that should be published** (web applications, services, executables):
   - Add `<IsPublishable>True</IsPublishable>` to the main `<PropertyGroup>`
   - These are typically projects with:
     - `<Project Sdk="Microsoft.NET.Sdk.Web">`
     - Docker support
     - Entry points (Program.cs with Main method)
     - Service hosts

2. **For projects that should be packed as NuGet packages** (libraries, shared code):
   - Add `<IsPackable>True</IsPackable>` to the main `<PropertyGroup>`
   - These are typically projects with:
     - `<Project Sdk="Microsoft.NET.Sdk">`
     - Reusable library code
     - No entry point

3. **For projects that should not be published or packed** (test projects, internal utilities):
   - No changes needed - the root `Directory.Build.props` sets both to `False` by default

**Example Changes:**

For a web service project (`LD.JV.BuilderAsync.Host.Messaging.csproj`):
```xml
<PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <UserSecretsId>2318815b-a78c-420b-80db-571a264a2cf9</UserSecretsId>
    <IsPublishable>True</IsPublishable>  <!-- ADD THIS LINE -->
    <DockerDefaultTargetOS>Linux</DockerDefaultTargetOS>
</PropertyGroup>
```

For a library project (`LD.JV.PlatformEvent.Internal.csproj`):
```xml
<PropertyGroup>
    <TargetFrameworks>net8.0;net9.0</TargetFrameworks>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>True</IsPackable>  <!-- ADD THIS LINE -->
</PropertyGroup>
```

### Step 6: Simplify Dockerfiles for Publishable Projects

**Action:** Update Dockerfiles to use pre-built artifacts instead of multi-stage builds.

**Instructions:**

For projects marked with `<IsPublishable>True</IsPublishable>` that have Dockerfiles, simplify them to expect pre-built publish artifacts:

1. **Identify Dockerfiles** in publishable project directories
2. **Replace multi-stage build Dockerfiles** with simplified single-stage versions
3. **Pattern to follow:**

**Before (multi-stage build):**
```dockerfile
FROM dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["NuGet.config", "."]
COPY ["Project/Project.csproj", "Project/"]
RUN dotnet restore "Project/Project.csproj"
COPY . .
WORKDIR "/src/Project"
RUN dotnet build "Project.csproj" -c Release -o /app/build
RUN dotnet publish "Project.csproj" -c Release -o /app/publish

FROM dotnet/runtime:9.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Project.dll"]
```

**After (simplified for pre-built artifacts):**
```dockerfile
FROM crazusw2dvosl1.azurecr.io/dotnet/runtime:9.0
WORKDIR /app
EXPOSE 8080
COPY . .
ENTRYPOINT ["dotnet", "ProjectName.dll"]
```

**Key Changes:**
- Remove all build stages (SDK image, restore, build, publish)
- Use only the runtime base image
- Simple `COPY . .` to copy pre-built artifacts
- Keep EXPOSE, ENTRYPOINT, and WORKDIR directives

**Why:** The build system now handles `dotnet publish` via the build tasks, creating publish artifacts in `Output/<Solution>/publish/<ProjectName>/`. Dockerfiles should only package these pre-built artifacts, not rebuild the application. This:
- Separates build concerns from containerization
- Speeds up Docker image creation
- Ensures consistent builds across environments
- Allows the build system to control versioning and build parameters

**Examples from this repository:**

For ASP.NET web applications:
```dockerfile
FROM crazusw2dvosl1.azurecr.io/dotnet/runtime:9.0
WORKDIR /app
EXPOSE 8080
COPY . .
ENTRYPOINT ["dotnet", "LD.JV.Builder.Host.Web.dll"]
```

For console applications/services:
```dockerfile
FROM crazusw2dvosl1.azurecr.io/dotnet/runtime:9.0
WORKDIR /app
EXPOSE 5000
COPY . .
ENTRYPOINT ["./LD.JV.PlatformEvent.Consumer"]
```

**Note:** The Dockerfile should remain in the project directory alongside the .csproj file. The build system will copy it to the publish output directory when `<IsPublishable>True</IsPublishable>` is set.

### Step 7: Test the Build System

**Action:** Verify the build system works correctly by testing individual build tasks sequentially with the developer.

**Instructions:**

**IMPORTANT:** The developer must run each command in their terminal. Prompt them to execute each command and wait for them to share the output before proceeding to the next step. Do not attempt to run commands automatically.

Work with the developer to test each build task in sequence. After each command succeeds, proceed to the next one:

1. **Test package restore:**
   ```powershell
   Invoke-Build DotNetRestore
   ```
   - Verifies NuGet packages can be restored
   - Checks package source configuration
   - Ensures all dependencies are available

2. **Test build:**
   ```powershell
   Invoke-Build DotNetBuild
   ```
   - Compiles all projects in the solution
   - Validates project references
   - Confirms output paths are correct

3. **Test unit tests:**
   ```powershell
   Invoke-Build DotNetTest
   ```
   - Runs all test projects
   - Generates test results
   - Validates test discovery

4. **Test publish (for publishable projects):**
   ```powershell
   Invoke-Build DotNetPublish
   ```
   - Creates deployment artifacts for projects marked `IsPublishable=True`
   - Output goes to `Output/<SolutionName>/publish/<ProjectName>/`
   - Includes runtime dependencies

5. **Test pack (for packable projects):**
   ```powershell
   Invoke-Build DotNetPack
   ```
   - Creates NuGet packages for projects marked `IsPackable=True`
   - Output goes to `Output/<SolutionName>/nuget/`
   - Includes version information from GitVersion

6. **Verify outputs:**
   - Check that `Output/` directory is created in the repository root
   - Verify subdirectories exist: `Output/<SolutionName>/bin/`, `obj/`, `publish/`, `nuget/`
   - Confirm build artifacts are in expected locations
   - Verify version.json is created with GitVersion information

7. **Test full CI pipeline (after individual tasks succeed):**
   ```powershell
   Invoke-Build CI
   ```
   - Runs all tasks in sequence
   - Simulates continuous integration build

---

## Key Concepts and Rationale

### Why Move Solutions to Root?

**Problem:** Multiple solutions in subdirectories make it difficult to:
- Build all solutions with a single command
- Share build configuration and tasks
- Manage output directories consistently
- Version solutions independently or together

**Solution:** Root-level solution files with subdirectory project references allow:
- Centralized build orchestration
- Shared build tasks and configuration
- Per-solution output directories
- Flexible versioning strategies

### Output Directory Structure

The build system creates a structured output directory:

```
Output/
├── JVBuilder/
│   ├── bin/
│   │   └── ProjectName/
│   │       └── Release/
│   │           └── net9.0/
│   ├── obj/
│   │   └── ProjectName/
│   ├── publish/
│   │   └── ProjectName/
│   ├── nuget/
│   └── version.json
├── JVBuilderAsync/
│   └── (same structure)
└── JVPlatformEventCommon/
    └── (same structure)
```

### GitVersion Integration

The build system uses GitVersion for semantic versioning:

**Configuration highlights:**
- **Workflow:** TrunkBased/preview1 - Each commit can increment version
- **Main branch:** Auto-increments minor version on merge
- **Feature branches:** Include branch name in pre-release tag
- **Release branches:** Use manual deployment mode with RC label
- **Commit messages:** Support `semver:` trailers for explicit version control
  - `semver: major` or `semver: breaking` - Increment major version
  - `semver: minor` or `semver: feature` - Increment minor version
  - `semver: patch` or `semver: fix` - Increment patch version
  - `semver: none` or `semver: skip` - No version increment

**Version format:**
- Assembly version: `{Major}.{Minor}.{Patch}.{BuildCount}`
- Informational version: `{Major}.{Minor}.{Patch}{PreReleaseTag}+Build.{BuildCount}.Date.{CommitDate}.Branch.{BranchName}.Sha.{Sha}`

### IsPackable vs IsPublishable

**IsPackable=True:**
- Creates NuGet packages with `dotnet pack`
- For libraries and shared code
- Output goes to `Output/<Solution>/nuget/`

**IsPublishable=True:**
- Creates deployment artifacts with `dotnet publish`
- For applications, services, and executables
- Output goes to `Output/<Solution>/publish/`
- Can include Dockerfiles and runtime dependencies

**Default (both False):**
- Test projects
- Internal utilities
- Projects not meant for distribution

### Invoke-Build Task Dependencies

The build system defines task dependencies:

```
CI Task:
  └─ Clean (if in CI or -Clean specified)
  └─ DotNetRestore
  └─ DotNetToolRestore
  └─ GetVersion
      └─ InstallGitVersion
      └─ GitInit
  └─ DotNetBuild
      └─ DotNetRestore
      └─ GetVersion
      └─ SonarQubeStart (if configured)
  └─ DotNetTest
  └─ DotNetTrx2JUnit
  └─ ReportGenerator
  └─ DotNetPack
  └─ DotNetPush
```

---

## Troubleshooting: Edge Cases and Complex Scenarios

This section documents real-world edge cases encountered during build system implementations and their solutions.

### Edge Case 1: SpecRun Path Handling with Centralized Output

**Repository:** FeeEngine (LD.FeeEngine.API)

**Symptom:**
Build fails with path duplication error in SpecRun-based test projects:
```
error: The filename, directory name, or volume label syntax is incorrect. : 
'C:\XDL\LD.FeeEngine.API\FeeEngine\LD.EPS.FeeEngine.BDD.Tests\C:\XDL\LD.FeeEngine.API\Output\FeeEngine\obj\...'
```

**Root Cause:**
SpecRun.SpecFlow targets file (version 3.9.31) does not correctly handle absolute paths in `BaseIntermediateOutputPath`. When the centralized build system sets this to an absolute path, SpecRun's targets attempt to concatenate it with the project directory path, resulting in malformed paths.

This is a known limitation of older SpecRun versions (pre-.NET 5) that assume `BaseIntermediateOutputPath` is always a relative path.

**Solution:**
Override the intermediate output path properties in the affected project to use a local relative path:

```xml
<PropertyGroup Label="Globals">
    <!-- Existing properties... -->
    <!-- Fix SpecRun path handling with custom output directories -->
    <BaseIntermediateOutputPath>obj\</BaseIntermediateOutputPath>
    <IntermediateOutputPath>$(BaseIntermediateOutputPath)\$(Configuration)\$(TargetFramework)\</IntermediateOutputPath>
</PropertyGroup>
```

**Trade-offs:**
- This project won't benefit from centralized intermediate output cleanup
- Creates a non-fatal warning about `BaseIntermediateOutputPath` being modified after MSBuild uses it
- Build artifacts (bin) still go to centralized location; only intermediate files (obj) are kept local
- Acceptable compromise until SpecRun is upgraded to version 3.10+ or SpecFlow 4.x

**When to Apply:**
- Projects using SpecRun.SpecFlow versions < 3.10
- Projects using SpecFlow.Plus.Runner with older versions
- Any test framework with custom MSBuild targets that assume relative paths

---

### Edge Case 2: Package Downgrade Errors from Legacy Dependencies

**Repository:** FeeEngine (LD.FeeEngine.API)

**Symptom:**
Build fails with NU1605 errors (package downgrade warnings treated as errors):
```
error NU1605: Warning As Error: Detected package downgrade: System.Diagnostics.Debug from 4.3.0 to 4.0.11
error NU1605: Warning As Error: Detected package downgrade: System.IO.FileSystem.Primitives from 4.3.0 to 4.0.1
error NU1605: Warning As Error: Detected package downgrade: System.Runtime.InteropServices from 4.3.0 to 4.1.0
error NU1605: Warning As Error: Detected package downgrade: System.Threading from 4.3.0 to 4.0.11
```

**Root Cause:**
Legacy internal packages (e.g., `LD.Common.AspNetCore 2.0.0.49`) or old test frameworks (e.g., `AutoFixture.AutoMoq 4.8.0`, `Moq 4.7.0`) create conflicting transitive dependency chains:

```
Project → LD.Common.AspNetCore 2.0.0.49
       → Microsoft.AspNetCore.Mvc.Core 2.2.0
       → Microsoft.Extensions.DependencyModel 2.1.0
       → Microsoft.DotNet.PlatformAbstractions 2.1.0
       → System.IO.FileSystem 4.0.1
       → runtime.win.System.IO.FileSystem 4.3.0
       → System.Diagnostics.Debug (>= 4.3.0)  ← Requires 4.3.0

But also:
Project → LD.Common.AspNetCore 2.0.0.49
       → Microsoft.Extensions.DependencyModel 2.1.0
       → System.Diagnostics.Debug (>= 4.0.11)  ← Allows 4.0.11
```

NuGet's dependency resolver chooses the lower version to satisfy both constraints, but this violates the "no downgrade" rule when `TreatWarningsAsErrors` is enabled.

**Solution:**
Add explicit package references for the higher versions required by transitive dependencies:

**For library projects with LD.Common.AspNetCore dependencies:**
```xml
<ItemGroup>
    <!-- Existing packages... -->
    <PackageReference Include="System.Diagnostics.Debug" Version="4.3.0" />
    <PackageReference Include="System.IO.FileSystem.Primitives" Version="4.3.0" />
    <PackageReference Include="System.Runtime.InteropServices" Version="4.3.0" />
</ItemGroup>
```

**For test projects with AutoFixture.AutoMoq dependencies:**
```xml
<ItemGroup>
    <!-- Existing packages... -->
    <PackageReference Include="System.Threading" Version="4.3.0" />
</ItemGroup>
```

**Why This Works:**
- Explicit package references take precedence over transitive dependencies in NuGet's resolution
- Forces NuGet to use version 4.3.0, satisfying all dependency constraints without downgrades
- System.* packages at version 4.3.0 (from .NET Core 1.x era) remain compatible with modern .NET
- At runtime, .NET 8.0+ uses built-in implementations; package references primarily satisfy NuGet's dependency graph

**Alternative Solutions (Not Recommended):**
- **Upgrade legacy packages:** Requires coordination across teams, potential breaking changes
- **Disable TreatWarningsAsErrors:** Reduces build quality, allows security vulnerabilities
- **Add NoWarn for NU1605:** Masks the problem without fixing it

**When to Apply:**
- Projects referencing legacy internal packages targeting .NET Framework or early .NET Core
- Test projects using older versions of Moq, AutoFixture, NSubstitute, or similar frameworks
- Any project with `TreatWarningsAsErrors=true` encountering NU1605 warnings

**Affected Projects in FeeEngine Example:**
- `LD.EPS.FeeEngine.ThirdPartyFramework` - Added 3 System.* packages
- `LD.EPS.FeeEngine.ClosingCorp` - Added 3 System.* packages
- `LD.EPS.FeeEngine.ClosingCorp.Tests` - Added System.Threading
- `LD.EPS.FeeEngine.ThirdPartyFees.Tests` - Added System.Threading
- `LD.EPS.FeeEngine.InRule.Tests` - Added System.Threading

---

### Edge Case 3: Understanding NuGet Dependency Resolution

**Background:**
Understanding how NuGet resolves package versions helps diagnose and fix dependency conflicts.

**NuGet Resolution Strategy:**
1. **Direct references win:** Explicit `<PackageReference>` in the project file takes highest precedence
2. **Nearest wins:** Among transitive dependencies, the package "nearest" to the project (fewest hops) is chosen
3. **Lowest compatible version:** When multiple versions satisfy constraints, NuGet picks the lowest version that works
4. **Downgrade detection:** If resolution results in using a lower version than required by any dependency, NU1605 is issued

**Example Dependency Graph:**
```
MyProject.csproj
├─ PackageA 2.0
│  └─ System.Text.Json >= 6.0.0
└─ PackageB 1.0
   └─ System.Text.Json >= 4.7.0

Resolution: System.Text.Json 6.0.0 (satisfies both >= 6.0.0 and >= 4.7.0)
```

**Downgrade Example:**
```
MyProject.csproj
├─ PackageA 2.0
│  └─ System.Text.Json 4.7.0 (exact version)
└─ PackageB 1.0
   └─ System.Text.Json >= 6.0.0

Resolution: System.Text.Json 4.7.0 (nearest wins, but downgrades from 6.0.0)
Warning NU1605: Detected package downgrade
```

**Fix:** Add explicit reference to override:
```xml
<PackageReference Include="System.Text.Json" Version="6.0.0" />
```

---

### Edge Case 4: Package Source Mapping Required with Central Package Management

**Repository:** LD.Shared.EnterprisePlatformServices.API (EPS)

**Symptom:**
Build fails with NU1507 errors when using Central Package Management with multiple NuGet sources:
```
error NU1507: Warning As Error: There are 6 package sources defined in your configuration. 
When using central package management, please map your package sources with package source mapping 
(https://aka.ms/nuget-package-source-mapping) or specify a single package source.
```

**Root Cause:**
When `Directory.Packages.props` enables Central Package Management (`<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>`), NuGet requires explicit package source mapping if multiple package sources are defined. This is a security feature to prevent dependency confusion attacks and ensure packages come from expected sources.

Without package source mapping, NuGet doesn't know which source to query for each package, leading to:
- Slower restore operations (queries all sources)
- Potential security risks (malicious packages from unexpected sources)
- Build failures when `TreatWarningsAsErrors` is enabled

**Solution:**
Add `<packageSourceMapping>` section to `nuget.config` to map package patterns to specific sources:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
    <add key="LDTS" value="https://nuget.loandepot.com/nuget/LDTS/v3/index.json" />
    <add key="LDTSQA" value="https://nuget.loandepot.com/nuget/LDTSQA/v3/index.json" />
    <add key="LoanDepot" value="https://nuget.loandepot.com/nuget/LoanDepot/v3/index.json" />
    <add key="EmpowerTest" value="https://nuget.loandepot.com/nuget/EmpowerTest/v3/index.json" />
    <add key="CUSA" value="https://nuget.loandepot.com/nuget/CUSA/v3/index.json" />
  </packageSources>
  
  <packageSourceMapping>
    <!-- Public packages from nuget.org -->
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
    
    <!-- Internal LD.* packages from company feeds -->
    <packageSource key="LDTS">
      <package pattern="LD.*" />
    </packageSource>
    <packageSource key="LDTSQA">
      <package pattern="LD.*" />
    </packageSource>
    <packageSource key="LoanDepot">
      <package pattern="LD.*" />
    </packageSource>
    <packageSource key="EmpowerTest">
      <package pattern="LD.*" />
    </packageSource>
    <packageSource key="CUSA">
      <package pattern="LD.*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
```

**Package Pattern Guidelines:**
- Use `*` wildcard to match all packages from a source (typically nuget.org for public packages)
- Use specific patterns like `LD.*` to match company-internal packages
- Use `CompanyName.*` patterns for vendor-specific packages
- More specific patterns take precedence over wildcards

**Why This Works:**
- NuGet now knows to query nuget.org for all public packages (Microsoft.*, System.*, etc.)
- Internal LD.* packages are only queried from company feeds
- Eliminates ambiguity and improves restore performance
- Prevents accidental package substitution attacks

**Alternative Solutions (Not Recommended):**
- **Disable Central Package Management:** Loses version consistency benefits
- **Use single package source:** Requires consolidating all packages into one feed
- **Disable TreatWarningsAsErrors:** Reduces build quality, allows security issues

**When to Apply:**
- Any repository using Central Package Management (`Directory.Packages.props`)
- Repositories with multiple NuGet package sources
- Builds failing with NU1507 errors
- Organizations with internal package feeds alongside nuget.org

**Related Documentation:**
- [NuGet Package Source Mapping](https://aka.ms/nuget-package-source-mapping)
- [Central Package Management](https://learn.microsoft.com/nuget/consume-packages/central-package-management)

---

### Edge Case 5: System.* Package Compatibility

**Question:** Why are System.* packages from .NET Core 1.x (version 4.3.0) still compatible with .NET 8.0?

**Answer:**
- System.* packages (System.Threading, System.Diagnostics.Debug, etc.) are part of .NET Standard 2.0
- .NET Standard 2.0 is supported by all modern .NET versions (.NET Core 2.0+, .NET 5+, .NET Framework 4.6.1+)
- Modern .NET includes these types in the core framework (no separate package needed at runtime)
- Package references are primarily for NuGet's dependency graph resolution
- At runtime, .NET 8.0's built-in implementations are used (type forwarding)

**Verification:**
```powershell
# Check if package is actually used at runtime
dotnet publish MyProject.csproj -c Release
# System.* packages won't appear in publish output - they're built into the runtime
```

---

### Recommendations for Preventing Edge Cases

**1. Regular Dependency Audits**
```powershell
# Check for outdated packages
dotnet list package --outdated

# Check for vulnerable packages
dotnet list package --vulnerable
```

**2. Central Package Management**
Use `Directory.Packages.props` for version management:
```xml
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
  <ItemGroup>
    <PackageVersion Include="System.Text.Json" Version="8.0.0" />
    <PackageVersion Include="Moq" Version="4.20.0" />
  </ItemGroup>
</Project>
```

**3. Upgrade Legacy Dependencies**
- Prioritize upgrading internal packages to target modern .NET
- Update test frameworks to current versions when feasible
- Document upgrade blockers for future planning

**4. Monitor Build Warnings**
- Review all NU1605 warnings even if build succeeds
- Investigate NU1608 (version override) warnings
- Track MSB3539 warnings about property modifications

**5. Test Framework Compatibility Matrix**
| Framework | Last Version Supporting .NET Framework | First Version Supporting .NET 5+ |
|-----------|---------------------------------------|-----------------------------------|
| SpecFlow | 3.9.x | 3.10+ |
| NUnit | 3.13.x | 3.13+ (both) |
| xUnit | 2.4.x | 2.4+ (both) |
| MSTest | 2.2.x | 2.2+ (both) |

---

## Common Issues and Solutions

### Issue: Build cannot find projects

**Symptom:** Error like "Project file does not exist"

**Solution:** Verify project paths in root solution files are correct and relative to repository root, not subdirectory.

### Issue: Output directory conflicts

**Symptom:** Build artifacts from different solutions overwrite each other

**Solution:** Ensure each root solution file has a unique name, which becomes the `SolutionName` variable used in output paths.

### Issue: GitVersion fails

**Symptom:** "No commits found on the current branch"

**Solution:** 
- Ensure repository has at least one commit
- Run `git fetch --unshallow` if in a shallow clone
- Verify `GitVersion.yml` is in repository root

### Issue: Projects not inheriting root Directory.Build.props

**Symptom:** Output goes to default `bin/` and `obj/` directories in project folders

**Solution:** Add the import statement to subdirectory `Directory.Build.props` files as described in Step 4.

### Issue: Test projects being packed or published

**Symptom:** NuGet packages or publish folders created for test projects

**Solution:** Ensure test projects do NOT have `<IsPackable>True</IsPackable>` or `<IsPublishable>True</IsPublishable>`. The default from root `Directory.Build.props` is False for both.

### Issue: NU1507 errors with Central Package Management

**Symptom:** Build warnings or errors like "NU1507: There are 2 package sources defined in your configuration. When using central package management, please map your package sources with package source mapping..."

**Solution:** Add `packageSourceMapping` section to the root `nuget.config` file. This is required when using Central Package Management (Directory.Packages.props). Example:

```xml
<packageSourceMapping>
  <packageSource key="nuget.org">
    <package pattern="*" />
  </packageSource>
  <packageSource key="LDTS">
    <package pattern="LD.*" />
  </packageSource>
  <!-- Add mapping for each package source in your config -->
</packageSourceMapping>
```

Place this section inside the `<configuration>` element, typically after `<activePackageSource>`. Map each package source to the package patterns it should provide.

---

## Validation Checklist

After implementation, verify:

- [ ] All original subdirectory solution files are deleted
- [ ] New root-level solution files exist for each subdirectory solution
- [ ] All project paths in root solutions are correct and relative to root
- [ ] Subdirectory `Directory.Build.props` files import the root `Directory.Build.props`
- [ ] Publishable projects have `<IsPublishable>True</IsPublishable>`
- [ ] Packable projects have `<IsPackable>True</IsPackable>`
- [ ] Test projects have neither IsPublishable nor IsPackable set to True
- [ ] `build.build.ps1` runs successfully for each solution
- [ ] Output directory structure is created correctly: `Output/<SolutionName>/`
- [ ] GitVersion generates version information successfully
- [ ] Tests run and produce results
- [ ] CI/CD pipeline is updated to use new build system
- [ ] `.gitignore` includes `Output/` directory

---

## Summary

This build system provides:
1. **Monorepo support** - Multiple solutions in one repository
2. **Centralized configuration** - Shared build tasks and properties
3. **Organized outputs** - Per-solution output directories
4. **Automated versioning** - GitVersion integration
5. **CI/CD ready** - Designed for pipeline automation
6. **Flexible** - Build all solutions or specific ones
7. **Extensible** - Add custom tasks as needed

The implementation consolidates build logic, reduces duplication, and provides a consistent developer and CI/CD experience across all solutions in the repository.
