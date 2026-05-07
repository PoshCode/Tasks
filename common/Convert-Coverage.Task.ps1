Add-BuildTask Convert-Coverage @{
    If   = { !$Script:SkipCoverage }
    Jobs = {
        New-Item -Type Directory -Path $SolutionTestResultsRoot -Force | Out-Null
        Set-Location $SolutionTestResultsRoot
        # ------------------------------
        dotnet tool execute dotnet-reportgenerator-globaltool -reports:'./coverage/*.xml' `
            -targetdir:'./coverage' `
            -reporttypes:'Html;MarkdownSummaryGithub;TextSummary' `
            -filefilters:'+*;-/_*' `
            -title:"$script:ProductName" `
            -tag:"$(${script:Version}.InformationalVersion)" `
            --yes

        switch ($script:BuildSystem) {
            "AzureDevOps" {
                Write-Build Gray "##vso[task.uploadsummary]$SolutionTestResultsRoot/coverage/SummaryGithub.md"
            }
            "Harness" {
                # https://developer.harness.io/docs/continuous-integration/use-ci/annotate-builds/
                hcli annotate --context test-summary --summary-file "$SolutionTestResultsRoot/coverage/SummaryGithub.md"
            }
            "GitHubActions" {
                Get-Content ./coverage/SummaryGithub.md -Raw
            }
            default {
                Get-Content ./coverage/Summary.txt -TotalCount 17
            }
        }
    }
}