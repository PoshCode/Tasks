Add-BuildTask Test-DotNet @{
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
        # dotnet test generates .trx files with machine/user-based names, not project or solution names
        New-Item -Type Directory -Path $SolutionTestResultsRoot -Force | Out-Null
        $TrxFiles = Get-ChildItem $SolutionTestResultsRoot -Filter "*.trx" -ErrorAction SilentlyContinue

        if ($TrxFiles) {
            $TrxFiles | Select-Object -ExpandProperty FullName
        } else { $BuildRoot }
    }
    Jobs    = "Build-DotNet", {

        $local:options = @{
            "-logger"            = "trx"
            "-results-directory" = $SolutionTestResultsRoot
        } + $script:dotnetOptions

        if (!$Script:SkipCoverage) {
            # Because we wrapt it in dotnet coverage, we need to build this as a string
            $Command = "dotnet test $dotnetSolution --no-build"
            $options.GetEnumerator() | ForEach-Object {
                $Command += " -$($_.Key) $($_.Value)"
            }
            $Command += " -p:SolutionName=$SolutionName"
            $Name = (Split-Path $dotnetSolution -LeafBase).ToLower()
            Write-Build Yellow "dotnet coverage collect '$Command' --output '$SolutionTestResultsRoot/coverage/$Name.xml' --output-format xml"
            dotnet coverage collect $Command --output "$SolutionTestResultsRoot/coverage/$Name.xml" --output-format xml
        } else {
            Write-Build Yellow "dotnet test $dotnetSolution --no-build $(($options.GetEnumerator().ForEach({"-$($_.key) $($_.value)"})) -join ' ')"
            dotnet test $dotnetSolution --no-build @options
        }
    }, "Convert-Trx2JUnit"
}
