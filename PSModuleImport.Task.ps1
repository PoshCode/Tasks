Add-BuildTask PSModuleImport "PSModuleRestore", "PSModuleBuild", {
    # Always re-import the module -- don't try to guess if it's been changed
    if ($PSModuleManifestPath = Get-ChildItem $PSModuleOutputPath -Filter "$PSModuleName.psd1" -Recurse -ErrorAction Ignore) {

        if (($loaded = Get-Module -Name $PSModuleName -All -ErrorAction Ignore)) {
            "Unloading Module '$PSModuleName' $($loaded.Version -join ', ')"
            $loaded | Remove-Module -Force
        }

        "Importing Module '$PSModuleName' $($Script:GitVersion.$PSModuleName.SemVer) from '$PSModuleManifestPath'"
        Import-Module -Name $PSModuleManifestPath -Force -PassThru:$PassThru
    } else {
        throw "Cannot find module manifest $PSModuleName in '$PSModuleOutputPath'"
    }
}
