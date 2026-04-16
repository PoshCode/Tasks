# Troubleshooting: Edge Cases and Complex Scenarios

This section is a history of real-world problems encountered during build system implementations and what the solution ended up being. The earlier the case, the less applicable, as this repository is under constant development. We do have a summary at the top here, with some recommendations for preventing problems.

1. **Regular Dependency Audits**
    ```powershell
    # Check for outdated packages
    dotnet list package --outdated

    # Check for vulnerable packages
    dotnet list package --vulnerable
    ```

2. **Central Package Management**

    Use `Directory.Packages.props` for version management:

    ```xml
    <Project>
    <PropertyGroup>
        <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    </PropertyGroup>
    <ItemGroup>
        <PackageVersion Include="System.Text.Json" Version="8.0.0" />
        <PackageVersion Include="Moq" Version="4.20.0" />
    </ItemGroup>
    </Project>
    ```

3. **Upgrade Legacy Dependencies**
    - Prioritize upgrading internal packages to target modern .NET
    - Update test frameworks to current versions when feasible
    - Document upgrade blockers for future planning

4. **Monitor Build Warnings**
    - Review all NU1605 warnings even if build succeeds
    - Investigate NU1608 (version override) warnings
    - Track MSB3539 warnings about property modifications

5. **Test Framework Compatibility Matrix**
    | Framework | Last Version Supporting .NET Framework | First Version Supporting .NET 5+ |
    |-----------|---------------------------------------|-----------------------------------|
    | SpecFlow | 3.9.x | 3.10+ |
    | NUnit | 3.13.x | 3.13+ (both) |
    | xUnit | 2.4.x | 2.4+ (both) |
    | MSTest | 2.2.x | 2.2+ (both) |

---

## Edge Case 1: SpecRun Path Handling with Centralized Output

**Repository:** FeeEngine (LD.FeeEngine.API)

**Symptom:**
Build fails with path duplication error in SpecRun-based test projects:
```
error: The filename, directory name, or volume label syntax is incorrect. :
'C:\XDL\LD.FeeEngine.API\FeeEngine\LD.EPS.FeeEngine.BDD.Tests\C:\XDL\LD.FeeEngine.API\Output\FeeEngine\obj\...'
```

**Root Cause:**
SpecRun.SpecFlow targets file (version 3.9.31) does not correctly handle absolute paths in `BaseIntermediateOutputPath`. When the centralized build system sets this to an absolute path, SpecRun's targets attempt to concatenate it with the project directory path, resulting in malformed paths.

This is a known limitation of older SpecRun versions (pre-.NET 5) that assume `BaseIntermediateOutputPath` is always a relative path.

**Solution:**
Override the intermediate output path properties in the affected project to use a local relative path:

```xml
<PropertyGroup Label="Globals">
    <!-- Existing properties... -->
    <!-- Fix SpecRun path handling with custom output directories -->
    <BaseIntermediateOutputPath>obj\</BaseIntermediateOutputPath>
    <IntermediateOutputPath>$(BaseIntermediateOutputPath)\$(Configuration)\$(TargetFramework)\</IntermediateOutputPath>
</PropertyGroup>
```

**Trade-offs:**
- This project won't benefit from centralized intermediate output cleanup
- Creates a non-fatal warning about `BaseIntermediateOutputPath` being modified after MSBuild uses it
- Build artifacts (bin) still go to centralized location; only intermediate files (obj) are kept local
- Acceptable compromise until SpecRun is upgraded to version 3.10+ or SpecFlow 4.x

**When to Apply:**
- Projects using SpecRun.SpecFlow versions < 3.10
- Projects using SpecFlow.Plus.Runner with older versions
- Any test framework with custom MSBuild targets that assume relative paths

---

## Edge Case 2: Package Downgrade Errors from Legacy Dependencies

**Repository:** FeeEngine (LD.FeeEngine.API)

**Symptom:**
Build fails with NU1605 errors (package downgrade warnings treated as errors):
```
error NU1605: Warning As Error: Detected package downgrade: System.Diagnostics.Debug from 4.3.0 to 4.0.11
error NU1605: Warning As Error: Detected package downgrade: System.IO.FileSystem.Primitives from 4.3.0 to 4.0.1
error NU1605: Warning As Error: Detected package downgrade: System.Runtime.InteropServices from 4.3.0 to 4.1.0
error NU1605: Warning As Error: Detected package downgrade: System.Threading from 4.3.0 to 4.0.11
```

