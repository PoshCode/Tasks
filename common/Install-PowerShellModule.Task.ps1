Add-BuildTask Install-PowerShellModule @{
    If      = { Test-Path $BuildRoot/*.requires.psd1 }
    Inputs  = { Get-Item "$BuildRoot/*.requires.psd1" }
    Outputs = { process { Join-Path -Path $OutputPath -ChildPath $_.Name } }
    Jobs    = (Get-Command "$PSScriptRoot/../scripts/Install-PowerShellModule.ps1").ScriptBlock,
    { Copy-Item "$BuildRoot/*.requires.psd1" -Destination "$OutputPath/" }
}
