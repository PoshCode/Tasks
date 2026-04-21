Add-BuildTask Convert-Coverage @{
    If   = { !$Script:SkipCoverage }
    Jobs = {
        Set-Location $SolutionTestResultsRoot
        # ------------------------------
        dotnet reportgenerator -reports:'./coverage/*.xml' `
            -targetdir:'./coverage' `
            -reporttypes:'Html;MarkdownSummaryGithub;TextSummary' `
            -filefilters:'+*;-/_*' `
            -title:"$script:ProductName" `
            -tag:"$(${script:Version}.InformationalVersion)"

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