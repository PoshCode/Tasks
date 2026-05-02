Add-BuildTask Convert-Trx2JUnit @{
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
            dotnet tool execute trx2junit $_ | Select-String -Pattern "Converting\s'"
        }
    }
}