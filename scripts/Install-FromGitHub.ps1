<#PSScriptInfo

.VERSION 1.5.2

.GUID 23addf96-d1d7-4f51-b97f-c4f0189263b6

.AUTHOR Joel 'Jaykul' Bennett

.COMPANYNAME HuddledMasses.org

.COPYRIGHT (c) Joel Bennett. All rights reserved.

.TAGS Installer GitHub Releases Binaries Linux Windows MacOS

.LICENSEURI https://github.com/Jaykul/FromGitHub/blob/main/LICENSE

.PROJECTURI https://github.com/Jaykul/FromGitHub

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

        FromGitHub v1.5.2+Build.local.Sha.d528184585be78a00fe7f69c808af9b12bc2a398.Date.20250711T045707
        1.5.2 - Fix metadata problems in published module and script
        1.5.1 - Fix a bug in SelectAssetByPlatform not using the order of OS and Architecture to select the best match.
        1.5.0 - Convert to a module with a build that exports the script


.PRIVATEDATA

#>



<#
.SYNOPSIS
Install a binary from a github release.

.DESCRIPTION
An installer for single-binary tools released on GitHub.
This cross-platform script will download, check the file hash,
unpack and and make sure the binary is on your PATH.

It uses the github API to get the details of the release and find the
list of downloadable assets, and relies on the common naming convention
to detect the right binary for your OS (and architecture).

.NOTES
All these examples are (only) tested on Windows and WSL Ubuntu


.EXAMPLE
Install-FromGitHub FluxCD Flux2

Install `Flux` from the https://github.com/FluxCD/Flux2 repository

.EXAMPLE
Install-FromGitHub earthly earthly

Install `earthly` from the https://github.com/earthly/earthly repository

.EXAMPLE
Install-FromGitHub junegunn fzf

Install `fzf` from the https://github.com/junegunn/fzf repository

.EXAMPLE
Install-FromGitHub BurntSushi ripgrep

Install `rg` from the https://github.com/BurntSushi/ripgrep repository

.EXAMPLE
Install-FromGitHub opentofu opentofu

Install `opentofu` from the https://github.com/opentofu/opentofu repository

.EXAMPLE
Install-FromGitHub twpayne chezmoi

Install `chezmoi` from the https://github.com/twpayne/chezmoi repository

.EXAMPLE
Install-GitHubRelease https://github.com/mikefarah/yq/releases/tag/v4.44.6

Install `yq` version v4.44.6 from it's release on github.com

.EXAMPLE
Install-FromGitHub sharkdp/bat
Install-FromGitHub sharkdp/fd

Install `bat` and `fd` from their repositories

#>

[Alias("Install-GitHubRelease")]
[CmdletBinding(SupportsShouldProcess)]
param(
        # The user or organization that owns the repository
        # Also supports pasting the org and repo as a single string: fluxcd/flux2
        # Or passing the full URL to the project: https://github.com/fluxcd/flux2
        # Or a specific release: https://github.com/fluxcd/flux2/releases/tag/v2.5.0
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("User")]
        [string]$Org,

        # The name of the repository or project to download from
        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [string]$Repo,

        # The tag of the release to download. Defaults to 'latest'
        [Parameter(Position = 2, ValueFromPipelineByPropertyName)]
        [Alias("Version")]
        [string]$Tag = 'latest',

        # Skip prompting to create the "BinDir" tool directory (on Windows)
        [switch]$Force,

        # A regex pattern to override selecting the right option from the assets on the release
        # The operating system is automatically detected, you do not need to pass this parameter
        [string]$OS,

        # A regex pattern to override selecting the right option from the assets on the release
        # The architecture is automatically detected, you do not need to pass this parameter
        [string]$Architecture,

        # The location to install to.
        # Defaults to $Env:LocalAppData\Programs\Tools on Windows, /usr/local/bin on Linux/MacOS
        # There's normally no reason to pass this parameter
        [string]$BinDir,

        # Optionally, the file name for the executable (it will be renamed to this)
        [string]$ExecutableName
    )


@(
'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'
)|.{

    [CmdletBinding(DefaultParameterSetName = "ByteArray")]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Base64Content
    )
    process {
        $Out = [System.IO.MemoryStream]::new()
        $In = [System.IO.MemoryStream][System.Convert]::FromBase64String($Base64Content)
        $zip = [System.IO.Compression.DeflateStream]::new($In, [System.IO.Compression.CompressionMode]::Decompress)
        $zip.CopyTo($Out)
        trap [System.IO.InvalidDataException] {
            Write-Debug "Base64Content not Compressed. Skipping Deflate."
            $In.CopyTo($Out)
            continue
        }
        $null = $Out.Seek(0, "Begin")
        $null = [System.Reflection.Assembly]::Load($Out.ToArray())
        trap [BadImageFormatException] {
            Write-Debug "Base64Content not an Assembly. Trying New-Module and ScriptBlock.Create."
            $null = $Out.Seek(0, "Begin")
            # Use StreamReader to handle possible BOM
            $Source = [System.IO.StreamReader]::new($Out, $true).ReadToEnd()
            $null = New-Module ([ScriptBlock]::Create($Source)) -Verbose:$false | Import-Module -Scope Global -Verbose:$false
            continue
        }
    }

}
Install-FromGitHub @PSBoundParameters