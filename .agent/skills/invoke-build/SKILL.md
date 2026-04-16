---
name: invoke-build
description: Building and testing this project
---

These instructions are for projects that use a PowerShell `*.build.ps1` script to build.
They depend on our shared [BuildTasks repository](https://github.com/loandepot/LD.Platform.BuildTasks), and use common build task names for build and testing.

To get started, you must verify that the [BuildTasks repository](https://github.com/loandepot/LD.Platform.BuildTasks) is cloned (and up to date) in a sibling folder to the project you're working on. Obviously that doesn't apply if this **is** the BuildTasks repository!

To clone the repository **as a sibling** to your project folder:

```bash
cd ..
git clone https://github.com/loandepot/LD.Platform.BuildTasks BuildTasks
```

To initialize your system and install dependencies for building, run the `../BuildTasks/scripts/Bootstrap.ps1` script.

## Invoke-Build

If you have a `*.build.ps1` in your project root that extends our common build scripts, then all builds should be run _in PowerShell_. You can run `Invoke-Build ?` to determine the available tasks, and then call one, like `Invoke-Build Build`. To review which tasks would be executed instead of running the full build, you can add `-whatif`.

### To restore dependencies:

```powershell
Invoke-Build Initialize
```

### To build the whole repository:

```powershell
Invoke-Build Build
```

### To run all tests:

```powershell
Invoke-Build Test
```

### Full CI build (with package publishing, etc)

```powershell
Invoke-Build CI
```