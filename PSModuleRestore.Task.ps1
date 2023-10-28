Add-BuildTask PSModuleRestore @{
    If      = Test-Path $BuildRoot${/}RequiredModules.psd1
    Inputs  = "$BuildRoot${/}RequiredModules.psd1"
    Outputs = "$OutputRoot${/}RequiredModules.psd1"
    Jobs    = {
        # Copy the metadata to the output as a way to avoid re-running this step over and over
        Copy-Item "$BuildRoot${/}RequiredModules.psd1" -Destination "$OutputRoot${/}RequiredModules.psd1"

        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        # This should install in the user's script folder (wherever that is). Passthru will tell us where.
        $Script = Install-Script Install-RequiredModule -NoPathUpdate -Force -PassThru -Scope CurrentUser
        & (Join-Path $Script.InstalledLocation "Install-RequiredModule.ps1") "$BuildRoot${/}RequiredModules.psd1" -Scope CurrentUser -Confirm:$false -Verbose:$Verbose

        foreach ($installErr in $IRM_InstallErrors) {
            Write-Warning "ERROR: $installErr"
            Write-Warning "STACKTRACE: $($installErr.ScriptStackTrace)"
        }
        Write-Progress "Importing Modules" -Completed
    }
}
