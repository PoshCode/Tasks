# Build Script Inheritance with Invoke-Build `Extends`

Invoke-Build (v5.11+) supports a special `$Extends` parameter that enables **build script inheritance**. A project's build script can extend the base scripts and inherit their parameters, initialization, and task definitions. We've organized our tasks into framework folders, and each framework has a `base.ps1` script in it. To create a build, you'll want to extend one or more of those!

## How It Works

### The `$Extends` Parameter

A build script declares a `param` block with a `ValidateScript` attribute on a parameter named `$Extends` that returns the paths to the base script(s) you want to inherit.

```powershell
param(
    [ValidateScript({
        @(
            "../*BuildTasks/dotnet/base.ps1"
            "../*BuildTasks/helm/base.ps1"
        ) | Resolve-Path
    })]
    $Extends,
    $TargetFramework = "net8.0"
)
```

When Invoke-Build processes this script:

1. It finds the `$Extends` parameter with a `ValidateScript` attribute
2. It **evaluates the ValidateScript** to get the path(s) to base script(s)
3. It resolves those paths relative to the script's directory (`$BuildRoot`)
4. It **processes the base scripts first**
5. Then it processes the build script's body

Note that the `ValidateScript` block is not used for validation.
In fact, no value is ever passed to that parameter.
Invoke-Build uses it solely to determine the base scripts.

### What Gets Inherited

| Inherited from base | How |
|---|---|
| **Parameters** | The variables in each base script's `param()` block become script variables and parameters to Invoke-Build. The derived script gets `-Clean`, `-TargetFramework`, `-ChartName`, etc. without redeclaring them. |
| **Task definitions** | Tasks defined in base scripts (and their imported `.Task.ps1` files) carry over automatically. |
| **Script body code** | Lightweight initialization and task imports execute during base processing. |
| **Enter-Build blocks** | Each base script's `Enter-Build` block runs (in order) before the first task. |

### What the Derived Script Controls

- **Override tasks** -- Calling `Add-BuildTask` with the same name as any existing task **replaces** it (the old definition is moved to a "Redefined" list).
- **Add new tasks** -- Define project-specific tasks not in the base.
- **Redirect `$BuildRoot`** -- Base scripts use `$BuildRoot = $BuildRoots[-1]` to point at the consuming project's directory (see [`$BuildRoot` Flow](#buildroot-flow-with-the-modern-buildscripts-architecture) below).

## Multiple Inheritance and Prefixing

Invoke-Build supports specifying a extending multiple scripts and renaming inherited tasks with a prefix using `::` syntax:

```powershell
param(
    [ValidateScript({
        "dotnet::../dotnet/base.ps1"
        "../common/base.ps1"
    })]
    $Extends
)
```

Tasks from `dotnet/base` would be prefixed (e.g., `dotnet::Build`), while tasks from `common` keep their original names. Tasks named `.` (the default task) are never renamed.

## Parameter Inheritance

### How Parameters Are Merged

Invoke-Build discovers parameters by walking the Extends chain **depth-first**. Each script's `param()` block is read, and its parameters are added to a global dictionary. Since it's a dictionary, **the last script to declare a parameter wins** (its type, attributes, and default value become the "official" definition for that parameter).

For our architecture, the Extends chain and discovery order looks like this:

```
extend.build.ps1                               ← discovery starts here
  ├── Extends: helm/base.ps1                         ← listed first
  │     └── Extends: common/base.ps1                 ← helm's base
  └── Extends: dotnet/base.ps1                       ← listed second
        └── Extends: common/base.ps1                 ← dotnet's base (diamond)
```

Parameter discovery order (depth-first recursion):

```
┌─────────────────────────────────────────────────────────────────────┐
│ PARAMETER DISCOVERY (depth-first)                                   │
│                                                                     │
│  1. common/base.ps1     → $Clean, $CollectCoverage                  │
│  2. helm/base.ps1       → $HelmChartRoot, $ChartName                │
│  3. common/base.ps1     → $Clean, $CollectCoverage    (same, no-op) │
│  4. dotnet/base.ps1     → $Configuration, $Solution,                |
|                           $dotnetSolution, $dotnetOptions,          │
│                      $TargetFramework = "net10.0",  ← registered    │
│                      $TargetRuntime                                 │
│  5. extend.build.ps1 → $TargetFramework = "net8.0" ← OVERWRITES!    │
│                                                                     │
│  Final param dictionary for $TargetFramework:                       │
│    default = "net8.0" (from extend.build.ps1, the last writer)      │
└─────────────────────────────────────────────────────────────────────┘
```

