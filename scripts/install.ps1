# ╔══════════════════════════════════════════════════════════════╗
# ║  SecGuardian — Installer (Windows PowerShell)               ║
# ║  将发布包安装到用户级或项目级 AI Agent 目录中                ║
# ╚══════════════════════════════════════════════════════════════╝
#
# 用法:
#   .\install.ps1 -User [options]              # 用户级（推荐）
#   .\install.ps1 <target-project> [options]   # 项目级
#
# 选项:
#   -User               安装到用户家目录（推荐，跨项目共用）
#   -All                安装全部三个平台 (默认)
#   -Claude             仅安装 Claude Code
#   -OpenCode           仅安装 OpenCode
#   -Gemini             仅安装 Gemini CLI
#   -ReleaseDir <dir>   指定发布包所在目录 (默认: 当前目录)
#   -Version <ver>      指定版本号 (默认: 自动检测)
#   -DryRun             仅显示将要执行的操作，不实际安装
#   -NoBackup           不备份已有安装
#
# 示例:
#   # 用户级安装（推荐）
#   .\install.ps1 -User -All                 # 安装全部平台到 %USERPROFILE%
#   .\install.ps1 -User -OpenCode            # 仅 OpenCode 到 %USERPROFILE%\.opencode\
#
#   # 项目级安装
#   .\install.ps1 C:\Users\me\my-project -All
#   .\install.ps1 C:\Users\me\my-project -OpenCode
#   .\install.ps1 C:\Users\me\my-project -ReleaseDir .\release -DryRun

param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Target = "",

    [Parameter()]
    [switch]$User = $false,

    [Parameter()]
    [ValidateSet("All", "Claude", "OpenCode", "Gemini")]
    [string]$Platform = "All",

    [Parameter()]
    [string]$ReleaseDir = ".",

    [Parameter()]
    [string]$Version = "",

    [Parameter()]
    [switch]$DryRun = $false,

    [Parameter()]
    [switch]$NoBackup = $false
)

$ErrorActionPreference = "Stop"

