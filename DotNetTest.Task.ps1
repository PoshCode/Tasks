Add-BuildTask DotNetTest @{
    # This task should be skipped if there are no C# projects to build
    If      = $dotnetTestProjects
    Inputs  = {
        Get-ChildItem $dotnetProjects -Recurse -File -Filter *.cs |
            Where-Object FullName -NotMatch "[\\/]obj[\\/]"
    }
    Outputs = {
        (Get-ChildItem $TestResultsRoot -Filter *.trx -Recurse -ErrorAction Ignore) ?? $TestResultsRoot
    }
    Jobs    = "DotNetBuild", {
        # make sure the coverage tool is available
        dotnet tool update --global dotnet-coverage

        $local:options = @{
            "-configuration" = $configuration
            "-results-directory" = $TestResultsRoot
        } + $script:dotnetOptions

        if ($Script:CollectCoverage) {
            $options["-collect"] = "Code Coverage"
        }

        foreach ($project in $dotnetTestProjects) {
            Write-Build Gray "dotnet test $project --no-build --logger trx" @options
            dotnet test $project --no-build --logger trx @options
        }
    }
}
