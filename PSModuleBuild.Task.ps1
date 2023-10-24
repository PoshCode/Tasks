Add-BuildTask PSModuleBuild @{
    If      = $PSModuleSourcePath
    Inputs  = { Get-ChildItem -Path $PSModuleSourceRoot -Recurse -Filter *.ps* }
    Outputs = { Join-Path $OutputRoot $PSModuleName "$PSModuleName.psm1" } # don't take off the script block, need to resolve AFTER init
    Jobs    = "PSModuleRestore", {
        Build-Module -SourcePath $PSModuleSourcePath -Destination $PSModuleOutputPath -SemVer $script:GitVersion['NuGetVersionV2']
    }
}
