# Key Concepts and Rationale

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

**Testing:** Developers must perform manual build and testing after implementation is complete.

## On Moving The Solution Files

Multiple solutions in subdirectories make it difficult to determine which solutions exist, and which should be built in automation. They also make it difficult to manage the output directories consistently, and version components together.

By moving the solution files in all repositories to the root, and using them to referencing the projects, we can share the same build process across all repositories while allowing you to structure your projects in sub-folders however you prefer.

You can even maintain additional solution files (or filters) that are not intended for CI build, but are just for developer convenience, as long as you don't put them in the root of the repository.

## Output Directory Structure

The build system creates a structured output directory where all output is in the root "Output" folder, and intermediate output is grouped per-solution so that if the solutions are built in parallel, but reference some of the same library projects, we don't get two solution builds trying to write the same output files at the same time.

```
Output/
├── Solution1/
│   ├── bin/
│   │   └── ProjectName/
│   │       └── Release/
│   │           └── net9.0/
│   ├── obj/
│   │   └── ProjectName/
│   ├── publish/
│   │   └── ProjectName/
│   └── version.json
├── Solution2/
~   (same structure)
├── Solution3/
~   (same structure)
├── nuget/
│   ├── ProjectName.1.0.0.nupkg
│   └── (all nuget packages from all solutions)
├── containers/
│   ├── ProjectName.1.0.0.tar
│   └── (all container images from all solutions)
~
└── version.json
```

## GitVersion Integration

All builds currently use GitVersion for semantic versioning:

**Configuration highlights:**
- **Workflow:** GitFlow
- **Main branch:** Increments `beta` pre-release version on merge
- **Feature branches:** Increments `alpha` pre-release version on merge
- **Release and hotfix branches:** Increments `rc` pre-release version on merge

**Version format:**
- Assembly version: `{Major}.{Minor}.{Patch}.{BuildCount}`
- Informational version: `{Major}.{Minor}.{Patch}{PreReleaseTag}+Build.{BuildCount}.Date.{CommitDate}.Branch.{BranchName}.Sha.{Sha}`

## IsPackable vs IsPublishable

**IsPackable=True:**
- Creates NuGet packages with `dotnet pack`
- For libraries and shared code
- Output goes to `Output/nuget/project.nupkg`

**IsPublishable=True:**
- Creates deployment artifacts with `dotnet publish`
- For applications, services, and executables
- Output goes to `Output/<Solution>/publish/project`

**Default (both False):**
- Test projects
- Internal utilities
- Projects not meant for distribution
