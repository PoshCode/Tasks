Add-BuildTask Connect-AzACR @{
    Jobs = {
        if ($env:AZURE_ACCESS_TOKEN) {
            # Pipeline path: use the OIDC plugin token directly
            Write-Build Gray "Using AZURE_ACCESS_TOKEN from OIDC plugin"
            $TenantId = $env:AZURE_TENANT_ID ?? (Get-AzContext).Tenant.Id

            Write-Build Gray "Exchanging access token for ACR refresh token..."
            $RefreshToken = (Invoke-RestMethod -Uri "https://$script:ACRUri/oauth2/exchange" -Method Post -Body @{
                grant_type   = "access_token"
                service      = $script:ACRUri
                access_token = $env:AZURE_ACCESS_TOKEN
                tenant       = $TenantId
            }).refresh_token

            Write-Build Yellow "helm registry login $script:ACRUri"
            $RefreshToken | helm registry login $script:ACRUri --username "00000000-0000-0000-0000-000000000000" --password-stdin
        } else {
            # Local path: use Az context via Connect-AzContainerRegistry
            if ($null -eq (Get-AzContext -ErrorAction SilentlyContinue)) {
                throw "No AZURE_ACCESS_TOKEN and no Az context. Run Connect-AzAccount first or provide AZURE_ACCESS_TOKEN."
            }
            Write-Build Yellow "Connect-AzContainerRegistry -Name $($script:ACRName)"
            Connect-AzContainerRegistry -Name $script:ACRName
        }
    }
}
