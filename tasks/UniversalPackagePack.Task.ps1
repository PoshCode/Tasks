
Add-BuildTask UniversalPackagePack @{
    If      = $dotnetSolution
    Inputs  = { 
        $Projects = $dotnetProjects | ForEach-Object { Join-Path (Split-Path $dotnetSolution) $_ }
        
        foreach ($Proj in $Projects) {
            $ProjectName = Split-Path $Proj -LeafBase
            
            # Check if project is publishable by reading the .csproj file
            # Directory.Build.props sets IsPublishable=false by default, so only projects
            # that explicitly set IsPublishable=true should be published
            $Content = Get-Content $Proj -Raw -ErrorAction SilentlyContinue
            if ($Content -imatch '<IsPublishable>\s*true\s*</IsPublishable>') {
                $DllPath = Join-Path $script:OutputPath "bin/$ProjectName/$script:Configuration/$script:TargetFramework/$script:TargetRuntime/$ProjectName.dll"
                if (Test-Path $DllPath) { $DllPath }
            }
        }
    }
    outputs = { Get-ChildItem $script:UniversalPacakgeRoot/*.upack -ErrorAction Ignore || Join-Path $script:UniversalPacakgeRoot "dummy.upack"}
    # Requires dotnetpublish but future state this task should be able to publish any library (python, npm, whatever). These tasks were just initially written for dotnet projects
    jobs    = 'DotNetPublish', {
        $VersionInfo = Get-Content (Join-Path $script:OutputPath version.json) | ConvertFrom-Json
        $script:UniversalPacakgeRoot = New-Item $script:UniversalPacakgeRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path
        Get-ChildItem $script:DotNetPublishRoot -Directory | ForEach-Object {
            $Solution = $_
            $local:options = @{
                "-source-directory" = $Solution.FullName
                "-name"             = $Solution.Name
                "-version"          = $VersionInfo.InformationalVersion
                "-target-directory" = $script:UniversalPacakgeRoot
            }
            Write-Build Gray "dotnet pgutil upack create $(($options.GetEnumerator().ForEach({"-$($_.key) $($_.value)"})) -join ' ')"
            dotnet pgutil upack create @options
        }
        # pgutil packages upload --feed=build-output --input-file=..\DevOpsScripts-Upack-Demo-0.0.0-rc.1+sha.df5b663.260206.upack --source=https://nuget.loandepot.com --api-key=04f1ab532b9397408b349e83420c762ac42eb98d
    }
}

# Project URL -> Repo url
# Are the audit properties being set by the pgutil tool (e.g. CreatedDate, CreatedBy)