**Root Cause:**
Legacy internal packages (e.g., `LD.Common.AspNetCore 2.0.0.49`) or old test frameworks (e.g., `AutoFixture.AutoMoq 4.8.0`, `Moq 4.7.0`) create conflicting transitive dependency chains:

```
Project → LD.Common.AspNetCore 2.0.0.49
       → Microsoft.AspNetCore.Mvc.Core 2.2.0
       → Microsoft.Extensions.DependencyModel 2.1.0
       → Microsoft.DotNet.PlatformAbstractions 2.1.0
       → System.IO.FileSystem 4.0.1
       → runtime.win.System.IO.FileSystem 4.3.0
       → System.Diagnostics.Debug (>= 4.3.0)  ← Requires 4.3.0

But also:
Project → LD.Common.AspNetCore 2.0.0.49
       → Microsoft.Extensions.DependencyModel 2.1.0
       → System.Diagnostics.Debug (>= 4.0.11)  ← Allows 4.0.11
```

NuGet's dependency resolver chooses the lower version to satisfy both constraints, but this violates the "no downgrade" rule when `TreatWarningsAsErrors` is enabled.

**Solution:**
Add explicit package references for the higher versions required by transitive dependencies:

**For library projects with LD.Common.AspNetCore dependencies:**
```xml
<ItemGroup>
    <!-- Existing packages... -->
    <PackageReference Include="System.Diagnostics.Debug" Version="4.3.0" />
    <PackageReference Include="System.IO.FileSystem.Primitives" Version="4.3.0" />
    <PackageReference Include="System.Runtime.InteropServices" Version="4.3.0" />
</ItemGroup>
```

**For test projects with AutoFixture.AutoMoq dependencies:**
```xml
<ItemGroup>
    <!-- Existing packages... -->
    <PackageReference Include="System.Threading" Version="4.3.0" />
</ItemGroup>
```

**Why This Works:**
- Explicit package references take precedence over transitive dependencies in NuGet's resolution
- Forces NuGet to use version 4.3.0, satisfying all dependency constraints without downgrades
- System.* packages at version 4.3.0 (from .NET Core 1.x era) remain compatible with modern .NET
- At runtime, .NET 8.0+ uses built-in implementations; package references primarily satisfy NuGet's dependency graph

**Alternative Solutions (Not Recommended):**
- **Upgrade legacy packages:** Requires coordination across teams, potential breaking changes
- **Disable TreatWarningsAsErrors:** Reduces build quality, allows security vulnerabilities
- **Add NoWarn for NU1605:** Masks the problem without fixing it

**When to Apply:**
- Projects referencing legacy internal packages targeting .NET Framework or early .NET Core
- Test projects using older versions of Moq, AutoFixture, NSubstitute, or similar frameworks
- Any project with `TreatWarningsAsErrors=true` encountering NU1605 warnings

**Affected Projects in FeeEngine Example:**
- `LD.EPS.FeeEngine.ThirdPartyFramework` - Added 3 System.* packages
- `LD.EPS.FeeEngine.ClosingCorp` - Added 3 System.* packages
- `LD.EPS.FeeEngine.ClosingCorp.Tests` - Added System.Threading
- `LD.EPS.FeeEngine.ThirdPartyFees.Tests` - Added System.Threading
- `LD.EPS.FeeEngine.InRule.Tests` - Added System.Threading

---

## Edge Case 3: Understanding NuGet Dependency Resolution

**Background:**
Understanding how NuGet resolves package versions helps diagnose and fix dependency conflicts.

**NuGet Resolution Strategy:**
1. **Direct references win:** Explicit `<PackageReference>` in the project file takes highest precedence
2. **Nearest wins:** Among transitive dependencies, the package "nearest" to the project (fewest hops) is chosen
3. **Lowest compatible version:** When multiple versions satisfy constraints, NuGet picks the lowest version that works
4. **Downgrade detection:** If resolution results in using a lower version than required by any dependency, NU1605 is issued

**Example Dependency Graph:**
```
MyProject.csproj
├─ PackageA 2.0
│  └─ System.Text.Json >= 6.0.0
└─ PackageB 1.0
   └─ System.Text.Json >= 4.7.0

Resolution: System.Text.Json 6.0.0 (satisfies both >= 6.0.0 and >= 4.7.0)
```

**Downgrade Example:**
```
MyProject.csproj
├─ PackageA 2.0
│  └─ System.Text.Json 4.7.0 (exact version)
└─ PackageB 1.0
   └─ System.Text.Json >= 6.0.0

Resolution: System.Text.Json 4.7.0 (nearest wins, but downgrades from 6.0.0)
Warning NU1605: Detected package downgrade
```

