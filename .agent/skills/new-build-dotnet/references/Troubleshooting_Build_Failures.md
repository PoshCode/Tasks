# Common Issues and Solutions

## Issue: Build cannot find projects

**Symptom:** Error like "Project file does not exist"

**Solution:** Verify project paths in root solution files are correct and relative to repository root, not subdirectory.

## Issue: Output directory conflicts

**Symptom:** Build artifacts from different solutions overwrite each other

**Solution:** Ensure each root solution file has a unique name, which becomes the `SolutionName` variable used in output paths.

## Issue: GitVersion fails

**Symptom:** "No commits found on the current branch"

**Solution:**
- Ensure repository has at least one commit
- Run `git fetch --unshallow` if in a shallow clone
- Verify `GitVersion.yml` is in repository root

## Issue: Projects not inheriting root Directory.Build.props

**Symptom:** Output goes to default `bin/` and `obj/` directories in project folders

**Solution:** Add the import statement to subdirectory `Directory.Build.props` files as described in Step 4.

## Issue: Test projects being packed or published

**Symptom:** NuGet packages or publish folders created for test projects

**Solution:** Ensure test projects do NOT have `<IsPackable>True</IsPackable>` or `<IsPublishable>True</IsPublishable>`. The default from root `Directory.Build.props` is False for both.

## Issue: NU1507 errors with Central Package Management

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
