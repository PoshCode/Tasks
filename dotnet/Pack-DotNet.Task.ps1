#! If this is trying to pack a test project, you must add <IsTestProject>true</IsTestProject> to the project file.
Add-BuildTask Pack-DotNet @{
    Inputs  = {
        $Projects = $dotnetProjects | ForEach-Object { Join-Path (Split-Path $dotnetSolution) $_ }
        $Projects

        foreach ($Proj in $Projects) {
            $ProjectName = Split-Path $Proj -LeafBase

            # Check if project is packable by reading the .csproj file
            # Directory.Build.props sets IsPackable=false by default, so only projects
            # that explicitly set IsPackable=true should be packed
            $Content = Get-Content $Proj -Raw -ErrorAction SilentlyContinue
            if ($Content -match '<IsPackable>\s*(true|True|TRUE)\s*</IsPackable>') {
                $DllPath = Join-Path $script:SolutionOutputPath "bin/$ProjectName/$script:Configuration/$script:TargetFramework/$script:TargetRuntime/$ProjectName.dll"
                if (Test-Path $DllPath) {
                    $DllPath
                }
            }
        }
    }
    Outputs = {
        $Projects = $dotnetProjects | ForEach-Object { Join-Path (Split-Path $dotnetSolution) $_ }

        foreach ($Proj in $Projects) {
            $ProjectName = Split-Path $Proj -LeafBase

            $Content = Get-Content $Proj -Raw -ErrorAction SilentlyContinue
            if ($Content -match '<IsPackable>\s*(true|True|TRUE)\s*</IsPackable>') {
                $NupkgPattern = Join-Path $script:DotNetPackRoot "$ProjectName.*.nupkg"
                $ExistingPkg = Get-Item $NupkgPattern -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

                if ($ExistingPkg) {
                    $ExistingPkg
                } else { $BuildRoot }
            }
        }
    }
    Jobs    = "Build-DotNet", {
        $script:DotNetPackRoot = New-Item $script:DotNetPackRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path

        $local:options = @{
            "-output" = $script:DotNetPackRoot
        }

        $Name = Split-Path $dotnetSolution -LeafBase
        if (${script:Version}.$Name) {
            $options["p"] = "Version=$(${script:Version}.$Name.InformationalVersion)"
        } else {
            $options["p"] = "Version=$(${script:Version}.InformationalVersion)"
        }

        Write-Host "Packing $Name"

        Write-Build Yellow "dotnet pack $dotnetSolution --no-build --include-symbols $(($options.GetEnumerator().ForEach({"$($_.key) $($_.value)"})) -join ' ')"
        dotnet pack $dotnetSolution --no-build --include-symbols @options
    }
}