**Fix:** Add explicit reference to override:
```xml
<PackageReference Include="System.Text.Json" Version="6.0.0" />
```

---

## Edge Case 4: Package Source Mapping Required with Central Package Management

**Repository:** LD.Shared.EnterprisePlatformServices.API (EPS)

**Symptom:**
Build fails with NU1507 errors when using Central Package Management with multiple NuGet sources:
```
error NU1507: Warning As Error: There are 6 package sources defined in your configuration.
When using central package management, please map your package sources with package source mapping
(https://aka.ms/nuget-package-source-mapping) or specify a single package source.
```

**Root Cause:**
When `Directory.Packages.props` enables Central Package Management (`<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>`), NuGet requires explicit package source mapping if multiple package sources are defined. This is a security feature to prevent dependency confusion attacks and ensure packages come from expected sources.

Without package source mapping, NuGet doesn't know which source to query for each package, leading to:
- Slower restore operations (queries all sources)
- Potential security risks (malicious packages from unexpected sources)
- Build failures when `TreatWarningsAsErrors` is enabled

**Solution:**
Add `<packageSourceMapping>` section to `nuget.config` to map package patterns to specific sources:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
    <add key="LDTS" value="https://nuget.loandepot.com/nuget/LDTS/v3/index.json" />
    <add key="LDTSQA" value="https://nuget.loandepot.com/nuget/LDTSQA/v3/index.json" />
    <add key="LoanDepot" value="https://nuget.loandepot.com/nuget/LoanDepot/v3/index.json" />
    <add key="EmpowerTest" value="https://nuget.loandepot.com/nuget/EmpowerTest/v3/index.json" />
    <add key="CUSA" value="https://nuget.loandepot.com/nuget/CUSA/v3/index.json" />
  </packageSources>

  <packageSourceMapping>
    <!-- Public packages from nuget.org -->
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>

    <!-- Internal LD.* packages from company feeds -->
    <packageSource key="LDTS">
      <package pattern="LD.*" />
    </packageSource>
    <packageSource key="LDTSQA">
      <package pattern="LD.*" />
    </packageSource>
    <packageSource key="LoanDepot">
      <package pattern="LD.*" />
    </packageSource>
    <packageSource key="EmpowerTest">
      <package pattern="LD.*" />
    </packageSource>
    <packageSource key="CUSA">
      <package pattern="LD.*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
```

**Package Pattern Guidelines:**
- Use `*` wildcard to match all packages from a source (typically nuget.org for public packages)
- Use specific patterns like `LD.*` to match company-internal packages
- Use `CompanyName.*` patterns for vendor-specific packages
- More specific patterns take precedence over wildcards

**Why This Works:**
- NuGet now knows to query nuget.org for all public packages (Microsoft.*, System.*, etc.)
- Internal LD.* packages are only queried from company feeds
- Eliminates ambiguity and improves restore performance
- Prevents accidental package substitution attacks

**Alternative Solutions (Not Recommended):**
- **Disable Central Package Management:** Loses version consistency benefits
- **Use single package source:** Requires consolidating all packages into one feed
- **Disable TreatWarningsAsErrors:** Reduces build quality, allows security issues

**When to Apply:**
- Any repository using Central Package Management (`Directory.Packages.props`)
- Repositories with multiple NuGet package sources
- Builds failing with NU1507 errors
- Organizations with internal package feeds alongside nuget.org

**Related Documentation:**
- [NuGet Package Source Mapping](https://aka.ms/nuget-package-source-mapping)
- [Central Package Management](https://learn.microsoft.com/nuget/consume-packages/central-package-management)

---

## Edge Case 5: System.* Package Compatibility

**Question:** Why are System.* packages from .NET Core 1.x (version 4.3.0) still compatible with .NET 8.0?

**Answer:**
- System.* packages (System.Threading, System.Diagnostics.Debug, etc.) are part of .NET Standard 2.0
- .NET Standard 2.0 is supported by all modern .NET versions (.NET Core 2.0+, .NET 5+, .NET Framework 4.6.1+)
- Modern .NET includes these types in the core framework (no separate package needed at runtime)
- Package references are primarily for NuGet's dependency graph resolution
- At runtime, .NET 8.0's built-in implementations are used (type forwarding)

**Verification:**
```powershell
# Check if package is actually used at runtime
dotnet publish MyProject.csproj -c Release
# System.* packages won't appear in publish output - they're built into the runtime
```

---