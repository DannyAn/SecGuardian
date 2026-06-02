#!/bin/bash
# SecGuardian — Release Build Script
#
# 构建所有发布产物到 dist/release/<version>/
#
# 用法:
#   bash scripts/release.sh [version]
#   bash scripts/release.sh 0.3.1
#
# 环境变量:
#   VERSION   版本号（默认从 git tag 或 CHANGELOG 取）
#   OUTPUT    输出目录（默认 dist/release）
#
# 输出:
#   dist/release/<version>/
#   ├── secguardian-index-<version>-darwin-arm64
#   ├── secguardian-index-<version>-darwin-arm64.sha256
#   ├── secguardian-index-<version>-darwin-amd64
#   ├── secguardian-index-<version>-darwin-amd64.sha256
#   ├── secguardian-index-<version>-linux-amd64
#   ├── secguardian-index-<version>-linux-amd64.sha256
#   ├── secguardian-index-<version>-windows-amd64.exe
#   ├── secguardian-index-<version>-windows-amd64.exe.sha256
#   ├── secguardian-<version>-claude-code-${PLATFORM_SUFFIX}.zip
#   ├── secguardian-<version>-opencode-${PLATFORM_SUFFIX}.zip
#   ├── secguardian-<version>-gemini-cli-${PLATFORM_SUFFIX}.zip
#   ├── secguardian-<version>-source.tar.gz
#   └── manifest.json

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(grep '^\#\# ' "$PROJECT_ROOT/CHANGELOG.md" | head -1 | sed 's/.*\[//;s/\].*//')}"
VERSION="${VERSION:-0.3.1}"
OUTPUT="${OUTPUT:-$PROJECT_ROOT/dist/release/$VERSION}"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log() { echo -e "${CYAN}  →${NC} $1"; }
done_msg() { echo -e "${GREEN}  ✓${NC} $1"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian Release Build v${VERSION}                  ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

mkdir -p "$OUTPUT"
# Clean previous release artifacts
rm -f "$OUTPUT"/*.zip "$OUTPUT"/*.zip.sha256 "$OUTPUT"/*.tar.gz "$OUTPUT"/*.tar.gz.sha256 "$OUTPUT"/secguardian-index-* "$OUTPUT"/manifest.json

# ── 1. Go Binary: macOS (native) ──────────────────
log "Building indexer binaries (macOS)..."
cd "$PROJECT_ROOT/internal"

# Detect current platform for naming
BUILD_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
BUILD_ARCH="$(uname -m | sed 's/x86_64/amd64/;s/arm64/arm64/;s/aarch64/arm64/')"
PLATFORM_SUFFIX="${BUILD_OS}-${BUILD_ARCH}"

for arch in arm64 amd64; do
    bin_name="secguardian-index-${VERSION}-darwin-${arch}"
    if GOOS=darwin GOARCH=$arch go build -o "$OUTPUT/$bin_name" . 2>/dev/null; then
        shasum -a 256 "$OUTPUT/$bin_name" | cut -d' ' -f1 > "$OUTPUT/$bin_name.sha256"
        done_msg "$bin_name ($(du -h "$OUTPUT/$bin_name" | cut -f1))"
    else
        log "WARN: $bin_name build failed (tree-sitter CGO) — try native build on $arch Mac"
    fi
done

# ── 1b. Build Notes ──────────────────────────────
log "Cross-platform note:"
log "  tree-sitter requires CGO, cross-compilation to Linux/Windows not possible locally."
log "  Linux/Windows binaries are built by CI (.github/workflows/ci.yml) on native runners."
log "  This release contains ${PLATFORM_SUFFIX} binaries only."
log "  For other platforms, download the source tarball and build natively:"
log "    cd internal && go build -o secguardian-index ."

# ── 2. Extension Packages ─────────────────────────
log "Building extension packages..."

cd "$PROJECT_ROOT"
bash scripts/package.sh > /dev/null 2>&1

# Claude Code: official plugin format (.claude-plugin/plugin.json)
bash scripts/deploy.sh cc > /dev/null 2>&1
claude_zip="$OUTPUT/secguardian-${VERSION}-claude-code-${PLATFORM_SUFFIX}.zip"
rm -f "$claude_zip"
if [ -d ".claude/plugins/secguardian" ]; then
    (cd .claude/plugins && zip -rq "$claude_zip" secguardian/)
    shasum -a 256 "$claude_zip" | cut -d' ' -f1 > "$claude_zip.sha256"
    done_msg "secguardian-${VERSION}-claude-code-${PLATFORM_SUFFIX}.zip ($(du -h "$claude_zip" | cut -f1))"
fi

# OpenCode: plugin under .opencode/plugins/secguardian/
bash scripts/deploy.sh nga > /dev/null 2>&1
opencode_zip="$OUTPUT/secguardian-${VERSION}-opencode-${PLATFORM_SUFFIX}.zip"
rm -f "$opencode_zip"
if [ -d ".opencode/plugins/secguardian" ]; then
    (cd .opencode/plugins && zip -rq "$opencode_zip" secguardian/)
    shasum -a 256 "$opencode_zip" | cut -d' ' -f1 > "$opencode_zip.sha256"
    done_msg "secguardian-${VERSION}-opencode-${PLATFORM_SUFFIX}.zip ($(du -h "$opencode_zip" | cut -f1))"
fi

# Gemini CLI: official extension format (.gemini/extensions/secguardian/)
bash scripts/deploy.sh cac > /dev/null 2>&1
gemini_zip="$OUTPUT/secguardian-${VERSION}-gemini-cli-${PLATFORM_SUFFIX}.zip"
rm -f "$gemini_zip"
if [ -d ".gemini/extensions/secguardian" ]; then
    (cd .gemini/extensions && zip -rq "$gemini_zip" secguardian/)
    shasum -a 256 "$gemini_zip" | cut -d' ' -f1 > "$gemini_zip.sha256"
    done_msg "secguardian-${VERSION}-gemini-cli-${PLATFORM_SUFFIX}.zip ($(du -h "$gemini_zip" | cut -f1))"
fi

# ── 3. Source Archive ─────────────────────────────
log "Packing source archive..."
source_archive="$OUTPUT/secguardian-${VERSION}-source.tar.gz"
git archive --format=tar.gz \
    --prefix="secguardian-${VERSION}/" \
    -o "$source_archive" HEAD
shasum -a 256 "$source_archive" | cut -d' ' -f1 > "$source_archive.sha256"
done_msg "secguardian-${VERSION}-source.tar.gz ($(du -h "$source_archive" | cut -f1))"

# ── 4. Manifest ──────────────────────────────────
log "Writing manifest..."
cat > "$OUTPUT/manifest.json" << EOF
{
  "version": "$VERSION",
  "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifacts": [
    {
      "name": "secguardian-index-${VERSION}-darwin-arm64",
      "os": "darwin",
      "arch": "arm64",
      "type": "indexer",
      "description": "Code indexer binary (tree-sitter), called by AI Agent commands"
    },
    {
      "name": "secguardian-index-${VERSION}-darwin-amd64",
      "os": "darwin",
      "arch": "amd64",
      "type": "indexer",
      "description": "Code indexer binary (tree-sitter), called by AI Agent commands"
    },
    {
      "name": "secguardian-${VERSION}-claude-code-${PLATFORM_SUFFIX}.zip",
      "platform": "claude-code",
      "type": "extension",
      "contents": ["commands", "skills", "knowledge", "scripts"]
    },
    {
      "name": "secguardian-${VERSION}-opencode-${PLATFORM_SUFFIX}.zip",
      "platform": "opencode",
      "type": "extension",
      "contents": ["commands", "skills", "knowledge", "scripts"],
      "install": ".opencode/"
    },
    {
      "name": "secguardian-${VERSION}-gemini-cli-${PLATFORM_SUFFIX}.zip",
      "platform": "gemini-cli",
      "type": "extension",
      "contents": ["commands", "skills", "knowledge", "scripts", "GEMINI.md"],
      "install": ".gemini/"
    },
    {
      "name": "secguardian-${VERSION}-source.tar.gz",
      "type": "source"
    }
  ],
  "detectors": 60,
  "cwe_top25": "25/25 (100%)",
  "owasp_top10": "10/10 (100%)",
	  "owasp_api_top10": "10/10 (100%)",
	  "audit_skills": 27
}
EOF
done_msg "manifest.json"

echo ""
echo -e "${GREEN}${BOLD}═══ Release v${VERSION} complete ═══${NC}"
echo -e "  Output: ${CYAN}$OUTPUT/${NC}"
ls -lh "$OUTPUT/" | grep -v "^total" | grep -v "^d" | awk '{print "  " $NF " (" $5 ")"}'
echo ""
echo -e "  ${BOLD}Next:${NC} Upload to GitHub Releases:"
echo -e "    gh release create v${VERSION} $OUTPUT/* --title 'v${VERSION}'"
