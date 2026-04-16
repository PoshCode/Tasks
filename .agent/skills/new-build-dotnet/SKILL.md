---
name: new-build-dotnet
description: configuring dotnet projects for build and creating a new build script
---

## Requirements

1. You must have the .NET 10 SDK installed. The projects may reference older SDKs like .NET 8, but you must have 10 available.
2. All projects must be using SDK-style projects

## Reference

There are NUMBERED documents in ./references with more detailed instructions for each of these steps, which you should refer to as you go through them.

## Process Overview

1. Move solution files to the root of the project
2. Copy the `*.Build.*` files from assets/ to your project root and customize them as needed
3. Update your projects:
    - Ensure direct project references
    - Add the `<IsPackable>` property as appropriate
    - Add the `<IsPublishable>` property as appropriate
    - Add the `<ContainerRepository>` property for container builds and remove Dockerfiles.
    - Add the `<IsTestProject>` for all test projects.

Once those steps are done, make sure that `.gitignore` includes `Output/` directory and run your `build.build.ps1` to verify that the build is working. You may need to further customize and troubleshoot, but the build should work locally.

Finally, use the `references/Validation_Checklist.md` to ensure all steps have been completed correctly, and verify the build works by testing individual build tasks and verifying that they produce the correct output.

There are conceptual documents and explanations in the ./references folder that you can read to understand the reasons behind these change, so you can customize and extend the build for your project safely.

Additionally, there are TROUBLESHOOTING documents in ./references where we document known problems and their solutions. If you encounter any problems not covered in those docs, please update the documentation for our future benefit.

You may want to copy the `invoke-build` skill into your project.