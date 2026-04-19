# Build Script Inheritance with Invoke-Build `Extends`

Invoke-Build (v5.11+) supports a special `$Extends` parameter that enables **build script inheritance**. Instead of copying `build.example.ps1` into every project, a derived script can extend the base and inherit its parameters, initialization, and task definitions.

## How It Works

### The `$Extends` Parameter

A derived build script declares a `param` block with a single special parameter:

```powershell
param(
    [ValidateScript({"..\LD.Platform.BuildTasks\build.example.ps1"})]
    $Extends
)
```

When Invoke-Build processes this script:

1. It finds the `$Extends` parameter with a `ValidateScript` attribute
2. It **evaluates the script block** to get the path(s) to base script(s)
3. It resolves the path relative to the derived script's directory (`$BuildRoot`)
4. It **processes the base script first** — parameters, body, and task definitions
5. Then it processes the derived script's body

The `ValidateScript` block is not used for validation here — Invoke-Build hijacks it to extract the base script path. The block should return one or more path strings.

### What Gets Inherited

| Inherited from base | How |
|---|---|
| **Parameters** | The base script's `param()` block becomes shared. The derived script gets `-Configuration`, `-Clean`, `-Solution`, etc. without redeclaring them. |
| **Task definitions** | Aggregate tasks like `CI`, `Build`, `Test`, `Pack`, `Publish` carry over automatically. |
| **Script body code** | Initialization, variable setup, and task imports all execute during base processing. |

### What the Derived Script Controls

- **Override tasks** — `Add-BuildTask` with the same name as a base task **replaces** it (the old definition is moved to a "Redefined" list).
- **Add new tasks** — Define project-specific tasks not in the base.
- **Re-initialize variables** — Fix path-dependent variables that were set with the base's `$BuildRoot` (see below).

## The `$BuildRoot` Problem

This is the most important caveat when using Extends with `build.example.ps1`.

When Invoke-Build processes the base script via Extends, **`$BuildRoot` is set to the base script's directory**, not the derived project's directory. This means all initialization code in `_Initialize.ps1` runs with wrong paths:

```
# During Extends (base script processing):
$BuildRoot = C:\XDL\LD.Platform.BuildTasks          # <- base script's dir

# During derived script body:
$BuildRoot = C:\XDL\LD.Shared.MyProject              # <- correct
```

Variables set during base initialization that depend on `$BuildRoot` will have stale values:
- `$OutputPath` — uses direct assignment, gets overwritten on re-init
- `$HelmChartRoot` — uses `??=`, does NOT get overwritten
- `$TestResultsRoot` — uses `??` chain, does NOT get overwritten
- `$UniversalPacakgeRoot` — uses `??=`, does NOT get overwritten

### The Fix: Reset and Re-initialize

The derived script must:

1. **Reset variables** that use `??=` (null-coalescing assignment) so `_Initialize.ps1` can set them correctly
2. **Re-run `_Initialize.ps1`** with the correct `$BuildRoot`

```powershell
# Reset variables that won't self-correct due to ??= operators
Remove-Variable HelmChartRoot -ErrorAction Ignore
$script:TestResultsRoot = $null
$script:UniversalPacakgeRoot = $null

foreach($taskDir in $Tasks) {
    $initialize = Join-Path $taskDir "_Initialize.ps1"
    if (Test-Path $initialize) {
        . $initialize
    }
}
```

> **Why `Remove-Variable` for `$HelmChartRoot`?**
> The base script's param block declares `[string]$HelmChartRoot`. The `[string]` type constraint converts `$null` to `""` (empty string). Since `""` is not `$null`, the `??=` operator in `_Initialize.ps1` won't overwrite it. `Remove-Variable` fully removes the typed variable so `??=` works on the next run.

Re-running `_Initialize.ps1` also **re-imports all `.Task.ps1` files**. Since `Add-BuildTask` replaces existing tasks with the same name, the re-imported tasks get the correct `$BuildRoot` context (stored in the task's `B1` property).

## Complete Example

### Base script: `build.example.ps1`

Located in `LD.Platform.BuildTasks`. Contains shared parameters, initialization, bootstrapping, and aggregate task definitions (CI, Build, Test, etc.).

### Derived script: `build.build.ps1`

Located in the consuming project (e.g., `LD.Shared.EnterprisePlatformServices.API`):

```powershell
<#
.SYNOPSIS
    ./build.build.ps1
.EXAMPLE
    Invoke-Build
#>
[CmdletBinding()]
param(
    [ValidateScript({"..\LD.Platform.BuildTasks\build.example.ps1"})]
    $Extends
)

$Tasks = "../LD.Platform.BuildTasks/tasks", "../BuildTasks/tasks", "../tasks/tasks", "tasks" |
    Convert-Path -ErrorAction Ignore

## Self-contained: can be invoked directly or via Invoke-Build
if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    foreach ($taskDir in $Tasks) {
        $bootstrap = Join-Path $taskDir "_BootStrap.ps1"
        if (Test-Path $bootstrap) { . $bootstrap }
    }
    Invoke-Build -File $MyInvocation.MyCommand.Path @PSBoundParameters -Result Result
    if ($Result.Error) {
        $Error[-1].ScriptStackTrace | Out-Host
        exit 1
    }
    exit 0
}

## Re-initialize with this project's $BuildRoot
Remove-Variable HelmChartRoot -ErrorAction Ignore
$script:TestResultsRoot = $null
$script:UniversalPacakgeRoot = $null
foreach($taskDir in $Tasks) {
    $initialize = Join-Path $taskDir "_Initialize.ps1"
    if (Test-Path $initialize) { . $initialize }
}

## Project-specific aggregate tasks
Add-BuildTask HelmBuild InstallRequiredModules, GetVersion, HelmUpdateValuesSchema
Add-BuildTask HelmTest HelmBuild, HelmTestChart
Add-BuildTask HelmPack HelmTest, HelmPackChart
Add-BuildTask HelmPush HelmPack, HelmPushChart
```

## Multiple Inheritance and Prefixing

Invoke-Build also supports extending multiple scripts and renaming inherited tasks with a prefix using `::` syntax:

```powershell
param(
    [ValidateScript({
        "MyPrefix::..\Base1\build.ps1"
        "..\Base2\build.ps1"
    })]
    $Extends
)
```

Tasks from `Base1` would be prefixed (e.g., `MyPrefix::Build`), while tasks from `Base2` keep their original names. Tasks named `.` (the default task) are never renamed.

## Quick Reference

| Concept | Detail |
|---|---|
| **Minimum Invoke-Build version** | 5.11.0 |
| **Parameter name** | Must be `$Extends` |
| **Path resolution** | Relative to the derived script's directory |
| **Task redefinition** | `Add-BuildTask` with same name replaces the base's version |
| **`$BuildRoot` during Extends** | Set to the **base** script's directory |
| **`$BuildRoot` in derived body** | Set to the **derived** script's directory |
| **Variables using `??=`** | Must be reset before re-initialization |
| **`[string]` typed params** | Use `Remove-Variable` instead of `= $null` to reset |

## Further Reading

- [Invoke-Build Extends documentation](https://github.com/nightroman/Invoke-Build/tree/main/Tasks/Extends)
- [Invoke-Build wiki](https://github.com/nightroman/Invoke-Build/wiki)