### User-Provided Values vs Defaults

There are two cases when a parameter is defined in multiple scripts:

**Case 1: User provides a value on the command line**

```powershell
Invoke-Build Build -TargetFramework net9.0
```

The user-provided value is **splatted to every script that declares that parameter**. All scripts see `$TargetFramework = "net9.0"`. No conflict.

**Case 2: No user-provided value (defaults apply)**

Each script's `param()` block evaluates its own default expression when that script is dot-sourced. Since all scripts share the same scope, **the last script body to run overwrites the variable**:

```
┌─────────────────────────────────────────────────────────────────────┐
│ LOADING PHASE -- $TargetFramework default resolution                │
│                                                                     │
│  BB[0] common/base.ps1 body runs                                   │
│  │  (does not declare $TargetFramework)                            │
│  ▼                                                                  │
│  BB[1] helm/base.ps1 body runs                                      │
│  │  (does not declare $TargetFramework)                            │
│  ▼                                                                  │
│  BB[2] common/base.ps1 body runs (diamond -- guard returns early)    │
│  ▼                                                                  │
│  BB[3] dotnet/base.ps1 body runs                                     │
│  │  param($TargetFramework = "net10.0")                            │
│  │  $TargetFramework is now "net10.0" ← dotnet's default          │
│  ▼                                                                  │
│  BB[4] extend.build.ps1 body runs                                  │
│  │  param($TargetFramework = "net8.0")                             │
│  │  $TargetFramework is now "net8.0"  ← OVERWRITES! derived wins  │
│  ▼                                                                  │
│  Final: $TargetFramework = "net8.0"                                │
└─────────────────────────────────────────────────────────────────────┘
```

**The derived (root) script's default always wins**, because it runs last.

### Parameters in Enter-Build

All `Enter-Build` blocks run **after all script bodies have completed**. They execute in the shared script scope, so they see the **final parameter values** -- not the intermediate values their script's body saw:

```
┌─────────────────────────────────────────────────────────────────────┐
│ PARAMETER VALUES OVER TIME                                          │
│                                                                     │
│  dotnet/base.ps1 body:                                              │
│  │  $TargetFramework = "net10.0"  ← dotnet's default at this point│
│  │  Write-Verbose "TARGETFRAME: $TargetFramework"                  │
│  │  # prints: "net10.0"                                            │
│  ▼                                                                  │
│  extend.build.ps1 body:                                             │
│  │  $TargetFramework = "net8.0"   ← overwrites to derived default │
│  ▼                                                                  │
│  ─── all bodies done, Enter-Build phase begins ───                  │
│                                                                     │
│  common/base.ps1 Enter-Build:                                        │
│  │  $Clean is available (parameter from common/base.ps1)            ✓   │
│  ▼                                                                  │
│  helm/base.ps1 Enter-Build:                                          │
│  │  $HelmChartRoot is available (parameter from helm/base.ps1)      ✓   │
│  ▼                                                                  │
│  dotnet/base.ps1 Enter-Build:                                        │
│  │  $TargetFramework = "net8.0"   ← sees the FINAL value      ✓   │
│  │  Write-Verbose "Enter-Build: TARGETFRAME: $TargetFramework"     │
│  │  # prints: "net8.0" -- NOT "net10.0"!                           │
│  ▼                                                                  │
│  extend.build.ps1: (no Enter-Build)                                 │
└─────────────────────────────────────────────────────────────────────┘
```

**Key rule**: Enter-Build blocks can reference any parameter from any script in the chain -- they all share the same scope. But when a parameter is declared in multiple scripts, Enter-Build always sees the derived script's default (or the user-provided value).

### Parameter Default Expressions and `$PSScriptRoot`

Parameter default expressions evaluate in the context of **their declaring script**. This matters when defaults use `$PSScriptRoot`:

