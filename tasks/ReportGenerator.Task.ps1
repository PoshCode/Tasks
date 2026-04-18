Add-BuildTask ReportGenerator @{
    If   = $Script:CollectCoverage
    Jobs = {
        Set-Location $TestResultsRoot
        # ------------------------------
        dotnet reportgenerator -reports:'./coverage/*.xml' `
            -targetdir:'./coverage' `
            -reporttypes:'Html;MarkdownSummaryGithub;TextSummary' `
            -filefilters:'+*;-/_*' `
            -title:"$script:ProductName" `
            -tag:"$(${script:Version}.SemVer)_${script:PipelineId}_${script:PipelineExecutionId}"

        switch ($script:BuildSystem) {
            "AzureDevops" {
                Write-Build Gray "##vso[task.uploadsummary]$TestResultsRoot/coverage/SummaryGithub.md"
            }
            "Harness" {
                # https://developer.harness.io/docs/continuous-integration/use-ci/annotate-builds/
                hcli annotate --context test-summary --summary-file "$TestResultsRoot/coverage/SummaryGithub.md"
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