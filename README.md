# Opinionated Build Tasks for Invoke-Build

- Requires PowerShell 7.2 or later.
- Should work with any module from my [PowerShellTemplate](/jaykul/PowerShellTemplate).

I've started using Invoke-Build to run my builds in PowerShell (due mostly to unhappiness with GitHub and Azure Pipelines).
This is a collection of tasks I've written that get shared by all my project builds.

## Usage

Your .build.ps1 script _must_ set variables:

### For PowerShell modules

- `$PSModuleName`
    - The name of the module you're building.
    - There **must** be a .psd1 module manifest with this name in your source.
    - The build will create a folder with this name in the output folder

If you're including building a dotnet project, it's also recommended to set

- `$DotNetPublishRoot`
    - The target folder for dotnet publish.
    - Defaults to `$OutputRoot/publish`
    - For PowerShell modules, I always override this to `$BuildRoot/lib` and add that to the `CopyDirectories` list
      in my ModuleBuilder `build.psd1` so that it gets copied to the output folder by ModuleBuilder.

### For DotNet assemblies

- `$dotnetProjects`
    - Specifies which projects to build
    - I recommend you put this as a parameter on your Build.ps1
        - Set the default to the full list of your assembly projects
        - Add an alias: "Projects"
- `$dotnetTestProjects`
    - Specifies which projects are test projects
    - I recommend you put this as a parameter on your Build.ps1
    - Add an alias: "TestProjects"
- `$dotnetOptions`
    - Specifies further options to pass to dotnet
    - I recommend you put this as a parameter on your Build.ps1
    - Add an alias: "Options"
    - Example values:
        "-verbosity" = "minimal"
        "-runtime" = "linux-x64"
