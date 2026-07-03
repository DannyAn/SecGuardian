# SecGuardian — Windows PowerShell indexer binary wrapper
#
# Invokes the canonical secguardian-index binary from bin/.
# In release packages the binary is always named 'secguardian-index.exe'
# regardless of platform.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BinDir = Join-Path $ScriptDir "bin"

# 1. Canonical name (release packages)
$Canonical = Join-Path $BinDir "secguardian-index.exe"
if (Test-Path $Canonical) {
    & $Canonical $args
    exit $LASTEXITCODE
}

# 2. Platform-specific fallback (dev builds)
$PlatformBin = Join-Path $BinDir "secguardian-index-windows-amd64.exe"
if (Test-Path $PlatformBin) {
    & $PlatformBin $args
    exit $LASTEXITCODE
}

# 3. Dev fallback
$DevBin = Join-Path (Split-Path $ScriptDir -Parent) "internal\secguardian-index.exe"
if (Test-Path $DevBin) {
    & $DevBin $args
    exit $LASTEXITCODE
}

Write-Error "Indexer binary not found. Expected: $Canonical"
exit 1
