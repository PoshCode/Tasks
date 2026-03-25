# TODO: This task needs to install helm on linux and windows, in CI or in local
Add-BuildTask Install-Helm @{
    If   = { $script:ChartName -and $script:BuildSystem -ne "None" }
    Jobs = {
        # Install Helm binary if not available (pipeline/Linux)
        if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
            if ($IsLinux) {
                $HelmVersion = "v4.1.0"
                Write-Build Yellow "Invoke-WebRequest -Uri https://get.helm.sh/helm-${HelmVersion}-linux-amd64.tar.gz -OutFile $TarFile"
                $TarFile = Join-Path $script:TempDirectory "helm.tar.gz"
                Invoke-WebRequest -Uri "https://get.helm.sh/helm-${HelmVersion}-linux-amd64.tar.gz" -OutFile $TarFile
                tar -zxvf $TarFile -C $script:TempDirectory
                Move-Item (Join-Path $script:TempDirectory "linux-amd64/helm") "/usr/local/bin/helm" -Force
                Remove-Item $TarFile -Force -ErrorAction SilentlyContinue
                Remove-Item (Join-Path $script:TempDirectory "linux-amd64") -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                throw "Helm is not installed. Please install Helm: https://helm.sh/docs/intro/install/"
            }
        }
        $HelmVersionShort = helm version --short
        Write-Build Gray "Helm version: $HelmVersionShort"

        # Install helm-schema plugin if not already installed
        # TODO: This will be a PITA for windows
        if ('schema' -notin (helm plugin list | ForEach-Object { ($_ -split '\t')[0] })) {
            # bug was introduced by owner of the helm-schema plugin in 0.23.0 and they "unreleased" it but didn't remove the latest tag on GitHub for it. So we have to pin to 0.22.0 for now until they fix it.
            if ($HelmVersionShort -ilike "v4*") {
                Write-Build Yellow "helm plugin install https://github.com/dadav/helm-schema --version 0.22.0 --verify=false"
                helm plugin install https://github.com/dadav/helm-schema --version 0.22.0 --verify=false
            } else {
                Write-Build Yellow "helm plugin install https://github.com/dadav/helm-schema --version 0.22.0"
                helm plugin install https://github.com/dadav/helm-schema --version 0.22.0
            }
        }
    }
}
