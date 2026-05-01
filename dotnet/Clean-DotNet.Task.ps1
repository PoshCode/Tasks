Add-BuildTask Clean-DotNet @{
    Jobs    = {
        Write-Build Yellow "dotnet clean $Name"
        dotnet clean $DotNetSolutionFile
    }
}
