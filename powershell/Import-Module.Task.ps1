Add-BuildTask Import-Module {
    # Always re-import the module -- don't try to guess if it's been changed
    if (-not (Test-Path $script:ManifestPath)) {
        throw "Could not find ManifestPath '$script:ManifestPath'"
    }

    if (($loaded = Get-Module -Name $script:ModuleName -All -ErrorAction Ignore)) {
        "Unloading Module '$script:ModuleName' $($loaded.Version -join ', ')"
        $loaded | Remove-Module -Force -Verbose:$false
    }

    try {
        "Importing Module '$script:ModuleName' $($script:Version.SemVer) from '$script:ManifestPath'"
        Import-Module -Name $script:ManifestPath -Force -ErrorAction Stop -Verbose:$false
    } catch {
        Write-Warning "Failed to import module '$script:ModuleName' from '$script:ManifestPath'"
        Write-Warning $_.Exception.Message
        Get-ChildItem (Split-Path $script:ManifestPath) -Recurse | Out-String -Width 120 | Out-Host
        throw $_
    }
}
