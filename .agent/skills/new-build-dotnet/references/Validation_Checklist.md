# Validation Checklist

## After implementation, verify:

- [ ] All original subdirectory solution files are deleted
- [ ] New root-level solution files exist for each releasable component
- [ ] All project paths in root solutions are correct and relative to root
- [ ] Subdirectory `Directory.Build.props` files import the root `Directory.Build.props`
- [ ] Publishable projects have `<IsPublishable>True</IsPublishable>`
- [ ] Packable projects have `<IsPackable>True</IsPackable>`
- [ ] Test projects have neither IsPublishable nor IsPackable set to True
- [ ] `.gitignore` includes `Output/` directory


## Test the Build

**Action:** Verify the build system works correctly by testing individual build tasks sequentially with the developer.

**Instructions:**

**IMPORTANT:** Each command must be run in PowerShell. A human must review the `Output/` directory after each command to ensure the results are as expected.

Agents should work with the developer to test each build task in sequence.

1. **Test package restore:**
    ```powershell
    Invoke-Build Initialize
    ```
    - Verifies NuGet packages can be restored
    - Checks package source configuration
    - Ensures all dependencies are available

2. **Test build:**
    ```powershell
    Invoke-Build Build
    ```
    - Compiles all projects in the solution
    - Validates project references
    - Confirms output paths are correct

3. **Test unit tests:**
    ```powershell
    Invoke-Build Test
    ```
    - Runs all test projects
    - Generates test results
    - Validates test discovery

4. **Test publish (for publishable projects):**
    ```powershell
    Invoke-Build Publish
    ```
    - Creates NuGet packages for projects marked `IsPackable=True`
    - Creates deployment artifacts for projects marked `IsPublishable=True`

5. **Verify outputs:**
    - Check that `Output/` directory is created in the repository root
    - Verify version.json is created with correct version information
    - Verify subdirectories exist: `Output/<SolutionName>/` should have `bin/`, `obj/`, etc.
    - Confirm build artifacts are in expected locations
        - Published websites go to `Output/publish/<ProjectName>/`
        - Packages go to `Output/nuget/`
        - Container images go to `Output/containers/`
    - All published output includes runtime dependencies
    - All published output includes correct version information

6. **Test full CI pipeline (after individual tasks succeed):**
   ```powershell
   Invoke-Build CI
   ```
   - Runs all tasks in sequence
   - Simulates continuous integration build
