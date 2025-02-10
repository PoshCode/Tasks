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

    # I require dotnet, and git version
    # Defaults to the "7.0" channel, change it to change the minimum version
    [double]$DotNet = "7.0",

    # Path to a file listing required PowerShell modules.
    # See also: https://github.com/marketplace/actions/modulefast#requiresspec
    # I now use Install-ModuleFast to install modules, but I'll translate "RequiredModules.psd1" for you
    # Any other file name will be passed to Install-ModuleFast -Path
    # NOTE: If this file is missing, we'll still install InvokeBuild, but if you have a requires spec, don't forget to include InvokeBuild in it!
    [Alias("RequiredModulesPath")]
    $RequiresPath = (@(@(Join-Path $pwd "*.requires.psd1"
                        Join-Path $pwd "RequiredModules.psd1"
                    ) | Convert-Path -ErrorAction Ignore)[0]),

    # Path to a .*proj file or .sln
    # If this file is present, dotnet restore will be run on it.
    $ProjectFile = (Join-Path $pwd "*.*proj"),

    # Scope for installation (of scripts and modules). Defaults to CurrentUser
    [ValidateSet("AllUsers", "CurrentUser")]
    $Scope = "CurrentUser"
)
$InformationPreference = "Continue"
$ErrorView = 'DetailedView'
$ErrorActionPreference = 'Stop'

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

if (Test-Path $ProjectFile) {
    Write-Information "Ensure dotnet package dependencies"
    split-path $ProjectFile -Parent | push-location
    dotnet restore $ProjectFile --ucr
}

# If there is a dotnet-tools.json file, restore the tools
if (Join-Path $pwd .config dotnet-tools.json | Test-Path) {
    Write-Information "Restore dotnet tools"
    if (Test-Path $ToolsFile) {
        dotnet tool restore --tool-manifest $ToolsFile
    }
}

# Regardless of whether you have a dotnet-tools.json file, we need gitversion global tool
# dotnet 8+ can "list" tool names, but this old syntax still works:
if (!(dotnet tool list -g | Select-String "gitversion.tool")) {
    Write-Information "Ensure GitVersion.tool"
    # We need gitversion 5.x (the new 6.x version will not support SemVer 1 that PowerShell still uses)
    dotnet tool update gitversion.tool --version 5.* --global
}

if (Test-Path $HOME/.dotnet/tools) {
    Write-Information "Ensure dotnet global tools in PATH"
    # TODO: implement semi-permanent PATH modification for github and azure
    $ENV:PATH += ([IO.Path]::PathSeparator) + (Convert-Path $HOME/.dotnet/tools)
}

# I don't want ModuleFast messing with the PSModulePath so we use the default user location
$ModuleDestination = if ($IsWindows) {
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell/Modules'
} else {
    # PowerShell on Linux and Mac follows XDG
    Join-Path $HOME '.local/share/powershell/Modules'
}

if (!(Get-Module ModuleFast -ListAvailable -ErrorAction SilentlyContinue)) {
    Write-Information "Ensure ModuleFast in $ModuleDestination" -Verbose
    # Skip using the api endpoint to avoid throtting, we can get latest from the redirect
    $VersionTag = try { Invoke-WebRequest https://github.com/JustinGrote/ModuleFast/releases/latest -MaximumRedirection 0 } catch { Split-Path -Leaf $_.Exception.Response.Headers.Location.ToString() }
    $zipFile = "ModuleFast.$($VersionTag.Trim('v')).zip"
    $zip = "https://github.com/JustinGrote/ModuleFast/releases/download/$VersionTag/$zipFile"
    Write-Information "Installing ModuleFast $VersionTag from $zip" -Verbose
    Invoke-WebRequest $zip -OutFile $zipFile
    Expand-Archive $zipFile -DestinationPath $ModuleDestination
    Remove-Item $zipFile
}

$ModuleFast = @{
    Destination = $ModuleDestination
}
if ($RequiresPath) {
    if ((Split-Path $RequiresPath -Leaf) -eq "RequiredModules.psd1") {
        Write-Information "Translating $RequiresPath to Module Specification"
        $Modules = Import-PowerShellDataFile $RequiresPath
        # Careful. It's possible $RequiresPath is in the root: /RequiredModules.psd1 has no parent.
        $NewRequiresPath = (Split-Path $RequiresPath) ? (Join-Path (Split-Path $RequiresPath) "build.requires.psd1") : "build.requires.psd1"
        @(
        "@{"
        foreach ($ModuleName in $Modules.Keys) {
            "    ""$ModuleName"" = "":" + $Modules[$ModuleName] + """"
        }
        "}"
        ) | Out-File $NewRequiresPath
        # If that worked, we can delete the old file
        Remove-Item $RequiresPath
        $RequiresPath = $NewRequiresPath
    }
    $ModuleFast["Path"] = $RequiresPath
} else {
    $ModuleFast["Specification"] = "InvokeBuild:5.*"
}

Install-ModuleFast @ModuleFast -Verbose

if ($IRM_InstallErrors) {
    foreach ($installErr in @($IRM_InstallErrors)) {
        Write-Warning "ERROR: $installErr"
        Write-Warning "STACKTRACE: $($installErr.ScriptStackTrace)"
    }
}