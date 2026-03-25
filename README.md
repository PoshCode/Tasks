# LD.Platform.BuildTasks

Centralized, reusable Invoke-Build task system for .NET monorepo projects at LoanDepot.

## Overview

BuildTasks provides reusable tasks scripts for Invoke-Build to standardize CI tasks across our various project types.

For each project type we aim to provide a common set of tasks used in CI, along with a "CI" task that composes them in a typical workflow, and common tasks for automating chores like updating dependencies and lock files, as well as deployment scripts.

- Get-Version: calculate the next version
- Initialize: restore dependencies
- Build: compile code or generate outputs
- Publish: create deployment artifacts
- Test: run tests and generate reports
- Push: push artifacts to build and artifact registries
- Checkpoint: tag the repository with the version

## Quick Starts


1. Clone this repository **as a sibling** to your project folder:
   ```powershell
   git clone https://github.com/loandepot/LD.Platform.BuildTasks BuildTasks
   ```
2. Follow the new-build instructions for your project type:
    - [Creating a new dotnet build](./skills/new-build-dotnet/SKILL.md)

## Common Commands

```powershell
# Full default build
Invoke-Build

# Build only
Invoke-Build Build

# Run tests
Invoke-Build Test

# Full CI build (with package publishing, etc)
Invoke-Build CI

# Investigate available tasks:
Invoke-Build ?

# Verify what will be executed:
Invoke-Build -whatif
```

## Documentation

Skills are being developed in the `skills/` directory, and both humans and AI agents are recommended to use the `new-build-<framework>/SKILL.md` files as the most up-to-date documentation for getting started.

Additional documentation is available in the `docs/` directory.

## Repository Structure

```
LD.Platform.BuildTasks/
├── common/                        # Shared tasks and base build script
│   ├── base.ps1                   # Base build script (shared initialization)
│   ├── Get-Version.Task.ps1       # Semantic versioning via GitVersion
│   ├── Clean-Output.Task.ps1      # Output directory cleanup
~
├── dotnet/                        # .NET build tasks
│   ├── base.ps1                   # DotNet build script (extends common/base.ps1)
│   ├── Build-DotNet.Task.ps1      # .NET build task
│   ├── Test-DotNet.Task.ps1       # .NET test task
~
├── helm/                          # Helm chart tasks
│   ├── base.ps1                   # Helm build script (extends common/base.ps1)
│   ├── Build-Helm.Task.ps1        # Helm build task
~
├── powershell/                    # PowerShell tasks (future)
├── node/                          # Node.js tasks (future)
├── scripts/                       # Utility scripts
├── docs/                          # Additional Documentation
├── skills/                        # AI Agent skills including the templates for new builds
├── GitVersion.yml                 # Default versioning configuration
~
└── README.md                      # This file!
```

## Key Features

### Centralized Output Management

All build outputs go to a centralized `Output/` directory.

For some project types (.NET, in particular) we put intermediate output (which might be duplicate)
in per-solution subfolders so we can parallelize this work. Final outputs should go directly in the
Output folder categorized by how it's being published (nuget, containers, charts, etc).

```
Output/
├── <SolutionName>/
│   ├── bin/          # Compiled assemblies
│   ├── obj/          # Intermediate files
│   └── version.json  # Version output
├── nuget/            # NuGet packages
├── publish/          # Deployment artifacts
├── containers/       # Container image tarballs
└── testresults/      # Test results
```

### Semantic Versioning

GitVersion is integrated, following our new git-flow workflow:
- Automatic version increments after each release is tagged and merged
- Version information embedded in output libraries and packages
