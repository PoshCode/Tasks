Add-BuildTask DockerBuild @{
    # This task can only be skipped if the images are newer than the source files
    If      = $dotnetProjects
    Inputs  = {
        $dotnetProjects.Where{ Get-ChildItem (Split-Path $_) -File -Filter Dockerfile } |
            Get-ChildItem -File
    }
    Outputs = {
        # We use the iidfile as a standing for date of the image
        # Projects that have an adjacent Dockerfile
        $dotnetProjects
        | Where-Object { Get-ChildItem (Split-Path $_) -File -Filter Dockerfile }
        | Join-Path -Path $OutputRoot -ChildPath { (Split-Path $_ -LeafBase).ToLower() }
    }
    Jobs    = {
        foreach ($project in $dotnetProjects.Where{ Get-ChildItem (Split-Path $_) -File -Filter Dockerfile }) {
            Set-Location (Split-Path $project)
            $name = (Split-Path $project -LeafBase).ToLower()

            Write-Build Gray "docker build . --tag $name --iidfile $(Join-Path $OutputRoot $name)"
            docker build . --tag $name --iidfile (Join-Path $OutputRoot $name)
        }
    }
}
