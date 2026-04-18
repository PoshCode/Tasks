Add-BuildTask Clean {
    Remove-BuildItem $OutputPath
    New-Item $OutputPath -ItemType Directory -Force | Out-Null
}
