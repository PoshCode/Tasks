Add-BuildTask Push-Helm @{
    Jobs = "Connect-AzACR", {
        $Package = Get-ChildItem $script:HelmOutputRoot -Recurse -Filter *.tgz

        $HelmPushEnabled = $script:HelmRepository -and $Package -and (
            $script:PushEnabled -or (
                $script:BuildSystem -ne "None" -and
                ($script:BranchName -eq "main" -or $script:BranchName -like "release/*")
            )
        )

        if ($HelmPushEnabled) {
            foreach ($Chart in $Package) {
                Write-Build Yellow "helm push $($Chart.FullName) $script:HelmRepository"
                Invoke-Native { helm push $Chart.FullName $script:HelmRepository } -ExceptionalExit
            }
        } else {
            Write-Warning ("Skipping Push for Helm. To push ensure that...`n" +
                "`t* You have charts to push in $script:HelmOutputRoot (Current: $(@($Package).Count))`n" +
                "`t* The repository URI is defined in `$HelmRepository (Current: $(!!"$HelmRepository"))`n" +
                "`t* You have set PushEnabled (Current: $script:PushEnabled) OR`n" +
                "`t* You are in a known build system (Current: $BuildSystem) AND`n" +
                "`t* You are committing to the main branch (Current: $BranchName)")
        }
    }
}
