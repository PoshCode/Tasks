
### Step 1: Analyze Repository Structure

**Action:** Identify all solution files and their locations.

**Instructions:**
1. Search for all `.sln` files in the repository
2. For each solution file found in a subdirectory (not in root), note:
   - The subdirectory name (e.g., `LD.JV.Builder`)
   - The solution file name (e.g., `LD.JV.Builder.sln`)
   - The projects contained in that solution
3. Create a mapping of subdirectory → new root-level solution name:
   - Pattern: If subdirectory is `LD.JV.Builder` and solution is `LD.JV.Builder.sln`, create root-level `LD.JV.Builder.sln`
   - Pattern: If subdirectory is `LD.JV.BuilderAsync` and solution is `LD.JV.BuilderAsync.sln`, create root-level `LD.JV.BuilderAsync.sln`
   - Pattern: If subdirectory is `LD.JV.PlatformEvent.Common` and solution is `LD.JV.PlatformEvent.Common.sln`, create root-level `LD.JV.PlatformEvent.Common.sln`

**Expected Output Format:**

After completing Step 1, provide a summary in this format:

```
## Step 1 Complete: Repository Structure Analysis

### Solution Files Found

**1. [Solution Name]**
- **Location:** [Full path to current solution file]
- **Subdirectory:** [Subdirectory name]
- **New root-level name:** [Name for root solution file]

**Projects contained ([count] total):**
- **Main/API Projects:**
  - [Project names that are web apps or APIs]

- **Library Projects:**
  - [Project names that are libraries]

- **Test Projects:**
  - [Project names that are test projects]

[Repeat for each solution found]

### Summary

- **[N] solution files** found in subdirectories
- **[Solution1.sln]** will be moved from `[SubDir]/` to root with updated paths (prefix: `[SubDir]\`)
- **[Solution2.sln]** will be moved from `[SubDir]/` to root with updated paths (prefix: `[SubDir]\`)
```

### Step 2: Create Root-Level Solution Files

**Action:** For each subdirectory solution one level deep from the root, move the solution file to the root and update the project paths.

**Instructions:**
1. Read the original solution file from the subdirectory
2. Update all project paths in the solution file to be relative from the repository root:
   - **Original path pattern:** `ProjectName\ProjectName.csproj` (relative to subdirectory)
   - **New path pattern:** `SubdirectoryName\ProjectName\ProjectName.csproj` (relative to root)
4. Preserve all project GUIDs, configurations, and solution items
5. Update any solution items paths (like NuGet.config) to reference the subdirectory:
   - **Original:** `NuGet.config = NuGet.config`
   - **New:** `NuGet.config = SubdirectoryName\NuGet.config`

**Example Transformation:**

Original solution in `LD.JV.Builder/LD.JV.Builder.sln`:
```
Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "LD.JV.Builder.Host.Web", "LD.JV.Builder.Host.Web\LD.JV.Builder.Host.Web.csproj", "{GUID}"
```

New solution in root `LD.JV.Builder.sln`:
```
Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "LD.JV.Builder.Host.Web", "LD.JV.Builder\LD.JV.Builder.Host.Web\LD.JV.Builder.Host.Web.csproj", "{GUID}"
```

### Step 3: Delete Original Subdirectory Solution Files

**Action:** Remove the old solution files from subdirectories.

**Instructions:**
1. For each solution file that was in a subdirectory (e.g., `LD.JV.Builder/LD.JV.Builder.sln`), delete it using `git rm`
2. **Do not delete:**
   - Project files (.csproj, .fsproj, etc.)
   - Source code
   - Tests
   - Docker files
   - Any other non-solution files

**Why:** The root-level solution files replace the subdirectory solutions. Keeping both would cause confusion and maintenance issues.
