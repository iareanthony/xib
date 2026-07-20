param(
    [string]$Release = "xib",
    [string]$Namespace = "xib-system",
    [string]$Registry = "registry.local/xib",
    [string]$Values = ".\k8s\values-airgap.yaml"
)

$ErrorActionPreference = "Stop"
& "$PSScriptRoot\preflight.ps1" -Namespace $Namespace
helm upgrade --install $Release .\k8s `
    --namespace $Namespace `
    --create-namespace `
    --values $Values `
    --set-string "global.imageRegistry=$Registry" `
    --wait `
    --timeout 10m

