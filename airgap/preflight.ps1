param(
    [string]$Namespace = "xib-system",
    [string]$StorageClass = ""
)

$ErrorActionPreference = "Stop"
foreach ($command in "kubectl", "helm") {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "$command is required"
    }
}

kubectl version --client | Out-Null
kubectl cluster-info | Out-Null
$nodes = kubectl get nodes --no-headers
if (-not $nodes) { throw "The cluster has no nodes" }

if ($StorageClass) {
    kubectl get storageclass $StorageClass | Out-Null
} else {
    $defaults = kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'
    if (-not $defaults) { throw "No default StorageClass found; set global.storageClass" }
}

Write-Host "Preflight passed for namespace $Namespace"

