Add-BuildTask GitInit @{
    If = {
        -not (git config user.name) -or -not (git config user.email) -or ($script:GitUser -and $script:GitUser -ne (git config user.name))
    }
    Jobs = {
        # If the user is already set, don't change it
        $Script:GitUser ??= (git config user.name) ?? 'Autobot'
        # If we're running in the CI/CD pipeline we need to set the author so we can pass the commit email policy
        git config user.name $Script:GitUser
        git config user.email 'DevOps@loandepot.com'
    }
}
