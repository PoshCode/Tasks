# .NOTES
#   THIS SCRIPT IS SYNCED to both InvokeBuildTasks and SharedPipelines -- PLEASE KEEP IN SYNC
# .SYNOPSIS
#   Installs Install-RequiredModule and then calls it ...
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', 'InputObject', Justification = 'For Invoke-Build Compabitility')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', "InputObject", Justification = 'For Invoke-Build Compabitility')]
param(
    [string]$RequiredModulesFile = "$pwd/RequiredModules.psd1",

    [hashtable]$RequiredModules = @{
        'InvokeBuild' = '[5.11.1, 6.0)'
    },
    # This command ignores pipeline input
    [Parameter(ValueFromPipeline, ValueFromRemainingArguments)]
    [PSObject[]]$InputObject,

    # This allows passing a different url for modulefastparam source. Used for Harness which must use APIM url to reach proget
    [string]$ModuleFastSourceUrl = "https://nuget.loandepot.com/nuget/PowerShell/v3/index.json",

    # ProGet API token for authenticated access (required for Harness/APIM endpoint, not needed for ADO private link)
    [string]$ProGetToken
)

# Construct credential if token is provided (for Harness APIM authentication)
$Credential = if ($ProGetToken) {
    $secureToken = ConvertTo-SecureString $ProGetToken -AsPlainText -Force
    [System.Management.Automation.PSCredential]::new('api', $secureToken)
} else {
    $null
}

# We have not yet migrated our PowerShell modules to LocalApplicationData on Windows
$ModuleFastParam = @{
    Source      = $ModuleFastSourceUrl
    Destination = if ($IsWindows) {
        # On Windows, the modules folder is not pre-created?
        mkdir (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell/Modules') -Force | Convert-Path
    } else {
        Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'powershell/Modules'
    }
}
if (-not (Test-Path $RequiredModulesFile)) {
    $ModuleFastParam['Specification'] = $RequiredModules.GetEnumerator().ForEach{ $_.Key + ":" + $_.Value }
    # Update this for the environment variable
    $RequiredModulesFile = $RequiredModules.Keys -join ";"
} else {
    $ModuleFastParam['Path'] = $RequiredModulesFile
}

if (!(Get-Module ModuleFast -ListAvailable -ErrorAction SilentlyContinue)) {
    # $PSModulePaths = @("PSModulePaths:") + $env:PSModulePath.Split([IO.Path]::PathSeparator, [StringSplitOptions]::RemoveEmptyEntries)
    # Write-Verbose $($PSModulePaths -join "`n  $($PSStyle.Formatting.Verbose)") -Verbose

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

# Install modules from ProGet (with auth for Harness/APIM, without auth for ADO private link)
if ($Credential) {
    Install-ModuleFast @ModuleFastParam -Credential $Credential -Verbose
} else {
    Install-ModuleFast @ModuleFastParam -Verbose
}

Write-Host "##vso[task.setvariable variable=RequiredModules]$RequiredModulesFile"
