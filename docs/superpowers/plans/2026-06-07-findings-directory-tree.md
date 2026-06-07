# Findings 目录树输出 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 findings 输出从单体 `findings.json` 重构为按 detector 组织的目录树，使 AI Agent 可逐文件读写，消除大项目的 token 爆炸问题。

**Architecture:** `findings/<namespace>/<detector-name>/<finding-id>.json` — 每个 finding 一个独立文件（~2KB），文件名直接使用 finding ID（天然唯一，对齐 SARIF/CodeQL 业界实践），渲染器 `os.walk()` 遍历聚合，向后兼容 v4.0 单体格式。

**Tech Stack:** Python 3 stdlib（json, os, argparse, collections, hashlib），Markdown（命令文档）

**关联 Spec:** [2026-06-07-findings-directory-tree-design.md](../specs/2026-06-07-findings-directory-tree-design.md)

---

### Task 1: 渲染器增加 `--findings-dir` 目录树读取模式

**Files:**
- Modify: `scripts/render-report.py`

这是核心改造。渲染器需要同时支持 `--findings`（v4.0 单体 JSON，向后兼容）和 `--findings-dir`（v5.0 目录树）两种输入模式。

- [ ] **Step 1: 添加 `load_findings_from_tree()` 函数**

在 `load_json()` 函数之后（第 116 行后），插入新函数：

```python
def load_findings_from_tree(findings_dir):
    """Load all finding files from a v5.0 directory tree.
    
    Walks findings/<namespace>/<detector>/<file>.json
    Returns list of finding dicts (same format as v4.0 findings.json['findings']).
    """
    findings = []
    if not os.path.isdir(findings_dir):
        print(f"ERROR: Findings directory not found: {findings_dir}", file=sys.stderr)
        sys.exit(1)
    for root, dirs, files in sorted(os.walk(findings_dir)):
        for fname in sorted(files):
            if fname.endswith('.json'):
                filepath = os.path.join(root, fname)
                try:
                    with open(filepath) as f:
                        data = json.load(f)
                except (json.JSONDecodeError, FileNotFoundError) as e:
                    print(f"WARNING: Skipping invalid finding file {filepath}: {e}", file=sys.stderr)
                    continue
                # Support both wrappers: {"finding": {...}} (v5.0 single) 
                # and bare Finding object (v4.0 inline from monolithic findings.json)
                if isinstance(data, dict) and 'finding' in data:
                    findings.append(data['finding'])
                elif isinstance(data, dict) and 'id' in data:
                    findings.append(data)
                else:
                    print(f"WARNING: Skipping {filepath} — missing 'finding' wrapper or 'id' field", file=sys.stderr)
    return findings
```

- [ ] **Step 2: 添加 `--findings-dir` 参数到 argparse**

找到 `parser.add_argument("--findings", ...)` 那一行（第 674 行附近），在其后添加：

```python
parser.add_argument("--findings-dir", 
                    help="Path to v5.0 findings/ directory tree (overrides --findings)")
```

- [ ] **Step 3: 修改 `main()` 中的数据加载逻辑**

找到 `findings_data = load_json(args.findings)` 这一行（第 687 行附近），替换为：

```python
# Load findings — support v5.0 directory tree or v4.0 monolithic JSON
if args.findings_dir:
    # v5.0: load from directory tree
    findings = load_findings_from_tree(args.findings_dir)
    # Build findings_data dict compatible with existing generators
    findings_data = {
        "schema_version": "1.0",
        "scan_id": "unknown",
        "command": "secguard",
        "started_at": "",
        "completed_at": "",
        "findings": findings,
    }
    # Try to load scan metadata from findings.json (same name as v4.0, now lightweight index only)
    index_path = os.path.join(args.output, "findings.json")
    if os.path.isfile(index_path):
        index_meta = load_json(index_path)
        for key in ["scan_id", "command", "started_at", "completed_at", 
                     "duration_ms", "path", "mode", "filters", "language",
                     "scope", "detectors", "security_score"]:
            if key in index_meta and key not in ("findings_index", "summary"):
                findings_data[key] = index_meta[key]
        # Also merge scope from index_meta if available
        if "scope" in index_meta and (not findings_data.get("scope") or findings_data["scope"].get("files", 0) == 0):
            findings_data["scope"] = index_meta["scope"]
else:
    # v4.0: load monolithic findings.json
    findings_data = load_json(args.findings)
```

- [ ] **Step 4: 更新参数验证逻辑**

找到 `parser.add_argument("--findings", required=True, ...)` 这一行，将 `required=True` 改为 `required=False`，因为有了 `--findings-dir` 作为替代：

```python
parser.add_argument("--findings", required=False, help="Path to findings.json (v4.0 monolithic, legacy)")
```

