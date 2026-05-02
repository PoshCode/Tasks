
Add-BuildTask Pack-UniversalPackage @{
    Inputs  = {
        $Projects = $dotnetProjects | ForEach-Object { Join-Path (Split-Path $dotnetSolution) $_ }

        foreach ($Proj in $Projects) {
            $ProjectName = Split-Path $Proj -LeafBase

            # Check if project is publishable by reading the .csproj file
            # Directory.Build.props sets IsPublishable=false by default, so only projects
            # that explicitly set IsPublishable=true should be published
            $Content = Get-Content $Proj -Raw -ErrorAction SilentlyContinue
            if ($Content -imatch '<IsPublishable>\s*true\s*</IsPublishable>') {
                $DllPath = Join-Path $script:OutputRoot "bin/$ProjectName/$script:Configuration/$script:TargetFramework/$script:TargetRuntime/$ProjectName.dll"
                if (Test-Path $DllPath) { $DllPath }
            }
        }
    }
    outputs = {
        if (($ExistingPack = Get-ChildItem $script:UniversalPackageRoot/*.upack -ErrorAction Ignore) -ne $null) {
            $ExistingPack
        } else {
            $BuildRoot
        }
    }
    # Requires dotnetpublish but future state this task should be able to publish any library (python, npm, whatever). These tasks were just initially written for dotnet projects
    jobs    = 'Publish-DotNet', {
        $VersionInfo = Get-Content (Join-Path $script:OutputRoot version.json) | ConvertFrom-Json
        $script:UniversalPackageRoot = New-Item $script:UniversalPackageRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path
        Get-ChildItem $script:DotNetPublishRoot -Directory | ForEach-Object {
            $Solution = $_
            $local:options = @(
                "--source-directory=$($Solution.FullName)"
                "--name=$($Solution.Name)"
                "--version=$($VersionInfo.Semver)"
                "--target-directory=$($script:UniversalPackageRoot)"
            )
            Write-Build Yellow "dotnet pgutil upack create $($Options -join ' ')"
            dotnet tool execute pgutil upack create @options
        }
        # pgutil packages upload --feed=build-output --input-file=..\DevOpsScripts-Upack-Demo-0.0.0-rc.1+sha.df5b663.260206.upack --source=https://nuget.loandepot.com --api-key=04f1ab532b9397408b349e83420c762ac42eb98d
    }
}
