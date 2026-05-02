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

$script:ErrorView = "DetailedView"
$script:InformationPreference = "Continue"
$script:ErrorActionPreference = "Stop"

# Force distinct colors for Verbose and Debug
if ($PSStyle.Formatting.Verbose -eq $PSStyle.Formatting.Warning) {
    $PSStyle.Formatting.Verbose = $PSStyle.Foreground.BrightCyan
}
if ($PSStyle.Formatting.Debug -eq $PSStyle.Formatting.Warning) {
    $PSStyle.Formatting.Debug = $PSStyle.Foreground.BrightGreen
}

& "$PSScriptRoot/Install-PowerShellModule.ps1" $Path

Pop-Location -StackName BootStrap