然后在 `main()` 中加载数据之后添加互斥校验：

```python
# Validate: at least one of --findings or --findings-dir must be provided
if not args.findings and not args.findings_dir:
    print("ERROR: Either --findings (v4.0) or --findings-dir (v5.0) must be provided", file=sys.stderr)
    sys.exit(1)
```

- [ ] **Step 5: 验证向后兼容 — v4.0 单体模式**

```bash
# 用上一次扫描的 findings.json 运行（确认不被破坏）
/usr/bin/python3 scripts/render-report.py \
    --findings examples/python-vuln-demo/.codeagent/secguard-secguardian/scans/sc-20260606-215859-zua2/findings.json \
    --index examples/python-vuln-demo/.codeagent/secguard-secguardian/scans/sc-20260606-215859-zua2/index.json \
    --output /tmp/test-v4-backcompat/
# Expected: 生成 6 个文件，与之前输出一致
diff <(cat examples/python-vuln-demo/.codeagent/secguard-secguardian/scans/sc-20260606-215859-zua2/manifest.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['findings']))") <(cat /tmp/test-v4-backcompat/manifest.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['findings']))")
# Expected: 两边都输出 27
```

- [ ] **Step 6: 验证新功能 — v5.0 目录树模式**

先用之前扫描的数据手工构建一个 findings/ 目录树（模拟 AI 输出），然后验证渲染器能正确读取：

```bash
SCAN_DIR="/tmp/test-v5-demo"
mkdir -p "$SCAN_DIR/findings/web/sql-injection"

# 创建一个 sample finding 文件
cat > "$SCAN_DIR/findings/web/sql-injection/H-SQLI-webapp-L47.json" << 'EOF'
{
  "schema_version": "1.0",
  "finding": {
    "id": "H-SQLI-webapp-L47",
    "severity": "High",
    "cwe": "CWE-89",
    "detector": "web.sql-injection",
    "file": "src/webapp.py",
    "line": 47,
    "function": "get_user",
    "title": "SQL injection via f-string query construction",
    "fix_summary": "Use parameterized queries",
    "location": {
      "file_path": "src/webapp.py",
      "start_line": 46,
      "end_line": 47,
      "function_name": "get_user",
      "snippet": "46: query = f\"SELECT * FROM users WHERE username = '{username}'\"\n47: cursor.execute(query)"
    },
    "evidence": {
      "code_context": "username = request.args.get('username', '')\nquery = f\"SELECT * FROM users WHERE username = '{username}'\"\ncursor.execute(query)",
      "judgment_rationale": "User input interpolated directly into SQL via f-string without parameterization. Matches CWE-89.",
      "data_flow_path": [
        {"step": "source", "file": "src/webapp.py", "line": 41, "description": "request.args.get('username') — user input"},
        {"step": "sink", "file": "src/webapp.py", "line": 47, "description": "cursor.execute(query) — SQL execution"}
      ]
    },
    "impact": {
      "attack_scenario": "Attacker injects SQL via username parameter to bypass auth or exfiltrate data.",
      "cvss_score": 8.6,
      "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N",
      "exploit_conditions": "Public web endpoint, no input sanitization"
    },
    "fix": {
      "description": "Use parameterized queries with placeholders.",
      "before_code": "query = f\"SELECT * FROM users WHERE username = '{username}'\"\ncursor.execute(query)",
      "after_code": "query = \"SELECT * FROM users WHERE username = ?\"\ncursor.execute(query, (username,))",
      "effort_hours": 0.5,
      "verification_method": "Test with SQL injection payloads — should be rejected"
    },
    "sarif_specific": {
      "confidence": "high",
      "risk_of_fix": "low",
      "detector_namespace": "web"
    }
  }
}
EOF

# Create findings.json at scan root — lightweight index, same name as v4.0 but without 4-segment data
cat > "$SCAN_DIR/findings.json" << 'EOF'
{
  "scan_id": "sc-test-v5",
  "command": "secguard",
  "path": "./src",
  "mode": "full",
  "language": "python",
  "timing": {"started": "2026-06-07T12:00:00+08:00", "completed": "2026-06-07T12:01:00+08:00", "duration_ms": 60000},
  "scope": {"files": 3, "lines": 295, "functions": 15, "call_edges": 1},
  "detectors": {"matched": 1, "executed": 1, "namespaces_used": ["web"]},
  "security_score": 90,
  "findings_index": [
    {"id": "H-SQLI-webapp-L47", "severity": "High", "cwe": "CWE-89", "detector": "web.sql-injection", "file": "src/webapp.py", "line": 47, "function": "get_user", "title": "SQL injection via f-string query construction", "path": "findings/web/sql-injection/H-SQLI-webapp-L47.json"}
  ]
}
EOF

# Create dummy index.json for renderer (it needs --index)
echo '{"files":["src/webapp.py"],"symbols":{"functions":[{"name":"get_user","file":"src/webapp.py","start_line":39,"end_line":53}]},"call_graph":{"edges":[]}}' > "$SCAN_DIR/index.json"

# Run renderer in v5.0 mode
/usr/bin/python3 scripts/render-report.py \
    --findings-dir "$SCAN_DIR/findings/" \
    --index "$SCAN_DIR/index.json" \
    --output "$SCAN_DIR/"
# Expected: ✓ report.md ✓ results.sarif ✓ summary.json ✓ manifest.json ✓ status.json ✓ delta.json
```

