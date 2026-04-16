# Update Projects To Modern Standards

Obviously we've already covered that all projects must be on a supported .NET Core SDK and using SDK-style projects, but the following steps must be taken to make sure you get the outputs you need from each project.

## Update the Project References

Start by collecting a full list of all the project assembly names. You can find these in the .csproj files in the AssemblyName property, like `<AssemblyName>LD.EPS.Common.Logging</AssemblyName>`. If there is no `<AssemblyName>` property, the assembly name defaults to the project file base name (without extension).

Examine all PackageReference elements in each project file and ensure that any NuGet package references are to projects which are not part of this repository.

If any projects have PackageReference elements that reference the name of a project in the same repository, you must convert those references to ProjectReference. Otherwise, you will end up needing to do multiple pull requests whenever you update a library -- first to merge changes to the library, and then to update the projects with dependencies on it.

## Update Publishing Properties

For projects to publish a NuGet package, they must have the `<IsPackable>true</IsPackable>` property, and ensure it has the necessary metadata (PackageId, Version, etc.). This change _must_ be reviewed by a human. There is no programmatic way of telling whether a project is supposed to be publishing a NuGet package.

Specifically, in some cases, things that _were_ published as NuGet packages prior to conversion to the monorepo pattern no longer need to be published, because the only consumers are now co-located in this repository.

For projects to publish a container, service, or web app, they must have the `<IsPublishable>true</IsPublishable>` property, and ensure it has the necessary metadata (Authors, etc.).

If projects are currently targeting containers for deployment they will have a Dockerfile in the project folder. That Dockerfile should be removed, and they should instead set the image repository name in the project as a property, like `<ContainerRepository>ld/eps/publicservice</ContainerRepository>`. That will be enough to produce the container image.

All test projects _must_ set the `<IsTestProject>true</IsTestProject>` attribute. These projects are not intended to be _shipped_ or packed into containers. They usually have "Test" or "Spec" in the name, and reference test frameworks like xUnit, NUnit, MSTest or SpecFlow.

Note that for advanced teams, there may be an integration project with a reference to a test framework that needs to be published to a container image so we can run integration tests in Kubernetes. Those projects should have `IsPublishable` and `ContainerRepository` set.