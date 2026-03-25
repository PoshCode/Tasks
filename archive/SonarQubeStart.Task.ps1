Add-BuildTask SonarQubeStart @{
    If   = { $script:SonarProjectKey -and $script:SonarToken }
    Jobs = "Get-Version", {
        dotnet sonarscanner begin `
            -key:"$($Script:SonarProjectKey)" `
            -version:"$(${script:Version}.SemVer)" `
            -d:"sonar.token=${script:SonarToken}" `
            -d:"sonar.host.url=${script:SonarHostURL}" `
            -d:"sonar.cs.vscoveragexml.reportsPaths=$TestResultsRoot/coverage/*.xml" `
            -d:sonar.exclusions=*.xsd
    }
}