- [ ] **Step 7: Commit**

```bash
git add scripts/render-report.py
git commit -m "feat(renderer): add --findings-dir for v5.0 directory tree (backward compatible)

- Add load_findings_from_tree() — walks findings/<ns>/<detector>/
- Add --findings-dir CLI argument
- --findings continues to work for v4.0 monolithic JSON
- Single finding file with {'finding': {...}} wrapper supported

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: 更新 findings-schema.json — 增加单文件格式

**Files:**
- Modify: `knowledge/protocols/findings-schema.json`

当前 schema 定义的是单体文件（含顶层 `findings` 数组）。需要增加单 finding 文件的 schema 定义。

- [ ] **Step 1: 在 `findings-schema.json` 顶部增加使用说明**

找到 `"description": "AI-to-Renderer contract..."` 这一行，修改为：

```json
"description": "AI-to-Renderer contract — v5.0 supports both monolithic findings.json and single-finding files in directory tree. See scan-output.md §2 for directory structure.",
```

- [ ] **Step 2: 添加 `SingleFindingFile` schema 到 `$defs`**

在 `$defs` 对象中（`"Finding"` 定义之前），添加：

```json
"SingleFindingFile": {
  "type": "object",
  "description": "v5.0 single-finding file format — one file per finding in findings/<namespace>/<detector>/",
  "required": ["schema_version", "finding"],
  "properties": {
    "schema_version": {
      "type": "string",
      "const": "1.0"
    },
    "finding": {
      "$ref": "#/$defs/Finding"
    }
  }
},
```

- [ ] **Step 3: 添加 `FindingsIndex` schema**

在同一位置添加扫描级索引文件 schema：

```json
"FindingsIndex": {
  "type": "object",
  "description": "v5.0 findings.json — same filename as v4.0, now lightweight index (metadata + finding references only, no 4-segment bodies)",
  "required": ["scan_id", "findings_index"],
  "properties": {
    "scan_id": { "type": "string" },
    "command": { "type": "string" },
    "path": { "type": "string" },
    "mode": { "type": "string" },
    "language": { "type": "string" },
    "timing": {
      "type": "object",
      "properties": {
        "started": { "type": "string", "format": "date-time" },
        "completed": { "type": "string", "format": "date-time" },
        "duration_ms": { "type": "integer" }
      }
    },
    "scope": { "$ref": "#/properties/scope" },
    "detectors": { "$ref": "#/properties/detectors" },
    "security_score": { "$ref": "#/properties/security_score" },
    "findings_index": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "severity", "detector", "file", "line", "path"],
        "properties": {
          "id": { "type": "string" },
          "severity": { "type": "string" },
          "cwe": { "type": "string" },
          "detector": { "type": "string" },
          "file": { "type": "string" },
          "line": { "type": "integer" },
          "function": { "type": "string" },
          "title": { "type": "string" },
          "path": {
            "type": "string",
            "description": "Relative path to single finding file, e.g. findings/web/sql-injection/H-SQLI-webapp-L47.json"
          }
        }
      }
    }
  }
}
```

- [ ] **Step 4: 验证 JSON Schema 语法有效性**

```bash
/usr/bin/python3 -c "import json; json.load(open('knowledge/protocols/findings-schema.json'))" && echo "✅ Valid JSON"
```

- [ ] **Step 5: Commit**

```bash
git add knowledge/protocols/findings-schema.json
git commit -m "feat(schema): add SingleFindingFile and FindingsIndex schemas for v5.0 directory tree

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: 更新 scan-output.md 协议文档

**Files:**
- Modify: `knowledge/protocols/scan-output.md`

- [ ] **Step 1: 在协议版本记录中添加 v5.0 变更**

找到 `> **v4.0 变更 (2026-06-06)**` 这一行（第 22 行），在其上方插入：

