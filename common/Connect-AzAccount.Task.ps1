Add-BuildTask Connect-AzAccount @{
    If   = { $null -eq (Get-AzContext -ErrorAction SilentlyContinue) }
    Jobs = {
        Write-Build Yellow "Connect-AzContext -Passthru"
        Connect-AzContext -Passthru
    }
}
