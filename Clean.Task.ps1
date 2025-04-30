Add-BuildTask Clean {
    # This will blow away everything that's .gitignored, and fast
    git clean -Xdf

    # Ensure the output directories from Initialize are still there
    New-Item -Type Directory -Path $OutputRoot -Force | Out-Null
    New-Item -Type Directory -Path $TestResultsRoot -Force | Out-Null
    New-Item -Type Directory -Path $TempRoot -Force | Out-Null
}