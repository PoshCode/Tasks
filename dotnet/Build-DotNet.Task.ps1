Add-BuildTask Build-DotNet @{
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

            # linux edge case where csproj name does not match the dll name (case sensitivity)
            $AssemblyName = $ProjectName
            $Content = Get-Content $Proj -Raw -ErrorAction SilentlyContinue
            if ($Content -match '<AssemblyName>([^<]+)</AssemblyName>') {
                $AssemblyName = $Matches[1]
            }

            $DllPath = Join-Path $script:SolutionOutputPath "bin/$ProjectName/$script:Configuration/$script:TargetFramework/$script:TargetRuntime/$AssemblyName.dll"
            $DllPath
        }
    }
    Jobs    = "Restore-DotNet", "Get-Version", {
        $Name = (Split-Path $dotnetSolution -LeafBase).ToLower()

        $local:options = @{
            '-configuration' = $script:configuration
        } + $script:dotnetOptions

        if (${script:Version}.$Name) {
            $options["p"] = "Version=$(${script:Version}.$Name.InformationalVersion)"
        } else {
            $options["p"] = "Version=$(${script:Version}.InformationalVersion)"
        }

        Write-Build Yellow "dotnet build $dotnetSolution --no-restore $(($options.GetEnumerator().ForEach({"-$($_.key) $($_.value)"})) -join ' ')"
        # Invoke-BuildExec [-Command] ScriptBlock [[-ExitCode] Int32[]] [[-ErrorMessage] String] [-Echo] [-StdErr]

        dotnet build $dotnetSolution --no-restore @options
    }
}
