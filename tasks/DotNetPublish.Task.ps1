Add-BuildTask DotNetPublish @{
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
    Outputs = {
        $Projects = $dotnetProjects | ForEach-Object { Join-Path (Split-Path $dotnetSolution) $_ }
        foreach ($Proj in $Projects) {
            $ProjectName = Split-Path $Proj -LeafBase
            
            $Content = Get-Content $Proj -Raw -ErrorAction SilentlyContinue
            if ($Content -imatch '<IsPublishable>\s*true\s*</IsPublishable>') {
                # Look for published dll in the publish directory
                $PublishedDll = Join-Path $script:DotNetPublishRoot "$ProjectName/$ProjectName.dll"
                $ExistingPublish = Get-Item $PublishedDll -ErrorAction SilentlyContinue
                
                if ($ExistingPublish) {
                    $ExistingPublish.FullName
                } else {
                    # Return a placeholder path so Outputs is not empty (file doesn't exist yet, so task will run)
                    $PublishedDll
                }
            }
        }
    }
    Jobs = "DotNetBuild", {
        #! This handles a known issue with dotnet: any csproj identifying itself as Microsoft.NET.Sdk.Web will ALWAYS be published, even if IsPublishable is set to false
        $script:ProjectsToIgnore = @()
        foreach ($Proj in $dotnetProjects) {          
            $Content = Get-Content $Proj -Raw -ErrorAction SilentlyContinue
            if  (($Content -imatch '<Project Sdk=\s*"Microsoft\.NET\.Sdk\.Web"\s*>') -and ($Proj -in $script:dotnetTestProjects)) {
                $script:ProjectsToIgnore += $Proj
            }
        }
    }, {
        if ($script:ProjectsToIgnore.Count -gt 0) {
            Write-Host "Skipping publish for projects: $($script:ProjectsToIgnore -join ', ')"
            dotnet sln $dotnetSolution remove $script:ProjectsToIgnore
        }
        $script:DotNetPublishRoot = New-Item $script:DotNetPublishRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Convert-Path
        $Name = Split-Path $dotnetSolution -LeafBase
        
        $local:options = @{} + $script:dotnetOptions
        
        if (${script:Version}.$Name) {
            $options["p"] = "Version=$(${script:Version}.$Name.InformationalVersion)"
        } else {
            $options["p"] = "Version=$(${script:Version}.InformationalVersion)"
        }

        Set-Location (Split-Path $dotnetSolution)
        Write-Build Gray "dotnet publish $dotnetSolution --no-build --no-restore $(($options.GetEnumerator().ForEach({"-$($_.key) $($_.value)"})) -join ' ') -p:SolutionName=$dotNetSolutionName"
        dotnet publish $dotnetSolution --no-build --no-restore @options "-p:SolutionName=$dotNetSolutionName"
    },{
        if ($script:ProjectsToIgnore.Count -gt 0) {
            dotnet sln $dotnetSolution add $script:ProjectsToIgnore
        }
    }
}