```powershell
# In helm/base.ps1 -- $PSScriptRoot = C:\...\LD.Platform.BuildTasks\helm
param(
    [string]$HelmChartRoot = @(
        if (Get-ChildItem -Path "$PSScriptRoot/charts" ...) {  # ← helm.ps1's dir
            Resolve-Path "$PSScriptRoot/charts"
        }
    )[0]
)
```

When used via Extends, `$PSScriptRoot` resolves to `helm/`, not the project directory. This is why scripts re-evaluate path-dependent params in their body after redirecting `$BuildRoot`:

```powershell
# In helm/base.ps1 body -- after $BuildRoot = $BuildRoots[-1]
if ($BuildRoots.Count -gt 1 -and -not $HelmChartRoot) {
    $HelmChartRoot = @(
        if (Get-ChildItem -Path "$BuildRoot/charts" ...) {  # ← project dir
            Resolve-Path "$BuildRoot/charts"
        }
    )[0]
}
```

### Diamond Inheritance and the Guard Pattern

When `extend.build.ps1` extends both `helm/base.ps1` and `dotnet/base.ps1`, and both extend `common/base.ps1`, the base script gets loaded twice. The guard pattern prevents double-initialization:

```powershell
# In common/base.ps1
if ($script:_BuildBaseInitialized) { return }
$script:_BuildBaseInitialized = $true
```

```
┌─────────────────────────────────────────────────────────────────────┐
│ DIAMOND INHERITANCE                                                 │
│                                                                     │
│  BB[0] common/base.ps1 (from helm/base.ps1's chain)                │
│  │  Guard: $false → runs fully, registers Enter-Build              │
│  ▼                                                                  │
│  BB[1] helm/base.ps1                                                │
│  ▼                                                                  │
│  BB[2] common/base.ps1 (from dotnet/base.ps1's chain)              │
│  │  Guard: $true → return (body skipped, NO Enter-Build registered)│
│  ▼                                                                  │
│  BB[3] dotnet/base.ps1                                              │
│  ▼                                                                  │
│  BB[4] extend.build.ps1                                             │
│                                                                     │
│  Enter-Build runs for: BB[0], BB[1], BB[3], BB[4]                  │
│  (BB[2] has no Enter-Build because its body returned early)         │
└─────────────────────────────────────────────────────────────────────┘
```

### Parameter Inheritance Summary

```
┌──────────────────────────────┬──────────────────────────────────────┐
│ Scenario                     │ Behavior                             │
├──────────────────────────────┼──────────────────────────────────────┤
│ User passes -Param value     │ All scripts see "value"              │
│ Only one script defines it   │ That script's default is used        │
│ Multiple scripts define it   │ Last body to run wins (= derived)    │
│ $PSScriptRoot in defaults    │ Resolves to declaring script's dir   │
│ Enter-Build reads a param    │ Sees the final value after all bodies│
│ Diamond inheritance          │ Guard prevents double-init           │
│ Param from any base          │ Available everywhere (shared scope)  │
└──────────────────────────────┴──────────────────────────────────────┘
```

## `$BuildRoot` Flow with the Framework Folder Architecture

The modern approach uses composable scripts in framework folders (`common/base.ps1`, `dotnet/base.ps1`, `helm/base.ps1`) with `Enter-Build` for heavy initialization. Here's how `$BuildRoot` flows through the entire lifecycle.

### The Extends Chain

```
extend.build.ps1  (C:\XDL\LD.Shared.EnterprisePlatformServices.API\)
  ├── Extends: helm/base.ps1    (C:\XDL\LD.Platform.BuildTasks\helm\)
  │     └── Extends: common/base.ps1
  └── Extends: dotnet/base.ps1  (C:\XDL\LD.Platform.BuildTasks\dotnet\)
        └── Extends: common/base.ps1  (diamond -- guarded)
```

### Phase 1: Loading (script bodies run)

Invoke-Build processes scripts **base-first → derived-last** (depth-first). Each script gets its own build block (`B1`) with its own `$BuildRoot` set to that script's directory:

