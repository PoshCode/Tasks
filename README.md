# LD.Platform.BuildTasks

## TODO

- [ ] Yeah, I think one other thing we need to do before we try to turn this into a "process" is we need to clean up our tasks to use exec (or our Invoke-Native command) so that when the native tools fail, the build fails. (See Invoke-Build Basics and Guidelines)
- [ x ] CSC : error CS5001: Program does not contain a static 'Main' method suitable for an entry point [C:\XDL\LD.Shared.EnterprisePlatformServices.API\EPS\ThirdParty\LD.EPS.ThirdParty.Calyx\LD.EPS.ThirdParty.Calyx.csproj]
- [ x ] what are we going to do about dotnet-tools.json? 
    - [ x ] Copy the file to the build root
- [ x ] Use a solution filter to filter out test projects that trying to publish because they're using microsoft.net.sdk.web 
    - [ ] ACTUALLY use dotnet sln remove to exclude them from the build and then add them back after the task completes
- [ ] How do I handle tasks for publishing to ACR vs universal package proget
