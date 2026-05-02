Add-BuildTask Clean-Output {
    Remove-BuildItem $OutputRoot
    New-Item $OutputRoot -ItemType Directory -Force | Out-Null
}