```
┌────────────────────────────────────────────────────────────────────┐
│ LOADING PHASE  (runs for ??, ?, and real builds)                   │
│                                                                    │
│  ┌──── BB[0]: common/base.ps1 (from helm/base.ps1's chain) ─────┐  │
│  │  $BuildRoot = C:\...\LD.Platform.BuildTasks\buildscripts\    │  │
│  │  $BuildRoots = @(                                            │  │
│  │    "C:\...\buildscripts\",                           ← [0]   │  │
│  │    "C:\...\buildscripts\",                           ← [1]   │  │
│  │    "C:\...\EnterprisePlatformServices.API\"          ← [-1]  │  │
│  │  )                                                           │  │
│  │  $BuildRoot = $BuildRoots[-1]   ← REDIRECTS to project dir!  │  │
│  │  # Sets preferences, $BuildSystem, $BranchName, etc.         │  │
│  │  # Imports .Task.ps1 files                                   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              ↓                                     │
│  ┌──── BB[1]: helm/base.ps1 ────────────────────────────────────┐  │
│  │  $BuildRoot = $BuildRoots[-1]   ← REDIRECTS to project dir!  │  │
│  │  # Re-evaluates $HelmChartRoot from project dir              │  │
│  │  # Sets $script:HelmChartRoot for task If conditions         │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              ↓                                     │
│  ┌──── BB[2]: common/base.ps1 (from dotnet/base.ps1 ) ──────────┐  │
│  │  Guard: $_BuildBaseInitialized = $true → return              │  │
│  │  (body skipped, no Enter-Build registered)                   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              ↓                                     │
│  ┌──── BB[3]: dotnet/base.ps1 ──────────────────────────────────┐  │
│  │  $BuildRoot = $BuildRoots[-1]   ← REDIRECTS to project dir!  │  │
│  │  # Re-evaluates $dotnetSolution from project dir             │  │
│  │  # Sets $script:dotnetSolution for task If conditions        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              ↓                                     │
│  ┌──── BB[4]: extend.build.ps1 ─────────────────────────────────┐  │
│  │  $BuildRoot = C:\...\EnterprisePlatformServices.API\         │  │
│  │  (no redirect needed -- already the root script)             │  │
│  │  # Defines aggregate tasks: Restore, Build, Test, Pack, Push │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  After loading, $BuildRoot is RESOLVED and LOCKED (made constant)  │
│  per build block. Each BB remembers its final $BuildRoot.          │
└────────────────────────────────────────────────────────────────────┘
```

### Phase 2: Enter-Build (only real builds)

`Enter-Build` blocks run **in inheritance order** (base first → derived last), each with its BB's stored `$BuildRoot`. This phase is **skipped entirely** for `??`, `?`, and `WhatIf` queries -- making task listing fast.

