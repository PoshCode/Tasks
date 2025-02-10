Add-BuildTask PSModuleRestore @{
    If      = Test-Path "$BuildRoot${/}*.requires.psd1"
    Inputs  = "$BuildRoot${/}*.requires.psd1" | Convert-Path -ErrorAction ignore
    Outputs = "$OutputRoot${/}*.requires.psd1"
    Jobs    = {
        Install-ModuleFast -Scope CurrentUser -Verbose
    }
}
