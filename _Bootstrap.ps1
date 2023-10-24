<#
    .SYNOPSIS
        Bootstrap the build environment.
    .DESCRIPTION
        This script is intended to be run from your build script.
        It will ensure that the build environment is ready to go.
        It will ensure that Invoke-Build is available.
        It will ensure that dotnet is available (even when we're not going to compile, I use it for GitVersion)
        It will ensure that GitVersion is available.
#>
[CmdletBinding()]
param(
    # When running locally, you can -Force to skip the confirmation prompts
    [switch]$Force,

    # I require dotnet, and gitversion
    # Defaults to the "7.0" channel, change it to change the minimum version
    [double]$DotNet = "7.0",

    # Path to a RequiredModules.psd1
    # If this file is missing, we'll still install InvokeBuild
    # If you have RequiredModules, don't forget to include InvokeBuild
    $RequiredModulesPath = (Join-Path $pwd "RequiredModules.psd1"),

    # Scope for installation (of scripts and modules). Defaults to CurrentUser
    [ValidateSet("AllUsers", "CurrentUser")]
    $Scope = "CurrentUser"
)
$InformationPreference = "Continue"

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Write-Information "Ensure Required Modules"
if (!(Get-Command Install-RequiredModule -ErrorAction SilentlyContinue)) {
    # This should install in the user's script folder (wherever that is). Passthru will tell us where.
    $Script = Install-Script Install-RequiredModule -NoPathUpdate -Force -PassThru -Scope $Scope
    Set-Alias Install-RequiredModule (Join-Path $Script.InstalledLocation "Install-RequiredModule.ps1") -Scope Global
}

if (Test-Path $RequiredModulesPath) {
    Install-RequiredModule $RequiredModulesPath -Scope $Scope -Confirm:$false -Verbose
} else {
    # The default required modules is just InvokeBuild
    Install-RequiredModule @{
        InvokeBuild = "5.*"
    } -Scope $Scope -Confirm:$false -Verbose
}

foreach ($installErr in $IRM_InstallErrors) {
    Write-Warning "ERROR: $installErr"
    Write-Warning "STACKTRACE: $($installErr.ScriptStackTrace)"
}

Write-Information "Ensure dotnet version"
if (!((Get-Command dotnet -ErrorAction SilentlyContinue) -and ([semver](dotnet --version) -gt $DotNet))) {
    # Obviously this must not happen on CI environments, so make sure you have dotnet preinstalled there...
    Write-Host "This script can call dotnet-install to install a local copy of dotnet $DotNet -- if you'd rather install it yourself, answer no:"
    if (!$IsLinux -and !$IsMacOS) {
        Invoke-WebRequest https://dot.net/v1/dotnet-install.ps1 -OutFile bootstrap-dotnet-install.ps1
        .\bootstrap-dotnet-install.ps1 -Channel $DotNet -InstallDir $HOME\.dotnet
    } else {
        Invoke-WebRequest https://dot.net/v1/dotnet-install.sh -OutFile bootstrap-dotnet-install.sh
        chmod +x bootstrap-dotnet-install.sh
        ./bootstrap-dotnet-install.sh --channel $DotNet --install-dir $HOME/.dotnet
    }
    if (!((Get-Command dotnet -ErrorAction SilentlyContinue) -and ([semver](dotnet --version) -gt $DotNet))) {
        throw "Unable to find dotnet $DotNet or later"
    }
}

Write-Information "Ensure GitVersion"
if (!(Get-Command dotnet-gitversion -ErrorAction SilentlyContinue)) {
    # TODO: implement semi-permanent PATH modification for github and azure
    $ENV:PATH += ([IO.Path]::PathSeparator) + (Convert-Path ~/.dotnet/tools)
    dotnet tool update GitVersion.Tool --global # --verbosity normal
}