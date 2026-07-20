param([string]$OutputDirectory = ".\bundle", [switch]$IncludeOllamaModel)
$ErrorActionPreference = "Stop"
$sources = Get-Content "$PSScriptRoot\artifact-sources.json" | ConvertFrom-Json
$artifactDir = New-Item -ItemType Directory -Force "$OutputDirectory\artifacts"
$chartDir = New-Item -ItemType Directory -Force "$artifactDir\falco-charts"
$trivyDir = New-Item -ItemType Directory -Force "$artifactDir\trivy-cache"
docker run --rm --volume "$($trivyDir.FullName):/root/.cache/trivy" $sources.trivyImage image --download-db-only
Invoke-WebRequest $sources.cisaKev -OutFile "$artifactDir\known_exploited_vulnerabilities.json"
Invoke-WebRequest $sources.epssCsv -OutFile "$artifactDir\epss_scores-current.csv.gz"
helm pull falco --repo https://falcosecurity.github.io/charts --version $sources.falcoCharts.falco --destination $chartDir
helm pull falcosidekick --repo https://falcosecurity.github.io/charts --version $sources.falcoCharts.falcosidekick --destination $chartDir
$extraImages = @($sources.trivyImage) + @($sources.falcoImages) + @($sources.ollamaImage)
$extraImages | ForEach-Object { docker pull $_ }
if ($IncludeOllamaModel) {
  $ollamaDir = New-Item -ItemType Directory -Force "$artifactDir\ollama"
  docker run --detach --rm --name xib-ollama-export --volume "$($ollamaDir.FullName):/root/.ollama" $sources.ollamaImage | Out-Null
  try { docker exec xib-ollama-export ollama pull $sources.ollamaModel } finally { docker stop xib-ollama-export | Out-Null }
  Set-Content "$ollamaDir\MODEL" $sources.ollamaModel
}
docker save --output "$OutputDirectory\xib-artifact-images.tar" $extraImages
Get-ChildItem $OutputDirectory -Recurse -File | Where-Object Name -ne "SHA256SUMS" | ForEach-Object {
  "{0}  {1}" -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.FullName.Substring((Resolve-Path $OutputDirectory).Path.Length + 1).Replace('\','/')
} | Set-Content "$OutputDirectory\SHA256SUMS"
Write-Host "Offline artifacts populated in $OutputDirectory"