```markdown
> **v5.0 变更 (2026-06-07)**: 单体 findings.json 重构为按 detector 组织的目录树（`findings/<namespace>/<detector>/<finding-id>.json`，文件名 = finding ID，天然唯一）。每个 finding 独立文件（~2KB），AI Agent 可按需读取。`findings.json` 同名升级：从"单体四段式"变为"轻量索引+元数据"，四段式数据拆入 `findings/` 目录树。渲染器通过 `--findings-dir` 读取目录树，`--findings` 保持 v4.0 兼容。参见: [2026-06-07-findings-directory-tree-design.md](../../docs/superpowers/specs/2026-06-07-findings-directory-tree-design.md)
```

- [ ] **Step 2: 更新目录结构章节**

找到当前目录结构图（第 26-35 行的代码块），替换为：

```markdown
## 目录结构 (v5.0)

```
.codeagent/<extension-name>/scans/<scan-id>/
├── index.json                  # 索引器输出：符号表+调用图+文件清单（Step 2，只读）
├── findings.json               # ★ 同名升级：v4.0 单体→v5.0 轻量索引（不含四段式，<50KB）
├── findings/                   # ★ v5.0: finding 目录树（四段式数据按 detector 分文件存放）
│   ├── web/
│   │   ├── sql-injection/
│   │   │   ├── H-SQLI-webapp-L47.json      # 完整四段式 finding（~2KB），文件名 = finding ID
│   │   │   └── M-IDOR-webapp-L100.json
│   │   ├── ssrf/
│   │   │   └── ...
│   │   └── ...
│   ├── crypto/
│   │   └── ...
│   ├── system/
│   │   └── ...
│   └── error/
│       └── ...
├── report.md                  # ★ 渲染器生成：人读审计报告
├── results.sarif              # 机读：SARIF 2.1.0
├── summary.json               # 仪表盘统计
├── manifest.json              # 扫描元数据 + 检出索引
├── status.json                # CI 门禁
├── delta.json                 # 增量对比
└── latest → <scan-id>/        # 符号链接 → 最新扫描
```

### 文件命名规范

```
<finding-id>.json
```

文件名直接使用 finding ID（格式: `<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>`），利用其天然唯一性：

| 组成部分 | 说明 | 示例 |
|---------|------|------|
| `SEVERITY` | C/H/M/L/I | `H` |
| `DETECTOR_ABBREV` | 3-5 字符缩写 | `SQLI` |
| `FILE_SLUG` | 文件名去扩展名，特殊字符 → `_` | `webapp` |
| `L<LINE>` | 行号 | `L47` |
| 完整文件名 | — | `H-SQLI-webapp-L47.json` |

**不会碰撞**：同一行代码不会被同一 detector 重复报告。对齐 SARIF (partialFingerprints)、CodeQL (file-hash)、Semgrep (finding-hash) 的 ID-as-key 模式。
```

- [ ] **Step 3: 添加 v4.0 兼容说明**

在目录结构之后添加：

```markdown
### v4.0 兼容模式（遗留）

v4.0 单体格式仍被支持（`--findings` flag），但不推荐用于新扫描：

```
findings.json               # v4.0: 单体文件（所有 finding 内联，生产环境会超大）
```

渲染器通过 `--findings` 读取 v4.0 格式，`--findings-dir` 读取 v5.0 目录树。
```

- [ ] **Step 4: 更新用户使用流程表**

找到 "用户使用流程" 表格（第 42-53 行），替换为：

```markdown
## 用户使用流程

| 我想做什么 | 操作 |
|-----------|------|
| **看全局摘要** | 打开 `findings.json` — 统计 + 检出 ID/严重度/文件/行号映射 |
| **按漏洞类型审查** | 进入 `findings/web/sql-injection/` — 查看所有 SQL 注入 |
| **看某个具体漏洞** | 打开 `findings/web/sql-injection/H-SQLI-webapp-L47.json` — 完整四段式 |
| **给团队分工** | "小王负责 `findings/crypto/`，小李负责 `findings/web/`" |
| **AI 批量修复** | 告诉 AI："读取 `findings/crypto/`，按 fix.after_code 修改源码" |
| **★ 看完整审计报告（商业交付）** | 打开 `report.md` — 六章专业审计报告 |
| **CI/CD 集成** | 消费 `results.sarif` — GitHub Code Scanning / GitLab SAST |
```

- [ ] **Step 5: Commit**

```bash
git add knowledge/protocols/scan-output.md
git commit -m "docs(protocol): update scan-output.md for v5.0 findings directory tree

- Add v5.0 directory structure with findings/<ns>/<detector>/ layout
- Document file naming convention (finding ID as filename, no collision)
- Update user workflow table for directory-tree navigation
- Add v4.0 backward compatibility note
- Clarify v5.0 findings.json evolution: monolithic → lightweight index

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: 更新 secguard.md 命令 — Step 4 改为逐文件输出

**Files:**
- Modify: `commands/secguard.md`

- [ ] **Step 1: 修改 Step 4 标题和关键变更说明**

找到 `### Step 4: 输出结构化 findings（遵循 Findings Protocol v1.0）`（第 256 行）及其下方的关键变更说明（第 258 行），替换为：

