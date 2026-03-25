Add-BuildTask PSModuleRestore @{
    If      = Test-Path "$BuildRoot${/}*.requires.psd1"
    Inputs  = "$BuildRoot${/}*.requires.psd1" | Convert-Path -ErrorAction ignore
    Outputs = "$OutputRoot${/}requires.lock.json"
    Jobs    = {
        Install-ModuleFast -Scope CurrentUser -Verbose -CI
        Copy-Item -Path "$BuildRoot${/}requires.lock.json" -Destination $OutputRoot
    }
}
