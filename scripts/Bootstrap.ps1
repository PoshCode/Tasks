<#
    .SYNOPSIS
        Ensures Install-RequiredModule and Invoke-Build are available
    .DESCRIPTION
        Installs Install-RequiredModule and runs it against your RequiredModules.psd1
    .EXAMPLE
        # In azure-pipelines.yaml:
        - pwsh: $(Build.SourcesDirectory)/InvokeBuildTasks/BootStrap.ps1
          displayName: 'BootStrap Invoke-Build'
          workingDirectory: $(Build.SourcesDirectory)/$(Build.Repository.Name)
#>
[CmdletBinding()]
param(
    # Path to a .requires.psd1 (if missing will only install InvokeBuild)
    [Alias("RequiredModulesPath")]
    $Path = "$PSScriptRoot/../build.requires.psd1"
)
Push-Location -StackName BootStrap

& "$PSScriptRoot/Install-PowerShellModule.ps1" $Path

Pop-Location -StackName BootStrap
