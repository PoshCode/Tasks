Add-BuildTask DotNetClean @{
    # This task should be skipped if there are no C# projects to build
    If      = $dotnetSolution
    Jobs    = {    
        Write-Build Yellow "dotnet clean $Name"
        dotnet clean $dotnetSolution         
    }
}
