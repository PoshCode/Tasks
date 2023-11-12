Add-BuildTask PSModuleBuild @{
    If      = $PSModuleSourcePath
    Inputs  = { Get-ChildItem -Path $PSModuleSourceRoot -Recurse -Filter *.ps* }
    Outputs = { Join-Path $OutputRoot $PSModuleName "$PSModuleName.psm1" } # don't take off the script block, need to resolve AFTER init
    Jobs    = "PSModuleRestore", {
        $InformationPreference = "Continue"

        $SemVer = (Get-Variable "GitVersion.$PSModuleName" -ValueOnly).InformationalVersion

        Write-Information "Build-Module -SourcePath $PSModuleSourcePath -Destination $PSModuleOutputPath -SemVer $SemVer"
        $Module = Build-Module -SourcePath $PSModuleSourcePath -Destination $PSModuleOutputPath -SemVer $SemVer -Verbose:$Verbose -Debug:$Debug -Passthru

        if ($DotNetPublishRoot -and (Test-Path $DotNetPublishRoot)) {
            $Libraries = New-Item (Join-Path $Module.ModuleBase lib) -Type Directory -Force | Convert-Path
            Get-ChildItem $DotNetPublishRoot
            | Where-Object { $_.BaseName -notmatch "System.*" -and $_.Extension -notin ".nupkg" }
            | Copy-Item -Destination $Libraries -Recurse
        }
    }
}
