<#
.SYNOPSIS
  SecGuardian CLI Entry Point (Windows)
.DESCRIPTION
  Launches the secguardian cross-platform Go binary.
  This is the primary entry point for Windows users.
.EXAMPLE
  .\scripts\secguardian.ps1 help
  .\scripts\secguardian.ps1 detectors
  .\scripts\secguardian.ps1 scan --path .\src --filters memory.*
  .\scripts\secguardian.ps1 audit --skill list
#>
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$Root = Split-Path -Parent $PSScriptRoot
$Binary = "$Root\scripts\secguardian.exe"

# Check if binary needs building
if (-not (Test-Path $Binary)) {
    Write-Host "secguardian binary not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build.ps1" binary
    if (-not (Test-Path $Binary)) {
        Write-Host "Build failed. Ensure Go 1.22+ is installed." -ForegroundColor Red
        exit 1
    }
}

# Run the Go binary with all arguments
& $Binary @Args
