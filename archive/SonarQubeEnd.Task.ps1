Add-BuildTask SonarQubeEnd @{
    If   = { $script:SonarProjectKey -and $script:SonarToken }
    Jobs = {
        dotnet sonarscanner end -d:"sonar.token=${script:SonarToken}"
    }
}