```markdown
### Step 4: 输出结构化 findings（遵循 Findings Protocol v5.0）

> ⚠️ **v5.0 关键变更**: AI **不再输出单体 findings.json**。改为按 detector 分类，**每个 finding 输出一个独立文件**到 `findings/` 目录树下。渲染器通过 `--findings-dir` 聚合所有 finding 文件生成报告。**禁止直接写 report.md / results.sarif / 任何其他输出文件** — 这些由渲染器生成。
```

- [ ] **Step 2: 重写 4a 为逐文件输出流程**

将当前 4a 到 4c 的内容（第 260-310 行）替换为：

```markdown
**4a. 按 detector 分组，以 finding ID 为文件名逐文件输出（每个文件 2-4KB）：**

每个 finding 写入独立文件，路径格式：
```
findings/<namespace>/<detector-name>/<finding-id>.json
```

**文件命名规则：直接使用 finding ID（业界最佳实践，对齐 SARIF/CodeQL/Semgrep）：**

finding ID 格式: `<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>`

| 组成部分 | 说明 | 唯一性 |
|---------|------|--------|
| `SEVERITY` | C/H/M/L/I | 同一行不同 detector = 不同 ID |
| `DETECTOR_ABBREV` | 3-5 字符缩写（SQLI, SSRF, CRYPTO...） | 不同 detector 不碰撞 |
| `FILE_SLUG` | 文件名去扩展名，特殊字符 → `_` | 不同文件不碰撞 |
| `L<LINE>` | 行号（L 前缀 + 数字） | 同行同 detector 只产一个 finding |

**为什么不会碰撞？** 同一行代码不会被同一 detector 重复报告。finding ID 天然保证全局唯一。

示例：
```
findings/web/sql-injection/H-SQLI-webapp-L47.json
findings/crypto/password-storage/H-CRYPTO-crypto_utils-L20.json
findings/resource/resource-exhaustion/L-DOS-webapp-L184.json   ← 同函数不同行，ID 不同，不碰撞
findings/resource/resource-exhaustion/L-DOS-webapp-L186.json   ← 同上
```

**单文件格式（遵循 `findings-schema.json` 中 `SingleFindingFile` schema）：**
```json
{
  "schema_version": "1.0",
  "finding": {
    "id": "H-SQLI-webapp-L47",
    "severity": "High",
    "cwe": "CWE-89",
    "detector": "web.sql-injection",
    "file": "src/webapp.py",
    "line": 47,
    "function": "get_user",
    "title": "SQL injection via f-string query construction",
    "fix_summary": "使用参数化查询替代 f-string 拼接",
    "location": { ... },
    "evidence": { ... },
    "impact": { ... },
    "fix": { ... },
    "sarif_specific": { ... }
  }
}
```

**Critical 优先输出**：按 Critical → High → Medium → Low 顺序输出，确保用户最关心的问题先落盘。

**4b. 输出轻量 `findings.json`（同名升级，不含四段式）：**

所有 finding 输出完毕后，写入索引文件：

```json
{
  "scan_id": "<scan-id>",
  "command": "secguard",
  "path": "./src",
  "mode": "full",
  "language": "python",
  "timing": { "started": "<iso>", "completed": "<iso>", "duration_ms": 76000 },
  "scope": { "files": 3, "lines": 295, "functions": 15, "call_edges": 1 },
  "detectors": { "matched": 27, "executed": 27, "namespaces_used": [...] },
  "security_score": 0,
  "findings_index": [
    {
      "id": "H-SQLI-webapp-L47",
      "severity": "High",
      "cwe": "CWE-89",
      "detector": "web.sql-injection",
      "file": "src/webapp.py",
      "line": 47,
      "function": "get_user",
      "title": "SQL injection via f-string query construction",
      "path": "findings/web/sql-injection/H-SQLI-webapp-L47.json"
    }
  ]
}
```

> 索引文件不含四段式详情，仅含导航字段。企业级项目（1000+ finding）索引约 300KB，AI Agent 可直接读取。

**4c. 自检完整性（必须执行）：**

在写入所有文件后，执行以下脚本校验：

```bash
SCAN_DIR=".codeagent/secguard-secguardian/scans/<scan_id>"
python3 << 'PYEOF'
import json, os, sys

index_path = os.path.join(os.environ['SCAN_DIR'], 'findings.json')
with open(index_path) as f:
    idx = json.load(f)

expected = len(idx['findings_index'])
actual = 0
missing = []

