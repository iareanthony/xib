param(
    [Parameter(Mandatory = $true)][string]$Archive,
    [ValidateSet("docker", "nerdctl")][string]$Runtime = "docker",
    [string]$Namespace = "k8s.io"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $Archive)) { throw "Archive not found: $Archive" }

if ($Runtime -eq "nerdctl") {
    nerdctl --namespace $Namespace load --input $Archive
} else {
    docker load --input $Archive
}

