---
name: secfix
description: "[Claude Code] AI Remediation — generate unified diff patches from findings"
platform: claude
---

# /secfix - AI Remediation

## ⚙️ Command Layer


Generate unified diff patches from findings produced by `/secreview`, `/secguard`, or `/secaudit`.

Designed for developers who know a fix needs to be applied but would rather review a patch than write one.

## Usage: 告诉 /secfix 修哪个扫描的结果

```
# ★ 默认：自动选最新的扫描结果
/secfix                                              # 遍历所有命令的 latest/，选最新的生成 patches

# 指定命令的最近一次扫描
/secfix secaudit                                     # 用 secaudit 的最新扫描
/secfix secreview                                    # 用 secreview 的最新扫描
/secfix secguard                                     # 用 secguard 的最新扫描

# 精确指定某次扫描的 findings 目录
/secfix .codeagent/secguardian/secguard/scans/sec-20260701-120000-abcd/findings/
```

### 扫描来源选择逻辑

| 参数 | 行为 |
|------|------|
| 无参数 | 遍历 `.codeagent/*/scans/` 下所有命令的 `latest/` 符号链接，选时间戳最新的一条 |
| `secaudit` / `secreview` / `secguard` | 只在该命令的 `latest/` 下找 |
| 路径 | 精确指定 findings 目录，跳过自动发现 |

扫描完成后 AI 会自动创建 `latest → <scan-id>/` 符号链接，所以无参数调用总是使用最近执行的那一次扫描——不论是 secguard、secreview 还是 secaudit。


## 🛠️ Engine Layer

> secfix 的修复建议生成遵循 Investigation Engine 模式：读取 finding 证据链 → 分析修复模式 → 生成 patch 文件。
> 详见 `secguard.md §Phase 2` 的 Investigation Pipeline 执行协议。

### 🔒 跨 Shell 状态传递

> **每个 bash 调用都是独立 shell，变量不共享。禁止用 `/tmp/` 传状态。**

secfix 读取已有扫描结果生成 patch。定位扫描目录时使用 `latest` 符号链接：
```bash
# 查找最新扫描（无参数时）
ls -td .codeagent/secguardian/*/scans/*/findings/ 2>/dev/null | head -1
```
需要持久化状态时，使用命令对应的 `.scan_state.secguard` / `.scan_state.secreview` / `.scan_state.secaudit`。
禁止使用 `/tmp/` 或系统临时目录。

## How It Works

```
Findings with fix.before_code/after_code
    |
    v
scripts/secfix.py                   <- Python script, no AI inference needed
    |
    v
Unified diff patches (.patch)
    + metadata (.patch.meta)
    + manifest (index.json)
    |
    v
Developer reviews:  git diff / cat *.patch
Developer applies:  git apply *.patch
```

## 📄 Output Layer

> 以下输出格式遵循 `internal/output/output_contract.md`。

## Output

Patches are written to a `fixes/` subdirectory alongside the scan findings:

```
.codeagent/<source-ext>/scans/<scan-id>/
└── fixes/
    ├── index.json                  <- Patch manifest
    └── <detector>/
        ├── <sha>_<file>-<line>.patch      <- unified diff
        └── <sha>_<file>-<line>.patch.meta  <- metadata
```

### Patch Format

Each `.patch` file is a standard unified diff:

```diff
# web.sql-injection
# Severity: High  |  CWE: CWE-089
# File: src/main.py:42
# Source scan: pr-20260630-143000-a1b2
# Description: Use parameterized query
#
# Apply: git apply <SHA>_main-42.patch
--- a/src/main.py
+++ b/src/main.py
@@ -1 +1 @@
-cursor.execute(f"SELECT * FROM users WHERE id = USER_INPUT")
+cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
```

### Metadata Format

Each `.patch.meta` file contains traceability info:

```json
{
  "source_file": ".../findings/web/sql-injection/...json",
  "detector": "web.sql-injection",
  "severity": "High",
  "cwe": "CWE-089",
  "file": "src/main.py",
  "line": 42,
  "description": "Use parameterized query",
  "patch_file": "fixes/web.sql-injection/<SHA>_main-42.patch"
}
```

## Workflow

1. **Detect**: `/secreview ./src cpp git diff` — finds 3 issues
2. **Fix**: `/secfix .codeagent/secreview-*/scans/<scan-id>/findings/` — generates 3 patches
3. **Review**: `cat .codeagent/secreview-*/scans/<scan-id>/fixes/<detector>/*.patch`
4. **Apply**: `git apply .codeagent/secreview-*/scans/<scan-id>/fixes/<detector>/*.patch`
5. **Verify**: `/secreview ./src cpp git diff` — re-run to confirm

## Key Principles

- **Decision stays with the developer.** secfix generates patches, it does not apply them.
- **Every patch is traceable.** Each .patch.meta links back to the source finding scan ID.
- **Re-run is required.** The gate is not clear until `/secreview` passes on the fixed code.
- **Zero AI inference.** secfix.py is a pure Python transformation — no model calls, instant execution.

## Implementation

- **Script**: `scripts/secfix.py`
- **Runtime**: Python 3 (no dependencies beyond stdlib)
- **Source resolution**: reads `SOURCE_ROOT` env var (default: cwd) to find target files
- **Output format**: unified diff (compatible with `git apply`)

## Workflow Integration

```
/secreview                    /secfix
    |                            |
    v                            v
findings/*.json   -------->   patches/*.patch
                               patches/*.patch.meta
                               patches/index.json
    |                            |
    v                            v
  review                      git apply
