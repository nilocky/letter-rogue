param(
    [string]$Dest = "T:\letter-rogue"
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "=== Exporting Web build..." -ForegroundColor Cyan
godot --headless --export-release "Web" build/web/index.html 2>&1
if (-not (Test-Path "build/web/index.html")) {
    Write-Host "Export failed - no index.html produced" -ForegroundColor Red
    exit 1
}

Write-Host "=== Copying to $Dest ..." -ForegroundColor Cyan
if (-not (Test-Path $Dest)) {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
}
Copy-Item -Path "$ProjectRoot\build\web\*" -Destination $Dest -Recurse -Force

Write-Host "=== Done. Deployed $(Get-ChildItem $Dest | Measure-Object | Select-Object -ExpandProperty Count) files to $Dest" -ForegroundColor Green
