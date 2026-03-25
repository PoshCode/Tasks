Add-BuildTask Clean-Output {
    Remove-BuildItem $OutputPath
    New-Item $OutputPath -ItemType Directory -Force | Out-Null
}
