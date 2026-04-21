---
name: new-build-powershell
description: configuring PowerShell Module projects for build and creating a new build script
---

## Requirements

1. Projects must target PowerShell Core (7.x)
2. The .NET SDK must be available
3. If there is a csproj, the `dotnet` base must also be included

## Reference

There are NUMBERED documents in ./references with more detailed instructions for each of these steps, which you should refer to as you go through them.

## Process Overview

1. Ensure you're building a ModuleBuilder module. There should be a `build.psd1` file in the project root.
2. Copy the files from assets/ to your project root and customize them
    - Add a `$ModuleName` parameter to the build.build.ps1 and hard-code the name of the module
    - If you have not reached 85% code coverage in tests, add a $PassingCodeCoverage parameter with a default, and a comment requiring it be increased for each pull request.
3. Update your projects:
    - Rename your RequiredModules.psd1 to build.requires.psd1 and if necessary, update the syntax for ModuleFast
    - Pester 5 Tests

Once those steps are done, make sure that `.gitignore` includes `Output/` directory and run your `build.build.ps1` to verify that the build is working. You may need to further customize and troubleshoot, but the build should work locally.

You may want to copy the `invoke-build` skill into your project.
