Add-BuildTask DotNetTest @{
    # This task should be skipped if there are no C# projects to build
    If      = $dotnetSolution
    Inputs  = {
        $Projects = $dotnetTestProjects | ForEach-Object { Join-Path (Split-Path $dotnetSolution) $_ }
        $Projects
        
        # Also include source files from each project directory
        foreach ($Proj in $Projects) {
            $ProjectDir = Split-Path $Proj -Parent
            Get-ChildItem $ProjectDir -Recurse -File -Include *.cs,*.csproj,*.resx,*.json -ErrorAction SilentlyContinue |
                Where-Object FullName -NotMatch "[\\/]obj[\\/]|[\\/]bin[\\/]"
        }
    }
    Outputs = {
        # Return any .trx files in the test results directory
        # dotnet test generates .trx files with machine/user-based names, not project names
        $TrxFiles = Get-ChildItem $TestResultsRoot -Filter "*.trx" -ErrorAction SilentlyContinue
        
        if ($TrxFiles) {
            $TrxFiles | Select-Object -ExpandProperty FullName
        } else {
            # Return a placeholder path so Outputs is not empty (file doesn't exist yet, so task will run)
            Join-Path $TestResultsRoot "test-results.trx"
        }
    }
    Jobs    = "DotNetBuild", {
        
        $local:options = @{
            "-logger"            = "trx" 
            "-results-directory" = $TestResultsRoot
            "-configuration"     = $configuration
        } + $script:dotnetOptions

        if ($Script:CollectCoverage) {
            # Because we wrapt it in dotnet coverage, we need to build this as a string
            $Command = "dotnet test $dotnetSolution --no-build"
            $options.GetEnumerator() | ForEach-Object {
                $Command += " -$($_.Key) $($_.Value)"
            }
            $Command += " -p:SolutionName=$dotnetSolutionName"
            $Name = (Split-Path $dotnetSolution -LeafBase).ToLower()
            Write-Build Gray "dotnet coverage collect '$Command' --output '$TestResultsRoot/coverage/$Name.xml' --output-format xml"
            dotnet coverage collect $Command --output "$TestResultsRoot/coverage/$Name.xml" --output-format xml
        } else {
            Write-Build Gray "dotnet test $dotnetSolution --no-build $(($options.GetEnumerator().ForEach({"-$($_.key) $($_.value)"})) -join ' ') -p:SolutionName=$dotnetSolutionName"
            dotnet test $dotnetSolution --no-build @options "-p:SolutionName=$dotnetSolutionName"
        }
        
    }, "SonarQubeEnd", "DotNetTrx2JUnit"
}
