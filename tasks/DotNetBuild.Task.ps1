Add-BuildTask DotNetBuild @{
    If      = $dotnetSolution
    Inputs  = {
        $Projects = $dotnetProjects | ForEach-Object { Join-Path (Split-Path $dotnetSolution) $_ }
        $Projects
        
        # Also include source files from each project directory
        foreach ($Proj in $Projects) {
            $ProjectDir = Split-Path $Proj -Parent
            Get-ChildItem $ProjectDir -Recurse -File -Include *.cs,*.csproj,*.resx,*.json -ErrorAction SilentlyContinue |
                Where-Object FullName -NotMatch "[\\/]obj[\\/]|[\\/]bin[\\/]"
        }
    }
    Outputs = {        
        $Projects = $dotnetProjects | ForEach-Object { Join-Path (Split-Path $dotnetSolution) $_ }
        
        # Return corresponding DLL files in OutputPath bin directory
        foreach ($Proj in $Projects) {
            $ProjectName = [IO.Path]::GetFileNameWithoutExtension($Proj)
            $DllPath = Join-Path $script:OutputPath "bin/$ProjectName/$script:Configuration/$script:TargetFramework/$script:TargetRuntime/$ProjectName.dll"
            $DllPath
        }
    }
    Jobs    = "DotNetRestore", "GetVersion", "SonarQubeStart", {
        $Name = (Split-Path $dotnetSolution -LeafBase).ToLower()
        
        $local:options = @{
            '-configuration' = $script:configuration
        } + $script:dotnetOptions
        
        if (${script:Version}.$Name) {
            $options["p"] = "Version=$(${script:Version}.$Name.InformationalVersion)"
        } else {
            $options["p"] = "Version=$(${script:Version}.InformationalVersion)"
        }
        
        # Pass SolutionName so Directory.Build.props can calculate correct paths (I think?)
        $SolutionName = if ($dotnetSolution -match '\.sln') {
            Split-Path $dotnetSolution -LeafBase
        } else {
            "shared"
        }
        
        Write-Build Gray "dotnet build $dotnetSolution --no-restore $(($options.GetEnumerator().ForEach({"-$($_.key) $($_.value)"})) -join ' ') -p:SolutionName=$SolutionName"
        # Invoke-BuildExec [-Command] ScriptBlock [[-ExitCode] Int32[]] [[-ErrorMessage] String] [-Echo] [-StdErr]
        
        dotnet build $dotnetSolution --no-restore @options "-p:SolutionName=$SolutionName"
    }
}
