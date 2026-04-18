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
    # Path to a RequiredModules.psd1 (if missing will only install InvokeBuild)
    $RequiredModulesPath = (Join-Path $pwd "RequiredModules.psd1"),

    # Scope for installation (of scripts and modules). Defaults to CurrentUser
    [ValidateSet("AllUsers", "CurrentUser")]
    $Scope = "CurrentUser"
)
Push-Location -StackName BootStrap

& "$PSScriptRoot/../scripts/Install-RequiredModule.ps1" $RequiredModulesPath

Pop-Location -StackName BootStrap