# ── 颜色函数 ──────────────────────────────────
function Write-Step  { Write-Host "`n═══ $args ═══" -ForegroundColor White }
function Write-Info  { Write-Host "  → $args" -ForegroundColor Cyan }
function Write-Done  { Write-Host "  ✓ $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "  ⚠ $args" -ForegroundColor Yellow }
function Write-ErrorMsg { Write-Host "  ✗ $args" -ForegroundColor Red }

# ── 确定安装目标 ──────────────────────────────
if ($User) {
    $Target = $env:USERPROFILE
    $InstallMode = "用户级"
    $InstallModeDesc = "跨所有项目可用"
} else {
    if ([string]::IsNullOrEmpty($Target)) {
        Write-ErrorMsg "请指定 -User（用户级安装）或 <project-path>（项目级安装）"
        Write-Host ""
        Write-Host "  用户级（推荐）:  .\install.ps1 -User -All"
        Write-Host "  项目级:          .\install.ps1 C:\Users\me\my-project -OpenCode"
        exit 1
    }
    $Target = Resolve-Path $Target -ErrorAction Stop
    $InstallMode = "项目级"
    $InstallModeDesc = "仅当前项目可用"
}

$ReleaseDir = Resolve-Path $ReleaseDir -ErrorAction SilentlyContinue
if (-not $ReleaseDir) { $ReleaseDir = (Get-Location).Path }

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor White
Write-Host "║  SecGuardian — ${InstallMode}安装                   ║" -ForegroundColor White
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor White
Write-Host ""
Write-Host "  安装模式: $InstallMode ($InstallModeDesc)" -ForegroundColor Cyan
Write-Host "  安装路径: $Target" -ForegroundColor Cyan
Write-Host "  平台:     $Platform" -ForegroundColor Cyan
Write-Host ""

# ── 自动检测版本 ──────────────────────────────
if ([string]::IsNullOrEmpty($Version)) {
    $zipFiles = Get-ChildItem -Path $ReleaseDir -Filter "secguardian-*-claude-code.zip" -ErrorAction SilentlyContinue
    if ($zipFiles) {
        $firstZip = $zipFiles[0].Name
        if ($firstZip -match "secguardian-(.+)-claude-code\.zip") {
            $Version = $matches[1]
        }
    }
    if ([string]::IsNullOrEmpty($Version)) {
        $Version = "0.4.0"
    }
}

Write-Info "检测到版本: v$Version"

# ── 查找发布包 ────────────────────────────────
function Find-Zip {
    param([string]$Pattern)
    $found = Get-ChildItem -Path $ReleaseDir -Filter $Pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    return $found
}

# ── 备份函数 ──────────────────────────────────
function Backup-Dir {
    param([string]$Path)
    if ((Test-Path $Path) -and (Get-ChildItem -Path $Path -ErrorAction SilentlyContinue)) {
        $backup = "$Path.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item -Path $Path -Destination $backup
        Write-Info "已备份: $backup"
    }
}

# ── 安装 Claude Code ──────────────────────────
function Install-Claude {
    if ($User) {
        Write-Step "Claude Code → ~\.claude\extensions\ (用户级)"
    } else {
        Write-Step "Claude Code → .claude\extensions\ (项目级)"
    }

    $zip = Find-Zip -Pattern "secguardian-${Version}-claude-code.zip"
    if (-not $zip) {
        Write-Warn "未找到 Claude Code 发布包，跳过"
        Write-Info "期望文件: secguardian-${Version}-claude-code.zip"
        return $false
    }

    $extDir = Join-Path $Target ".claude\extensions"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] 解压 $($zip.FullName) → $extDir\"
        return $true
    }

    if (-not $NoBackup) { Backup-Dir -Path $extDir }
    if (Test-Path $extDir) { Remove-Item -Recurse -Force $extDir }
    New-Item -ItemType Directory -Path $extDir -Force | Out-Null

    Expand-Archive -Path $zip.FullName -DestinationPath $extDir -Force
    Write-Done "已安装到 $extDir\"

    $count = (Get-ChildItem -Directory -Path $extDir).Count
    Write-Info "安装了 $count 个 extension"
    return $true
}

# ── 安装 OpenCode ─────────────────────────────
function Install-OpenCode {
    if ($User) {
        Write-Step "OpenCode → ~\.opencode\ (用户级)"
    } else {
        Write-Step "OpenCode → .opencode\ (项目级)"
    }

    $zip = Find-Zip -Pattern "secguardian-${Version}-opencode.zip"
    if (-not $zip) {
        Write-Warn "未找到 OpenCode 发布包，跳过"
        Write-Info "期望文件: secguardian-${Version}-opencode.zip"
        return $false
    }

    $ocDir = Join-Path $Target ".opencode"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] 解压 $($zip.FullName) → $ocDir\"
        return $true
    }

    if (-not $NoBackup) { Backup-Dir -Path $ocDir }
    if (Test-Path $ocDir) { Remove-Item -Recurse -Force $ocDir }
    New-Item -ItemType Directory -Path $ocDir -Force | Out-Null

    Expand-Archive -Path $zip.FullName -DestinationPath $ocDir -Force
    Write-Done "已安装到 $ocDir\"
    return $true
}

# ── 安装 Gemini CLI ───────────────────────────
function Install-Gemini {
    if ($User) {
        Write-Step "Gemini CLI → ~\.gemini\ (用户级)"
    } else {
        Write-Step "Gemini CLI → .gemini\ (项目级)"
    }

    $zip = Find-Zip -Pattern "secguardian-${Version}-gemini-cli.zip"
    if (-not $zip) {
        Write-Warn "未找到 Gemini CLI 发布包，跳过"
        Write-Info "期望文件: secguardian-${Version}-gemini-cli.zip"
        return $false
    }

    $gmDir = Join-Path $Target ".gemini"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] 解压 $($zip.FullName) → $gmDir\"
        return $true
    }

    if (-not $NoBackup) { Backup-Dir -Path $gmDir }
    if (Test-Path $gmDir) { Remove-Item -Recurse -Force $gmDir }
    New-Item -ItemType Directory -Path $gmDir -Force | Out-Null

    Expand-Archive -Path $zip.FullName -DestinationPath $gmDir -Force
    Write-Done "已安装到 $gmDir\"
    return $true
}

