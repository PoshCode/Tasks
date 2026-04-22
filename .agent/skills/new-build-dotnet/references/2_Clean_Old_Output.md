# Clean old Output and Intermediate directories

This only matters for developer workstations, where the project is checked out,
and has either been built previously or has been opened in Visual Studio
(or VS Code with the C# Dev Kit) which will automatically build it.

We need to get rid of the `obj` (and `bin`) directories in the project folders
because they contain intermediate output files including **source** files
like AssemblyInfo.cs, that will get recreated in the new `Output/` directory
causing conflicts and build errors.

## There are two easy ways

### Run `dotnet clean`

Ensure the project is not open in Visual Studio (or VS Code with the C# Dev Kit),
and run the `dotnet clean` command against each solution file.

This has to be done **before** you copy in the new `Directory.Build.props`,
while the projects will still point at the original output locations.

### Run `git clean`

As an alternative, you can run `git clean -ndX .` to list untracked files.
Review that list carefully to ensure that there's nothing you want to keep,
then run `git clean -fdX` to actually delete them.

The risk is that this includes local configuration files you want to keep.