```
┌─────────────────────────────────────────────────────────────────────┐
│ ENTER-BUILD PHASE  (skipped for ?? and ? queries)                  │
│                                                                     │
│  BB[0] common/base.ps1 Enter-Build:                                 │
│  │  $BuildRoot = ...EnterprisePlatformServices.API\  (redirected)  │
│  │  Creates Output/, testresults/ dirs                              │
│  │  Sets $OutputPath, $TestResultsRoot, $GHTools, etc.             │
│  ▼                                                                  │
│  BB[1] helm/base.ps1 Enter-Build:                                   │
│  │  $BuildRoot = ...EnterprisePlatformServices.API\  (redirected)  │
│  │  Sets $helmOutputPath, $ACRName, enumerates charts              │
│  ▼                                                                  │
│  BB[2] common/base.ps1: (diamond -- no Enter-Build)                 │
│  ▼                                                                  │
│  BB[3] dotnet/base.ps1 Enter-Build:                                 │
│  │  $BuildRoot = ...EnterprisePlatformServices.API\  (redirected)  │
│  │  Sets $SolutionOutputPath, runs dotnet sln list, etc.             │
│  ▼                                                                  │
│  BB[4] extend.build.ps1:  (no Enter-Build defined)                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

`Exit-Build` blocks run in **reverse order** (derived first → base last), including on failures.

### Phase 3: Task Execution

Each **task** remembers which BB defined it (stored in `$Task.B1`). When a task runs, `$BuildRoot` is set from that task's BB -- and that BB's `Enter-BuildTask` / `Exit-BuildTask` blocks are invoked:

```
┌─────────────────────────────────────────────────────────────────────┐
│ TASK EXECUTION                                                      │
│                                                                     │
│  Task "Build" (defined in extend.build.ps1 → BB[4])               │
│  │  $BuildRoot = ...EnterprisePlatformServices.API\                │
│  │                                                                  │
│  ├─► Task "Build-DotNet" (imported by common/base.ps1 → BB[0])     │
│  │   $BuildRoot = ...EnterprisePlatformServices.API\ (redirected) │
│  │   Enter-BuildTask from BB[0] runs (if defined)                  │
│  │   Exit-BuildTask  from BB[0] runs (if defined)                  │
│  ...                                                                │
└─────────────────────────────────────────────────────────────────────┘
```

### The Key Insight: `$BuildRoots[-1]`

Without the `$BuildRoot = $BuildRoots[-1]` redirect in `common/base.ps1`, `helm/base.ps1`, and `dotnet/base.ps1`, `$BuildRoot` would point to the **base script's** directory. That's wrong because paths like `Join-Path $BuildRoot "charts"` or `Join-Path $BuildRoot "Output"` need to resolve relative to the **consuming project**, not the shared build framework.

The `$BuildRoots` array is available during loading and always has `[-1]` pointing to the root (derived) script's directory. So `$BuildRoot = $BuildRoots[-1]` is the standard pattern to redirect `$BuildRoot` upward to the consuming project.

### Why `Enter-Build` Matters

| What | Body (loading) | `Enter-Build` |
|---|---|---|
| **When it runs** | Always (including `??`, `?`, WhatIf) | Only for real builds |
| **Use for** | Lightweight setup, task `If` variables | Directory creation, expensive commands |
| **`$BuildRoot`** | Set per-BB, can be redirected | Set per-BB, already locked |
| **Task `If` scriptblocks** | Can reference body variables | Can reference Enter-Build variables |

Task `If` conditions that reference variables set in `Enter-Build` **must** be wrapped in `{}` scriptblocks so they evaluate at runtime (after Enter-Build) rather than at definition time (during loading).

## `Enter-Build` Architecture

### The Problem: Loading ≠ Building

Every time Invoke-Build touches your script -- even just to list tasks (`??`), show help (`?`), or run with `-WhatIf` -- it executes the **entire script body**. Before `Enter-Build`, that meant every query paid the full cost of initialization:

```
┌─────────────────────────────────────────────────────────────────────┐
│ BEFORE: Everything in the script body                              │
│                                                                     │
│  User runs: Invoke-Build ??                                        │
│                                                                     │
│  Script body executes:                                              │
│  ├── $BuildRoot redirect                         (lightweight) ✓   │
│  ├── Set preferences, $BuildSystem               (lightweight) ✓   │
│  ├── New-Item Output/, testresults/ dirs          (side effect) ✗   │
│  ├── dotnet sln list, dotnet --version            (expensive)   ✗   │
│  ├── Get-ChildItem for Helm charts                (expensive)   ✗   │
│  ├── Initialize $GHTools, $TempDirectory          (not needed)  ✗   │
│  └── Define tasks                                 (required)    ✓   │
│                                                                     │
│  Result: Slow ?? queries, directories created unnecessarily,        │
│          external commands run for no reason                         │
└─────────────────────────────────────────────────────────────────────┘
```

### The Solution: Split Body vs Enter-Build

`Enter-Build` is a special block that Invoke-Build calls **only when actually building** -- after loading, after task resolution, right before the first task runs. Each script in the Extends chain gets its own independent `Enter-Build`.

```
┌─────────────────────────────────────────────────────────────────────┐
│ AFTER: Split between body and Enter-Build                          │
│                                                                     │
│  ┌── SCRIPT BODY (runs ALWAYS, even for ??) ─────────────────────┐ │
│  │                                                                │ │
│  │  # Lightweight, no side effects                                │ │
│  │  $BuildRoot = $BuildRoots[-1]          ← redirect             │ │
│  │  $script:BuildSystem = ...             ← env detection        │ │
│  │  $script:BranchName = ...              ← git branch           │ │
│  │  $script:dotnetSolution = ...          ← for task If          │ │
│  │  $script:HelmChartRoot = ...           ← for task If          │ │
│  │  Set-BuildHeader { ... }               ← cosmetic             │ │
│  │                                                                │ │
│  │  # Task definitions                                            │ │
│  │  Add-BuildTask Build-DotNet @{ If = { $script:dotnetSolution } │ │
│  │  Add-BuildTask Pack-Helm @{ If = { $script:ChartName } }  │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌── ENTER-BUILD (runs ONLY for real builds) ────────────────────┐ │
│  │                                                                │ │
│  │  # Heavy init, side effects OK                                 │ │
│  │  New-Item $OutputPath -Type Directory     ← creates dirs      │ │
│  │  New-Item $TestResultsRoot -Type Directory                     │ │
│  │  dotnet sln list                          ← expensive call    │ │
│  │  dotnet --version                         ← expensive call    │ │
│  │  Get-ChildItem for $HelmCharts            ← chart enumeration │ │
│  │  $script:GHTools = ...                    ← tool registration │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### How Enter-Build Executes Across the Extends Chain

Each script registers its own `Enter-Build` block. They run **in inheritance order**, each with the correct `$BuildRoot`, and each in the **script scope** (as if the code were written directly in the script body):

```
┌─────────────────────────────────────────────────────────────────────┐
│ Invoke-Build Build                                                  │
│                                                                     │
│  1. LOAD all scripts (bodies run)                                   │
│     BB[0] always.ps1 body   → registers Enter-Build { ... }        │
│     BB[1] helm.ps1 body     → registers Enter-Build { ... }        │
│     BB[2] always.ps1 body   → guard returns early (diamond)        │
│     BB[3] dotnet.ps1 body   → registers Enter-Build { ... }        │
│     BB[4] extend.build.ps1  → (no Enter-Build)                     │
│                                                                     │
│  2. RESOLVE tasks, check for missing references                     │
│                                                                     │
│  3. RUN Enter-Build blocks (in order):                              │
│                                                                     │
│     BB[0] always.ps1 Enter-Build:                                  │
│     │  $BuildRoot = ...EnterprisePlatformServices.API\             │
│     │  ┌─────────────────────────────────────────────┐             │
│     │  │ $Script:OutputPath = Join-Path $BuildRoot   │             │
│     │  │    'Output'                                 │             │
│     │  │ New-Item $OutputPath -Force                 │             │
│     │  │ $Script:TestResultsRoot = ...               │             │
│     │  │ New-Item $TestResultsRoot -Force            │             │
│     │  │ $Script:GHTools = @{}                       │             │
│     │  │ $Script:UniversalPackageRoot = ...          │             │
│     │  └─────────────────────────────────────────────┘             │
│     ▼                                                               │
│     BB[1] helm.ps1 Enter-Build:                                    │
│     │  $BuildRoot = ...EnterprisePlatformServices.API\             │
│     │  ┌─────────────────────────────────────────────┐             │
│     │  │ # Can see $OutputPath from BB[0]'s          │             │
│     │  │ # Enter-Build (shared script scope)         │             │
│     │  │ $script:helmOutputPath = Join-Path          │             │
│     │  │    $OutputPath "charts"                     │             │
│     │  │ $script:HelmCharts = Get-ChildItem ...      │             │
│     │  │ $script:GHTools.add("kubeconform", ...)     │             │
│     │  └─────────────────────────────────────────────┘             │
│     ▼                                                               │
│     BB[2] always.ps1: (diamond -- no Enter-Build registered)        │
│     ▼                                                               │
│     BB[3] dotnet.ps1 Enter-Build:                                  │
│     │  $BuildRoot = ...EnterprisePlatformServices.API\             │
│     │  ┌─────────────────────────────────────────────┐             │
│     │  │ # $TargetFramework = "net8.0" (final value) │             │
│     │  │ $script:SolutionOutputPath = Join-Path        │             │
│     │  │    $OutputPath $SolutionName           │             │
│     │  │ dotnet sln list → $dotnetProjects           │             │
│     │  │ dotnet --version → $DotNetVersion           │             │
│     │  └─────────────────────────────────────────────┘             │
│     ▼                                                               │
│     BB[4] extend.build.ps1: (no Enter-Build -- nothing to do)       │
│                                                                     │
│  4. RUN tasks: Build → Build-DotNet → ...                           │
│                                                                     │
│  5. RUN Exit-Build blocks (REVERSE order):                          │
│     BB[4] extend.build.ps1  → (none)                               │
│     BB[3] dotnet.ps1        → (none currently)                     │
│     BB[2] always.ps1        → (none, diamond)                      │
│     BB[1] helm.ps1          → (none currently)                     │
│     BB[0] always.ps1        → (none currently)                     │
└─────────────────────────────────────────────────────────────────────┘
```

### The `If` Scriptblock Rule

Because task `If` conditions are evaluated **at task definition time** (during loading), but `Enter-Build` variables don't exist yet at that point, any `If` that references an `Enter-Build` variable must be wrapped in `{}`:

```
┌─────────────────────────────────────────────────────────────────────┐
│ TIMELINE                                                            │
│                                                                     │
│  Loading          Enter-Build          Task If eval    Task runs   │
│  ────┬──────────────┬───────────────────┬──────────────┬──────     │
│      │              │                   │              │            │
│      │ If = $var    │                   │              │            │
│      │ ↑ evaluates  │                   │              │            │
│      │ NOW → $null! │                   │              │            │
│      │              │                   │              │            │
│      │ If = { $var }│                   │ ← evaluates  │            │
│      │ ↑ stores the │                   │    HERE with │            │
│      │ scriptblock  │  $var = "value"   │    "value" ✓ │            │
│      │              │  ↑ set here       │              │            │
│  ────┴──────────────┴───────────────────┴──────────────┴──────     │
└─────────────────────────────────────────────────────────────────────┘

# WRONG -- evaluates to $null during loading, task always skips:
Add-BuildTask Install-GitHubTools @{ If = $script:GHTools.Count -gt 0 }

# RIGHT -- deferred to runtime, evaluates after Enter-Build sets $GHTools:
Add-BuildTask Install-GitHubTools @{ If = { $script:GHTools.Count -gt 0 } }
```

### What Goes Where -- Decision Guide

```
┌──────────────────────────────────┬────────────┬──────────────┐
│ Code                             │ Body       │ Enter-Build  │
├──────────────────────────────────┼────────────┼──────────────┤
│ $BuildRoot = $BuildRoots[-1]     │     ✓      │              │
│ $script:BuildSystem = ...        │     ✓      │              │
│ $script:BranchName = ...         │     ✓      │              │
│ $script:dotnetSolution = ...     │     ✓      │              │
│ $script:HelmChartRoot = ...      │     ✓      │              │
│ Set-BuildHeader / Set-BuildFooter│     ✓      │              │
│ Add-BuildTask ...                │     ✓      │              │
│ . $taskfile.FullName (imports)   │     ✓      │              │
├──────────────────────────────────┼────────────┼──────────────┤
│ New-Item (create directories)    │            │      ✓       │
│ dotnet sln list                  │            │      ✓       │
│ dotnet --version                 │            │      ✓       │
│ Get-ChildItem (chart enum)       │            │      ✓       │
│ $script:OutputPath = ...         │            │      ✓       │
│ $script:TestResultsRoot = ...    │            │      ✓       │
│ $script:GHTools = @{}            │            │      ✓       │
│ $script:dotnetProjects = ...     │            │      ✓       │
│ $Env:LDBUILD_* = ...             │            │      ✓       │
└──────────────────────────────────┴────────────┴──────────────┘
```

## Quick Reference

| Concept | Detail |
|---|---|
| **Minimum Invoke-Build version** | 5.11.0 |
| **Parameter name** | Must be `$Extends` |
| **Path resolution** | Relative to the derived script's directory |
| **Task redefinition** | `Add-BuildTask` with same name replaces the base's version |
| **`$BuildRoot` during Extends** | Set to the **base** script's directory |
| **`$BuildRoot` in derived body** | Set to the **derived** script's directory |
| **`$BuildRoots[-1]`** | Standard redirect to the consuming project's directory |
| **`Enter-Build`** | Heavy init deferred to build time; skipped for `??` / `?` |
| **Task `If` scriptblocks** | Wrap in `{}` if referencing `Enter-Build` variables |

## Further Reading

- [Invoke-Build Extends documentation](https://github.com/nightroman/Invoke-Build/tree/main/Tasks/Extends)
- [Invoke-Build wiki](https://github.com/nightroman/Invoke-Build/wiki)