for entry in idx['findings_index']:
    fpath = os.path.join(os.environ['SCAN_DIR'], entry['path'])
    if os.path.isfile(fpath):
        # Verify four-segment completeness
        with open(fpath) as f:
            data = json.load(f)
        finding = data.get('finding', data)
        loc = finding.get('location', {})
        ev = finding.get('evidence', {})
        imp = finding.get('impact', {})
        fix = finding.get('fix', {})
        
        incomplete = []
        if not loc.get('file_path'): incomplete.append('location.file_path')
        if not loc.get('snippet'): incomplete.append('location.snippet')
        if not ev.get('judgment_rationale'): incomplete.append('evidence.judgment_rationale')
        if not imp.get('attack_scenario'): incomplete.append('impact.attack_scenario')
        if not fix.get('before_code'): incomplete.append('fix.before_code')
        if not fix.get('after_code'): incomplete.append('fix.after_code')
        
        if incomplete:
            missing.append(f"{entry['id']}: missing {', '.join(incomplete)}")
        else:
            actual += 1
    else:
        missing.append(f"{entry['id']}: file not found at {entry['path']}")

if missing:
    print(f"❌ {len(missing)} findings incomplete/missing:")
    for m in missing: print(f"  - {m}")
    sys.exit(1)
else:
    print(f"✅ All {actual}/{expected} findings present and complete")
PYEOF
```

**任一 ❌ → 补充缺失文件/内容 → 重新检查，最多 3 次。** 3 次后仍未通过 → 在 `findings.json` 顶层添加 `"quality_gate_warning": ["<不完整的 finding ID>"]`，渲染器会在 report.md 中标记。

**4d. 调用渲染器生成所有输出：**

```bash
# 定位渲染器
RENDERER=""
for base in "." "$HOME"; do
    for path in \
        ".opencode/extensions/secguardian/scripts/render-report.py" \
        ".config/opencode/extensions/secguardian/scripts/render-report.py" \
        ".gemini/extensions/secguardian/scripts/render-report.py" \
        ".claude/plugins/secguardian/scripts/render-report.py"; do
        candidate="$base/$path"
        [ -f "$candidate" ] && RENDERER="$candidate" && break 3
    done
done
[ -z "$RENDERER" ] && [ -f "scripts/render-report.py" ] && RENDERER="scripts/render-report.py"

python3 "$RENDERER" \
    --findings-dir .codeagent/secguard-secguardian/scans/<scan_id>/findings/ \
    --index .codeagent/secguard-secguardian/scans/<scan_id>/index.json \
    --output .codeagent/secguard-secguardian/scans/<scan_id>/
```

渲染器自动生成: `report.md` + `results.sarif` + `summary.json` + `manifest.json` + `status.json` + `delta.json`。

> ⚠️ 如果渲染器不存在或执行失败，打印警告：`"Renderer unavailable — findings saved to findings/ directory tree only. Run: python3 scripts/render-report.py --findings-dir <path>/findings/ --index <path>/index.json --output <path>/"`
```

- [ ] **Step 3: 更新 Step 1 输出目录说明**

在 Step 1 的输出目录创建代码之后，增加 `findings/` 目录的创建：

在 Step 1 的 `mkdir -p ".codeagent/secguard-secguardian/scans/$SCAN_ID"` 之后添加：

```
同时预创建 findings 基础目录：`.codeagent/secguard-secguardian/scans/<scan_id>/findings/`
```

- [ ] **Step 4: Commit**

```bash
git add commands/secguard.md
git commit -m "feat(secguard): rewrite Step 4 for v5.0 per-finding file output

- Replace monolithic findings.json with findings/<ns>/<detector>/<finding-id>.json tree
- Finding ID as filename — naturally unique, aligned with SARIF/CodeQL/Semgrep
- Add v5.0 findings.json — same filename, upgraded to lightweight index + metadata only
- Add 4c file-level completeness self-check script
- Renderer called with --findings-dir instead of --findings

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: 同步更新 secaudit.md 和 secreview.md

**Files:**
- Modify: `commands/secaudit.md`
- Modify: `commands/secreview.md`

这两个命令的 Step 4 结构与 secguard.md 相同，做相同的替换。

- [ ] **Step 1: 在 secaudit.md 中找到 Step 4 相关段落，做与 Task 4 相同的替换**

```bash
# 定位 secaudit.md 中 Step 4 的位置
grep -n "Step 4\|4a\|4b\|4c\|findings.json\|--findings" commands/secaudit.md
```

预期找到类似的结构（具体行号可能不同，需要按实际情况修改）。将 Step 4 的 4a/4b/4c 部分替换为与 Task 4 Step 2 相同的内容（仅将 `"command": "secguard"` 改为 `"command": "secaudit"`，scan 输出路径改为 `secaudit-secguardian`）。

如果 secaudit.md 的 Step 4 对 secguard.md 有引用（如"参考 secguard 的 Step 4"），则只需更新引用说明即可。

- [ ] **Step 2: 在 secreview.md 中做相同的替换**

```bash
grep -n "Step 4\|4a\|4b\|4c\|findings.json\|--findings" commands/secreview.md
```

同样的替换，`"command"` 值改为 `"secreview"`，路径改为 `secreview-secguardian`。

- [ ] **Step 3: Commit**

```bash
git add commands/secaudit.md commands/secreview.md
git commit -m "feat(secaudit,secreview): sync Step 4 to v5.0 per-finding file output

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: 端到端验证

