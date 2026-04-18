Add-BuildTask DotNetTrx2JUnit @{
    If      = (dotnet tool list trx2junit --format json | ConvertFrom-Json).data
    Partial = $true
    Input   = {
        Get-ChildItem $TestResultsRoot/*.trx
    }
    Output  = {
        process {
            [System.IO.Path]::ChangeExtension($_, 'xml')
        }
    }
    Jobs    = {
        process {
            dotnet trx2junit $_
        }
    }
}