---
name: secfix
description: "AI Remediation — generate ready-to-apply patches from findings (MVP: scripts/secfix.py)"
---

# /secfix - AI Remediation

Generate unified diff patches from findings produced by `/secreview`, `/secguard`, or `/secaudit`.

Designed for developers who know a fix needs to be applied but would rather review a patch than write one.

## Usage

```
# ★ 零参数缺省调用（推荐）
/secfix                                              # 自动发现最近扫描结果，生成 patches

# 指定扫描结果目录
/secfix --findings-dir .codeagent/secreview-*/scans/<id>/findings/

# 指定 scan ID
/secfix --scan-id pr-20260630-143000-a1b2
```

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

## Output

```
<output>/
├── index.json                  <- Patch manifest
├── <detector>/
│   ├── <sha12>_<file>-<line>.patch      <- unified diff
│   └── <sha12>_<file>-<line>.patch.meta  <- metadata
└── ...
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
-cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
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
  "patch_file": "<output>/web.sql-injection/<SHA>_main-42.patch"
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