**Files:**
- Test target: `examples/python-vuln-demo/`

用 python-vuln-demo 完整跑一次扫描，验证目录树输出 + 渲染器生成的报告与 v4.0 一致。

- [ ] **Step 1: 执行一次完整扫描（使用新命令格式）**

在终端中执行 `/secguardian:secguard ./src *` — 这应该按新流程输出 findings/ 目录树。

- [ ] **Step 2: 验证目录树结构**

```bash
SCAN_DIR=$(readlink -f examples/python-vuln-demo/.codeagent/secguard-secguardian/scans/latest)
echo "Scan dir: $SCAN_DIR"

# 验证 findings/ 目录存在
[ -d "$SCAN_DIR/findings" ] && echo "✅ findings/ exists" || echo "❌ missing findings/"

# 验证按 detector 分类
echo "Detector directories:"
find "$SCAN_DIR/findings" -type d | sort

# 验证 finding 文件数量（findings/ 下只有 finding 文件，无需过滤）
FINDING_COUNT=$(find "$SCAN_DIR/findings" -name "*.json" | wc -l | tr -d ' ')
echo "Finding files: $FINDING_COUNT"

# 验证 findings.json 存在（scan root，不在 findings/ 内）
[ -f "$SCAN_DIR/findings.json" ] && echo "✅ findings.json exists" || echo "❌ missing findings.json"
```

- [ ] **Step 3: 验证每个 finding 文件四段式完整性**

```bash
SCAN_DIR=$(readlink -f examples/python-vuln-demo/.codeagent/secguard-secguardian/scans/latest)
python3 -c "
import json, os, sys

findings_dir = os.path.join('$SCAN_DIR', 'findings')
issues = []
count = 0
for root, dirs, files in os.walk(findings_dir):
    for fname in files:
        if not fname.endswith('.json'):
            continue
        fpath = os.path.join(root, fname)
        with open(fpath) as f:
            data = json.load(f)
        finding = data.get('finding', data)
        
        # Check four-segment
        loc = finding.get('location', {})
        ev = finding.get('evidence', {})
        imp = finding.get('impact', {})
        fix = finding.get('fix', {})
        
        missing = []
        if not loc.get('file_path'): missing.append('location.file_path')
        if not loc.get('snippet'): missing.append('location.snippet')
        if not ev.get('judgment_rationale'): missing.append('evidence.judgment_rationale')
        if not imp.get('attack_scenario'): missing.append('impact.attack_scenario')
        if not fix.get('before_code'): missing.append('fix.before_code')
        if not fix.get('after_code'): missing.append('fix.after_code')
        
        if missing:
            issues.append(f'{fname}: missing {missing}')
        count += 1

if issues:
    print(f'❌ {len(issues)} incomplete:')
    for i in issues: print(f'  - {i}')
    sys.exit(1)
else:
    print(f'✅ All {count} finding files pass 4-segment check')
"
```

- [ ] **Step 4: 验证渲染器输出文件齐全**

```bash
SCAN_DIR=$(readlink -f examples/python-vuln-demo/.codeagent/secguard-secguardian/scans/latest)
for f in report.md results.sarif summary.json manifest.json status.json delta.json; do
    [ -f "$SCAN_DIR/$f" ] && echo "✅ $f" || echo "❌ MISSING $f"
done
```

- [ ] **Step 5: 对比新旧格式 manifest.json**

确认 finding 数量和 ID 一致：

```bash
# 旧格式
python3 -c "import json; d=json.load(open('examples/python-vuln-demo/.codeagent/secguard-secguardian/scans/sc-20260606-215859-zua2/manifest.json')); print('v4.0 findings:', len(d['findings'])); [print(f['id']) for f in sorted(d['findings'], key=lambda x: x['id'])]" > /tmp/v4_ids.txt

# 新格式  
SCAN_DIR=$(readlink -f examples/python-vuln-demo/.codeagent/secguard-secguardian/scans/latest)
python3 -c "import json; d=json.load(open('$SCAN_DIR/manifest.json')); print('v5.0 findings:', len(d['findings'])); [print(f['id']) for f in sorted(d['findings'], key=lambda x: x['id'])]" > /tmp/v5_ids.txt

diff /tmp/v4_ids.txt /tmp/v5_ids.txt && echo "✅ Finding IDs match between v4.0 and v5.0" || echo "⚠️ Differences found (may be expected if scan changed)"
```

