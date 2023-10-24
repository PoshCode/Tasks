Add-BuildTask PSModuleImport "PSModuleRestore", "PSModuleBuild", {
    # Always re-import the module -- don't try to guess if it's been changed
    if (-not(Test-Path $PSModuleManifestPath)) {
        throw "Could not find ManifestPath '$PSModuleManifestPath'"
    } else {

        if (($loaded = Get-Module -Name $PSModuleName -All -ErrorAction Ignore)) {
            "Unloading Module '$PSModuleName' $($loaded.Version -join ', ')"
            $loaded | Remove-Module -Force
        }

        "Importing Module '$PSModuleName' $($Script:GitVersion.SemVer) from '$PSModuleManifestPath'"
        Import-Module -Name $PSModuleManifestPath -Force -PassThru:$PassThru
    }
}
