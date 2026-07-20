param(
    [string]$OutputDirectory = ".\bundle",
    [string]$ImageList = ".\airgap\images.txt"
)

$ErrorActionPreference = "Stop"
$images = Get-Content -LiteralPath $ImageList |
    Where-Object { $_ -and -not $_.TrimStart().StartsWith("#") }

if (-not $images) { throw "No images found in $ImageList" }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

foreach ($image in $images) {
    docker pull $image
}

$archive = Join-Path $OutputDirectory "xib-images.tar"
docker save --output $archive $images
Copy-Item -LiteralPath $ImageList -Destination (Join-Path $OutputDirectory "images.txt")
Get-FileHash -Algorithm SHA256 -LiteralPath $archive |
    ForEach-Object { "$($_.Hash.ToLower())  xib-images.tar" } |
    Set-Content -LiteralPath (Join-Path $OutputDirectory "SHA256SUMS")

Write-Host "Created $archive"

