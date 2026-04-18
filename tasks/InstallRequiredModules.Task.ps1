Add-BuildTask InstallRequiredModules @{
    If      = Test-Path $BuildRoot/RequiredModules.psd1
    Inputs  = "$BuildRoot/RequiredModules.psd1"
    Outputs = "$Output/RequiredModules.psd1"
    Jobs    = (Get-Command "$PSScriptRoot/../scripts/Install-RequiredModule.ps1").ScriptBlock,
             { Copy-Item "$BuildRoot/RequiredModules.psd1" -Destination "$Output/RequiredModules.psd1" }
}
