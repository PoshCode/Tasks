Add-BuildTask HelmInstall @{
    If   = ($script:ChartName -and $script:BuildSystem -ne "None")
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
        Write-Build Gray "Helm version: $(helm version --short)"

        # Install helm-schema plugin if not already installed
        if ('schema' -notin (helm plugin list | ForEach-Object { ($_ -split '\t')[0] })) {
            Write-Build Yellow "helm plugin install https://github.com/dadav/helm-schema --verify=false"
            helm plugin install https://github.com/dadav/helm-schema --verify=false
        }
    }
}
