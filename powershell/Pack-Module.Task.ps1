Add-BuildTask Pack-Module @{
    If   = { Test-Path $script:ManifestPath }
    Jobs = {
        function Get-ModuleTag {
            [CmdletBinding()]
            param(
                [PSModuleInfo]$Module,
                [string[]]$Tags = @()
            )
            end {
                if ($Tags) {
                    $TagSet = [System.Collections.Generic.HashSet[string]]::new($Tags)
                } else {
                    $TagSet = [System.Collections.Generic.HashSet[string]]::new()
                }

                $null = $TagSet.add('PSModule')

                foreach ($Cmd in $Module.ExportedCmdlets.Keys) {
                    $null = $TagSet.Add('PSIncludes_Cmdlet')
                    $null = $TagSet.add(('PSCmdlet_{0}' -f $Cmd))
                }

                foreach ($Fn in $Module.ExportedFunctions.Keys) {
                    $null = $TagSet.Add('PSIncludes_Function')
                    $null = $TagSet.add(('PSFunction_{0}' -f $Fn))
                }

                foreach ($Cmd in $Module.ExportedCommands.Keys) {
                    $null = $TagSet.add(('PSCommand_{0}' -f $Cmd))
                }

                # TODO: DSC resources are not supported
                # TODO: RoleCapabilities are not supported

                $TagSet -join ' '
            }
        }

        function Convert-Required {
            [OutputType([string])]
            [CmdletBinding()]
            param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [PSModuleInfo]$Module,
                [String[]]$ExternalModuleDependencies
            )
            process {
                # We require that the RequiredModules manifest and psm1 have the same name
                $ModuleData = Import-PowerShellDataFile ([IO.Path]::ChangeExtension($Module.Path, ".psd1"))
                [Microsoft.PowerShell.Commands.ModuleSpecification[]]$RequiredModules = $ModuleData.RequiredModules
                $Required = $RequiredModules.Where{
                    # Don't put external dependencies in the nuspec
                    $_.Name -notin $ExternalModuleDependencies
                }
                Wait-Debugger
                if ($Required.Count -eq 0) { return }

                "<dependencies>"
                $Required.ForEach{
                    $Version = if ($_.RequiredVersion) {
                        'version="[{0}]"' -f $_.RequiredVersion
                    } elseif ($_.Version -and $_.MaximumVersion) {
                        # Support wildcards?
                        'version="[{0},{1}]"' -f $_.Version, ($_.MaximumVersion -replace "\*$", "99999")
                    } elseif ($_.MaximumVersion) {
                        # Support wildcards?
                        'version="[, {0}]"' -f ($_.MaximumVersion -replace "\*$", "99999")
                    } elseif ($_.Version) {
                        'version="{0}"' -f $_.Version
                    } elseif (($Actual = Get-Module $_.Name)) {
                        # Best practice is not to specify an upper bound unless you KNOW of an incompatibility
                        'version="{0}"' -f $Actual.Version.ToString(3)
                    } elseif (($Actual = (Get-Module $_.Name -ListAvailable)[0])) {
                        # Best practice is not to specify an upper bound unless you KNOW of an incompatibility
                        'version="{0}"' -f $Actual.Version.ToString(3)
                    } else {
                        'version="0.0"'
                    }
                    '<dependency id="{0}" {1}/>' -f $_.Name, $Version
                }
                "</dependencies>"
            }
        }

        $NuspecPath = [IO.Path]::ChangeExtension($script:ManifestPath, ".nuspec")
        $Module = Get-Module -List $script:ManifestPath

        @"
<?xml version="1.0"?>
<package >
    <metadata>
        <id>{0}</id>
        <version>{1}</version>
        <authors>{2}</authors>
        <owners>{3}</owners>
        <description>{4}</description>
        <releaseNotes>{5}</releaseNotes>
        <requireLicenseAcceptance>{6}</requireLicenseAcceptance>
        <copyright>{7}</copyright>
        <tags>{8}</tags>
        {9}
    </metadata>
</package>
"@ -f $Module.Name,
        (@($Module.Version, $Module.PSData.Prerelease?.Trim("-")).Where{ $_ } -join '-'),
        $Module.Author,
        $Module.CompanyName,
        $Module.Description,
        $Module.ReleaseNotes,
        ([bool]$Module.PSData.RequireLicenseAcceptance).ToString().ToLower(),
        $Module.Copyright,
        (@(Get-ModuleTag -Module $Module -Tags $Module.PSData.Tags) -join " "),
        (@(
            ($Module.ProjectUri ? "<projectUrl>$($Module.ProjectUri)</projectUrl>" : "")
            ($Module.IconUri ? "<iconUrl>$($Module.IconUri)</iconUrl>" : "")
            ($Module.LicenseUri ? "<licenseUrl>$($Module.LicenseUri)</licenseUrl>" : "")
            @(Convert-Required $Module $Module.PSData.ExternalModuleDependencies)
        ) -join "`n        ")
        | Set-Content $NuspecPath -Encoding UTF8

        dotnet pack $NuspecPath --output $script:PSPackageRoot -v detailed -nologo
    }
}
