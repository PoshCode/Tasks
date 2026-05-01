Add-BuildTask Convert-Trx2JUnit @{
    If      = { if ($script:TargetFramework -eq "net8.0") {
        dotnet tool list trx2junit | Select-Object -Skip 2
        } else {
            (dotnet tool list trx2junit --format json | ConvertFrom-Json).data
        } }
    Partial = $true
    Input   = {
        New-Item -Type Directory -Path $SolutionTestResultsRoot -Force | Out-Null
        Get-ChildItem $SolutionTestResultsRoot/*.trx
    }
    Output  = {
        process {
            [System.IO.Path]::ChangeExtension($_, 'xml')
        }
    }
    Jobs    = {
        Get-ChildItem $SolutionTestResultsRoot/*.trx | ForEach-Object -ThrottleLimit ([Environment]::ProcessorCount - 1) -Parallel {
            dotnet trx2junit $_ | Select-String -Pattern "Converting\s'"
        }
    }
}