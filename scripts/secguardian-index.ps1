# SecGuardian — Windows PowerShell indexer binary wrapper
#
# Detects platform and executes the appropriate binary.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BinDir = Join-Path $ScriptDir "bin"
$TargetBin = Join-Path $BinDir "secguardian-index-windows-amd64.exe"

if (-not (Test-Path $TargetBin)) {
    # Fallback to local built binary in internal/ for dev environment
    $DevBin = Join-Path (Split-Path $ScriptDir -Parent) "internal\secguardian-index.exe"
    if (Test-Path $DevBin) {
        & $DevBin $args
        exit $LASTEXITCODE
    }
    
    Write-Error "Indexer binary not found: $TargetBin"
    exit 1
}

& $TargetBin $args
exit $LASTEXITCODE
