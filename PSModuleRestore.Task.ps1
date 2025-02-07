Add-BuildTask PSModuleRestore @{
    If      = (Test-Path "$BuildRoot${/}RequiredModules.psd1", "$BuildRoot${/}*.requires.psd1") -contains $true
    Inputs  = "$BuildRoot${/}RequiredModules.psd1", "$BuildRoot${/}*.requires.psd1" | Convert-Path -ErrorAction ignore
    Outputs = "$OutputRoot${/}*.requires.psd1"
    Jobs    = {
        "$BuildRoot${/}*.requires.psd1", "$BuildRoot${/}RequiredModules.psd1"
        | Convert-Path -ErrorAction ignore -OutVariable RequiresPath

        # TODO: Deprecate RequiredModules.psd1
        if ((Split-Path $RequiresPath -Leaf) -eq "RequiredModules.psd1") {
            Write-Information "Translating RequiredModules.psd1 to Specification"
            $Modules = Import-PowerShellDataFile $RequiresPath
            # Pull a switcheroo
            $RequiresPath = Join-Path (Split-Path $RequiresPath) "build.requires.psd1"
            @(
                "@{"
                foreach ($ModuleName in $Modules.Keys) {
                    "    ""$ModuleName"" = "":" + $Modules[$ModuleName] + """"
                }
                "}"
            ) | Out-File $RequiresPath
        }
        # TODO: Switch to generating a lockfile?
        Copy-Item $RequiresPath -Destination "$OutputRoot${/}"

        $Destination = if ($IsWindows) {
            Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell/Modules'
        } else {
            Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'powershell/Modules'
        }

        Install-ModuleFast -Destination $Destination -Path $RequiresPath -Verbose
    }
}
