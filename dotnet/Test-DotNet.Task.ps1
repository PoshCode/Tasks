Add-BuildTask Test-DotNet @{
    Inputs  = {
        $DotNetProjects.Where({ $_.IsTestProject }).ForEach({ Get-ChildItem (Split-Path $_.Path) -Recurse -File -ErrorAction SilentlyContinue })
    }
    Outputs = {
        New-Item -Type Directory -Path $SolutionTestResultsRoot -Force | Out-Null
        Join-Path $SolutionTestResultsRoot "*.trx"
    }
    Jobs    = "Build-DotNet", {

        $local:options = @{
            "-logger"            = "trx"
            "-results-directory" = $SolutionTestResultsRoot
        } + $script:dotnetOptions

        # Because we might wrap it in `dotnet coverage collect`, we need to build this as a string
        $Command = "dotnet test --solution $DotNetSolutionFile -p:SolutionName=$SolutionName --no-build $(($options.GetEnumerator().ForEach({"-$($_.Key) $($_.Value)"})) -join ' ')"
        if (!$Script:SkipCoverage) {
            Write-Build Yellow "dotnet coverage collect '$Command' --output '$SolutionTestResultsRoot/coverage/$SolutionName.xml' --output-format xml"
            dotnet tool execute dotnet-coverage collect $Command --output "$SolutionTestResultsRoot/coverage/$SolutionName.xml" --output-format xml
        } else {
            Write-Build Yellow $Command
            dotnet test --solution $DotNetSolutionFile -p:SolutionName=$SolutionName --no-build @options
        }
    }, "Convert-Trx2JUnit"
}
