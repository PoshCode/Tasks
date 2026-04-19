Add-BuildTask DotNetTrx2JUnit @{
    If      = if ($script:TargetFramework -eq "net8.0") { 
        dotnet tool list trx2junit | Select-Object -Skip 2
    } else { 
        (dotnet tool list trx2junit --format json | ConvertFrom-Json).data
    }
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
        Get-ChildItem $TestResultsRoot/*.trx | ForEach-Object -ThrottleLimit ([Environment]::ProcessorCount - 1) -Parallel { 
            dotnet trx2junit $_ | Select-String -Pattern "Converting\s'" 
        } 
    }
}