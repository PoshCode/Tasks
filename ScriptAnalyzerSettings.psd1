@{
    # Limit the generated records from: Error, Warning, Information.
    Severity = @('Error','Warning')

    # ExcludeRules runs the default set of rules except for:
    ExcludeRules = @('PSAvoidUsingDeprecatedManifestFields')

    # Customize rules
    Rules = @{
        PSAvoidUsingCmdletAliases = @{ Whitelist = @('Where','Select')}
        # We should set this to force 5.1 compatibility checks
        # PSUseCompatibleCmdlets = @{Compatibility = @("")}
    }
}
