# TODO: This script can be removed, see ll1-15 Initialize.ps1
$ErrorView = "DetailedView"
$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"
$PSStyle.OutputRendering = "ANSI"

# Force different colors for Verbose and Debug
if ($PSStyle.Formatting.Verbose -eq $PSStyle.Formatting.Warning) {
    $PSStyle.Formatting.Verbose = $PSStyle.Foreground.BrightCyan
}
if ($PSStyle.Formatting.Debug -eq $PSStyle.Formatting.Warning) {
    $PSStyle.Formatting.Debug = $PSStyle.Foreground.BrightGreen
}

# turn on debug and verbose if the pipeline is run in debug mode
if ($ENV:AGENT_DIAGNOSTIC -eq 'True' -or $ENV:SYSTEM_DEBUG -eq 'True') {
    $script:VerbosePreference = "Continue"
    $script:DebugPreference = "Continue"
    $PSStyle
}
