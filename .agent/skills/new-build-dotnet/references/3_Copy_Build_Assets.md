# Copy the `Build` files from assets/

These files go in your project root and they need to be customized a little bit.

If there are existing `Directory.build.props` or `Directory.build.targets` files _in the root_ of the project, you will need to merge their contents with the ones from the assets folder, making sure to preserve any customizations or important properties and targets that are already defined.

Additionally, if there are existing `Directory.build.props` in any **child** folders, those need to be updated to import the files in the root, by adding this line inside the `<Project>` tag:

```xml
<Import Project="$([MSBuild]::GetPathOfFileAbove('Directory.Build.props', '$(MSBuildThisFileDirectory)../'))"/>
```

Finally, if there is already a *.build.ps1 script, you should leave that file as-is, and assume it's already customized. You could copy over our `assets/build.build.ps1` as `new.build.ps1` but you'll need to compare them and resolve to a single `*.build.ps1` file in the root before running Invoke-Build!

## Update the `<Authors>` to your **team** email

This email should be set to a team email distribution list for the maintainers of the project.

## Update the `<PackageProjectUrl>` to the repo URL

This should be set to the web URL of the repository where this project lives, not the git URL.

## Finally, update the base files in the build.build.ps1

By default the build.build.ps1 references these two base scripts:

```
    "../*BuildTasks/dotnet/base.ps1"
    "../*BuildTasks/helm/base.ps1"
```

If your project is not using Helm, you can remove the second reference. If you have other project types mixed into the repo, you'll want to update the list here to reference the appropriate base files.