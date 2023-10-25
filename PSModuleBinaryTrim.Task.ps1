Add-BuildTask PSModuleBinaryTrim @{
    If      = $PSModuleOutputPath
    Jobs    = {
        $InformationPreference = "Continue"
        Get-ChildItem $PSModuleOutputPath -Recurse -Filter System.*.dll | Remove-Item
    }
}