# ── 健康检查 ──────────────────────────────────
function Invoke-HealthCheck {
    Write-Step "健康检查"

    $indexer = $null
    $candidates = @(
        (Join-Path $Target ".opencode\scripts\secguardian-index.ps1"),
        (Join-Path $Target ".gemini\scripts\secguardian-index.ps1"),
        (Join-Path $Target ".claude\extensions\secguard-secguardian\scripts\secguardian-index.ps1")
    )

    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $indexer = $c
            break
        }
    }

    if (-not $indexer) {
        Write-Warn "未找到 secguardian-index.ps1 wrapper"
        return
    }

    if ($DryRun) {
        Write-Host "  [DRY-RUN] powershell $indexer --health"
        return
    }

    try {
        & powershell -File $indexer --health 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Done "索引器健康检查通过"
        } else {
            Write-Warn "索引器健康检查完成（退出码: $LASTEXITCODE）"
        }
    } catch {
        Write-Warn "索引器健康检查失败: $_"
    }
}

# ── 安装摘要 ──────────────────────────────────
function Write-Summary {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════" -ForegroundColor White
    Write-Host "  安装完成!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  安装模式: $InstallMode" -ForegroundColor Cyan
    Write-Host "  安装路径: $Target" -ForegroundColor Cyan
    Write-Host ""

    $claudeDir = Join-Path $Target ".claude\extensions"
    if ((Test-Path $claudeDir) -and (Get-ChildItem -Path $claudeDir -ErrorAction SilentlyContinue)) {
        Write-Host "  ✓ Claude Code:  $claudeDir\" -ForegroundColor Green
        Write-Host "     重启 Claude Code 后使用 /secguard, /secaudit, /secreview"
    }

    $ocCommands = Join-Path $Target ".opencode\commands"
    if (Test-Path $ocCommands) {
        Write-Host "  ✓ OpenCode:      $Target\.opencode\ (commands + skills + knowledge + scripts)" -ForegroundColor Green
        Write-Host "     重启 OpenCode 后使用 /secguard, /secaudit, /secreview"
    }

    $gmSkills = Join-Path $Target ".gemini\skills"
    if (Test-Path $gmSkills) {
        Write-Host "  ✓ Gemini CLI:    $Target\.gemini\ (commands + skills + knowledge + scripts)" -ForegroundColor Green
        Write-Host "     在 Gemini CLI 中运行 /skills reload"
    }

    Write-Host ""
    Write-Host "  扫描输出目录: .codeagent\<extension>\scans\<scan-id>\" -ForegroundColor White

    if ($User) {
        Write-Host ""
        Write-Host "  提示: 用户级安装使 SecGuardian 在所有项目中可用。" -ForegroundColor Yellow
        Write-Host "        如果某个项目同时存在项目级安装，项目级优先。" -ForegroundColor Yellow
    }
    Write-Host ""
}

# ── 主流程 ─────────────────────────────────────
$failures = 0

switch ($Platform) {
    "All" {
        if (-not (Install-Claude))   { $failures++ }
        if (-not (Install-OpenCode)) { $failures++ }
        if (-not (Install-Gemini))   { $failures++ }
    }
    "Claude" {
        if (-not (Install-Claude))   { $failures++ }
    }
    "OpenCode" {
        if (-not (Install-OpenCode)) { $failures++ }
    }
    "Gemini" {
        if (-not (Install-Gemini))   { $failures++ }
    }
}

if (-not $DryRun) {
    Invoke-HealthCheck
}

Write-Summary

if ($failures -gt 0) {
    Write-Warn "$failures 个平台安装失败（可能缺少对应的发布包）"
}
