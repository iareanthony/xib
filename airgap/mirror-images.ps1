param(
    [Parameter(Mandatory = $true)][string]$Registry,
    [string]$ImageList = ".\airgap\images.txt"
)

$ErrorActionPreference = "Stop"
$images = Get-Content -LiteralPath $ImageList |
    Where-Object { $_ -and -not $_.TrimStart().StartsWith("#") }

foreach ($source in $images) {
    $leaf = ($source -split "/")[-1]
    $target = "$($Registry.TrimEnd('/'))/$leaf"
    docker pull $source
    docker tag $source $target
    docker push $target
    Write-Host "$source -> $target"
}

