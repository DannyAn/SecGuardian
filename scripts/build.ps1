<#
.SYNOPSIS
  SecGuardian Windows Build Script
.DESCRIPTION
  Builds the secguardian Go binary and deploys extensions for Windows.
.PARAMETER Target
  Build target: all (default), cc, nga, cac, or binary-only
.EXAMPLE
  .\scripts\build.ps1
  .\scripts\build.ps1 binary
#>
param(
    [string]$Target = "all"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host ""
Write-Host "=== SecGuardian Build (Windows) ===" -ForegroundColor Cyan

# Step 1: Build Go binary
Write-Host "  → Building secguardian binary..." -ForegroundColor Cyan
Push-Location "$Root\internal"
try {
    go build -o secguardian.exe .
    $binSize = (Get-Item secguardian.exe).Length / 1MB
    Write-Host "    Built: secguardian.exe ($([math]::Round($binSize, 1)) MB)" -ForegroundColor Green
} finally {
    Pop-Location
}

# Copy binary to scripts/
Copy-Item -Force "$Root\internal\secguardian.exe" "$Root\scripts\secguardian.exe"
Write-Host "    Copied to scripts/secguardian.exe" -ForegroundColor Green

if ($Target -eq "binary") {
    Write-Host "Done (binary only)." -ForegroundColor Green
    exit 0
}

# Step 2: Package + deploy extensions
Write-Host "  → Packaging extensions..." -ForegroundColor Cyan
# Note: package/deploy scripts are bash for now, invoke via the Go binary instead
Write-Host "    Extension deployment available via Go CLI: secguardian detectors" -ForegroundColor Yellow

Write-Host ""
Write-Host "Build complete." -ForegroundColor Green
Write-Host "Run: .\scripts\secguardian.exe help" -ForegroundColor White
