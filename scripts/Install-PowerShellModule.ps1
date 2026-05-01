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
    # This command does not support pipeline input
    # But is sometimes called with pipeline input ...
    [Parameter(ValueFromPipeline, ValueFromRemainingArguments)]
    [PSObject[]]$IgnoredPipelineInput,

    # This allows passing a different url for source.
    [string]$Source,

    # This might be needed for a proxy like passing through APIM to a feed....
    [System.Management.Automation.PSCredential]$Credential
)

$Destination = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'powershell/Modules'
# If we have not yet migrated our PowerShell modules to LocalApplicationData on Windows
if ($Env:PSModulePath -split ([Io.Path]::PathSeparator) -notcontains $Destination) {
    # On Windows, the modules folder is not pre-created?
    $Destination = mkdir (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell/Modules') -Force | Convert-Path
}
$PSBoundParameters.Remove('IgnoredPipelineInput') | Out-Null

$ModuleFastParam = $PSBoundParameters + @{
    Destination = $Destination
}

# The defaults are not "bound"
# ... use the path if it exists, otherwise the specification
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

Install-ModuleFast @ModuleFastParam -Verbose

if ($BuildSystem -eq "Azure") {
    # We use this as a condition in the Azure step, to skip rerunning this job
    Write-Host "##vso[task.setvariable variable=RequiredModules]$Path"
}