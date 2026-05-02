Add-BuildTask SonarQubeEnd @{
    If   = { $script:SonarProjectKey -and $script:SonarToken }
    Jobs = {
        dotnet tool execute sonarscanner end -d:"sonar.token=${script:SonarToken}"
    }
}