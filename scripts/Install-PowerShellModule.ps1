# .NOTES
#   THIS SCRIPT IS SYNCED to both InvokeBuildTasks and SharedPipelines -- PLEASE KEEP IN SYNC
# .SYNOPSIS
#   Installs Install-RequiredModule and then calls it ...
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', 'InputObject', Justification = 'For Invoke-Build Compabitility')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', "InputObject", Justification = 'For Invoke-Build Compabitility')]
param(
    [Alias("RequiredModulesPath")]
    [string]$path = "$pwd/*.requires.psd1",

    [string[]]$Specification = @(
        'InvokeBuild:[5.11.1, 6.0)'
    ),
    # This command explicitly ignores pipeline input
    # But is sometimes called with input ...
    [Parameter(ValueFromPipeline, ValueFromRemainingArguments)]
    [PSObject[]]$InputObject,

    # This allows passing a different url for modulefastparam source. Used for Harness which must use APIM url to reach proget
    [string]$ModuleFastSourceUrl = "https://nuget.loandepot.com/nuget/PowerShell/v3/index.json",

    # API token for APIM access (only needed for accessing the APIM from outside the firewall)
    [SecureString]$ApiToken
)

$Destination = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'powershell/Modules'
# If we have not yet migrated our PowerShell modules to LocalApplicationData on Windows
if ($Env:PSModulePath -split ([Io.Path]::PathSeparator) -notcontains $Destination) {
    # On Windows, the modules folder is not pre-created?
    $Destination = mkdir (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell/Modules') -Force | Convert-Path
}

$ModuleFastParam = @{
    Source      = $ModuleFastSourceUrl
    Destination = $Destination
}
# This wrapper uses the path if it exists, otherwise uses the Specification
if (-not (Test-Path $Path)) {
    $ModuleFastParam['Specification'] = $Specification
    # Update this for the environment variable
    $Path = "'$($Specification -join "', '")'"
} else {
    $ModuleFastParam['Path'] = $Path
}

# If ModuleFast is not already installed, install it to $Destination
if (!(Get-Module ModuleFast -ListAvailable -ErrorAction SilentlyContinue)) {
    Write-Verbose "ModuleFast not found. Installing to $($ModuleFastParam.Destination)" -Verbose
    # When we get redirected beyond our limit, IWR throws
    [string]$Location = try {
        # Github redirects releases/latest, but throttles their API
        Invoke-WebRequest https://github.com/JustinGrote/ModuleFast/releases/latest -UseBasicParsing -MaximumRedirection 0
        "https://github.com/JustinGrote/ModuleFast/releases/tag/v0.6.0"
    } catch {
        $_.Exception.Response.Headers.location
    }
    $tag = Split-Path $Location -Leaf
    $version = $tag.Trim("v")
    $file = "ModuleFast.$version.zip"
    $url = "https://github.com/JustinGrote/ModuleFast/releases/download/$tag/$file"
    Write-Verbose "Installing $file from $url" -Verbose
    Invoke-WebRequest $url -OutFile $file
    Expand-Archive $file -DestinationPath $ModuleFastParam.Destination
    Remove-Item $file
}

# Use APIM authentication token if provided
if ($ApiToken) {
    $ModuleFastParam['Credential'] = [System.Management.Automation.PSCredential]::new('api', $ApiToken)
}

Install-ModuleFast @ModuleFastParam -Verbose

if ($BuildSystem -eq "Azure") {
    # We use this as a condition in the Azure step, to skip rerunning this job
    Write-Host "##vso[task.setvariable variable=RequiredModules]$Path"
}