- [ ] **Step 6: 验证单个 finding 文件可被 AI 按需读取**

```bash
SCAN_DIR=$(readlink -f examples/python-vuln-demo/.codeagent/secguard-secguardian/scans/latest)
# 随机选一个 finding 文件
SAMPLE=$(find "$SCAN_DIR/findings" -name "*.json" | head -1)
echo "Sample: $SAMPLE"
echo "Size: $(wc -c < "$SAMPLE") bytes"
# 验证 JSON 有效
python3 -c "import json; d=json.load(open('$SAMPLE')); print('ID:', d['finding']['id']); print('Has location:', bool(d['finding'].get('location'))); print('Has fix:', bool(d['finding'].get('fix')))" && echo "✅ AI-readable single finding file"
```

- [ ] **Step 7: 清理并 Commit（如有修改）**

```bash
git status
# 如果有 self-check 等验证脚本的修改，一并提交
git add -A && git diff --cached --stat
```

---

### Task 7: 更新设计日志

**Files:**
- Modify: `docs/design-journal.md`

- [ ] **Step 1: 在文件顶部（第一个日期标题之前）插入 v5.0 决策记录**

找到第一个 `## 2026-06-` 开头的标题，在其上方插入新的决策条目。

```bash
# 找到设计日志中第一个日期标题的行号
grep -n "^## 2026-06-03" docs/design-journal.md
```

在第一个日期标题之前插入：

```markdown
## 2026-06-07 — Findings 输出架构重构：单体 JSON → 目录树

### 背景

v4.0 单体 `findings.json` 在 3 文件 295 行 demo 扫描中产出 50KB JSON，耗时 ~9 分钟。1000 文件项目预估 25MB JSON，AI Agent 无法读取。用户明确指出："级别低不代表不是问题，所有检出的问题都要用户认可去修正"，不应按 severity 暗示某些问题不重要。

### 讨论要点

- **核心矛盾**：AI 单次 Write 50KB 可行，但后续读取 25MB JSON 直接爆 token
- **用户方案**：findings/ 下按 detector 分类，文件名直接使用 finding ID（天然唯一，避免碰撞）
- **不按 severity 重复输出**：避免"低严重度=不重要"的暗示，保持每个 finding 的严肃性
- **向后兼容**：渲染器同时支持 `--findings`（v4.0）和 `--findings-dir`（v5.0）

### 最终方案

`findings/<namespace>/<detector-name>/<finding-id>.json` 目录树（文件名 = finding ID）：
- 每个 finding 一个独立文件（~2KB），自包含完整四段式
- `findings.json`（<50KB）同名升级：v4.0 单体四段式 → v5.0 轻量索引 + 元数据
- 渲染器 `os.walk()` 遍历聚合，输出逻辑不变
- 按 detector 分类方便团队分工和按漏洞类型审查

### 影响范围

- `scripts/render-report.py` — `--findings-dir` + `load_findings_from_tree()`
- `knowledge/protocols/scan-output.md` — 目录结构 + naming convention
- `knowledge/protocols/findings-schema.json` — SingleFindingFile + FindingsIndex
- `commands/secguard.md` — Step 4 逐文件输出流程
- `commands/secaudit.md`, `commands/secreview.md` — 同步更新

详见: [2026-06-07-findings-directory-tree-design.md](superpowers/specs/2026-06-07-findings-directory-tree-design.md)

---
```

- [ ] **Step 2: Commit**

```bash
git add docs/design-journal.md
git commit -m "docs(design): record v5.0 findings directory tree design decision

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## 验证检查清单

实施完成后，按以下清单逐项验证：

- [ ] `--findings` (v4.0) 模式仍能正常运行旧扫描结果
- [ ] `--findings-dir` (v5.0) 模式正确遍历目录树并聚合所有 finding
- [ ] 生成的 report.md / SARIF / summary / manifest / status / delta 与 v4.0 内容一致
- [ ] 单个 finding 文件 < 5KB，可被 AI 一次性读取
- [ ] `findings.json` 条目数与 findings/ 目录下 finding 文件数一致
- [ ] finding ID 即文件名，天然无冲突（无需 `__N` 去重）
- [ ] 自检完整性脚本通过（所有 finding 四段式完整）
- [ ] `self-check.sh` 通过（10 秒内）

---

*关联文档: [2026-06-07-findings-directory-tree-design.md](../specs/2026-06-07-findings-directory-tree-design.md), [design-journal](../../design-journal.md)*
