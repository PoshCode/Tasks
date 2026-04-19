Add-BuildTask ConnectAzAccount @{
    If   = ($null -eq (Get-AzContext -ErrorAction SilentlyContinue) )
    Jobs = {
        Write-Build Gray "No Azure context found. Connecting to Azure..."

        if ($env:AZURE_CLIENT_ID -and $env:AZURE_TENANT_ID) {
            Write-Build Yellow "Connect-AzAccount -Identity -AccountId $env:AZURE_CLIENT_ID"
            Connect-AzAccount -Identity -AccountId $env:AZURE_CLIENT_ID | Out-Null
        } elseif ($env:AZURE_CLIENT_ID -and $env:AZURE_CLIENT_SECRET -and $env:AZURE_TENANT_ID) {
            Write-Build Yellow "Connect-AzAccount -ServicePrincipal -Credential $env:AZURE_CLIENT_ID -Tenant $env:AZURE_TENANT_ID"
            $SecurePassword = ConvertTo-SecureString $env:AZURE_CLIENT_SECRET -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential($env:AZURE_CLIENT_ID, $SecurePassword)
            Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $env:AZURE_TENANT_ID | Out-Null
        } else {
            Write-Build Yellow "Connect-AzAccount"
            Connect-AzAccount | Out-Null
        }

        $AzContext = Get-AzContext
        Write-Build Green "Connected to Azure as $($AzContext.Account.Id) in subscription $($AzContext.Subscription.Name)"
    }
}
