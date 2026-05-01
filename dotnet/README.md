# Build Tasks for .NET Projects

To use the dotnet build, be sure to [follow the instructions](.agent\skills\new-build-dotnet\SKILL.md)
in the `new-build-dotnet` skill, copying the assets and reading the references.

There are several files in the [`assets/`](.agent\skills\new-build-dotnet\assets) directory
that normalize output paths, properties, and tasks for our conventions.
These build scripts depend on those conventions about output paths and properties,
and won't work correctly without the Directory.Build.props and global.json from the assets.

The test task assumes the use of the Microsoft Testing Platform test runner,
which should be configured in a `global.json` in the project root. Otherwise, you'll need
to override the `Test-DotNet` task to use the test runner of your choice.

Additionally, all the dotnet commands are run against a _solution_ rather than individual projects.
This means we require (at least one) solution file, and we can only build one at a time.

See: <https://github.com/coverlet-coverage/coverlet/blob/master/Documentation/Coverlet.MTP.Integration.md>
