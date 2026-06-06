---
name: secaudit
description: "★ 旗舰产品：AI 深度安全审计 — 17 项专业安全分析，替代传统安全顾问"
---

# /secaudit - 安全专项审计

针对安全专项问题进行深度审计分析。自动识别用户意图，路由到对应的分析或领域审计 skill。

## 使用方式

```
## ★ 旗舰产品

SecAudit 是 SecGuardian 的旗舰产品——AI 深度安全审计。它替代传统安全顾问执行 17 项专业安全分析，每项分析需要资深工程师 4-8 小时。AI 在数秒内完成同等深度的审计，帮助企业年省 $50K+ 安全审计费用。

## 使用方式

```
/secaudit                                    # 列出所有 17 个 skills
/secaudit taint-analysis                     # 污点分析 — 追踪不可信数据到危险操作
/secaudit auth-and-session                   # 认证与会话管理审计
/secaudit cryptography                       # 密码学完整审计
/secaudit input-validation                   # 输入验证深度审计
/secaudit attack-surface-analysis            # 攻击面枚举
/secaudit analysis                           # 列出 5 个分析方法类 skills
/secaudit domain                             # 列出 12 个安全领域类 skills
/secaudit <skill-name> [path]                # 指定审计代码路径
/secaudit <skill-name> [path] --sarif        # 输出 SARIF 格式（CI/CD 集成）
```

## 输出

遵循 [Scan Output Protocol 3.0](../knowledge/protocols/scan-output.md)。人读/机读分离。

```
.codeagent/secaudit-secguardian/scans/<scan-id>/
├── report.md               # ★ 人读审计报告 (Markdown)
├── results.sarif            # 机读: SARIF 2.1.0 (CI/CD)
├── summary.json             # 仪表盘统计
├── manifest.json            # 审计元数据 + 发现索引
├── status.json              # CI 门禁
└── delta.json               # 增量对比 (vs 上次扫描)
```

**执行完毕后必须输出审计摘要：**

```
## secaudit 审计完成 — taint-analysis

Scan ID: sec-20260523-143000-b3c4
Skill: secaudit-taint-analysis

### 结果
- 分析路径: 15 (Source → Propagation → Sink)
- 完整链路: 15 analyzed
- 检出: 4 (Critical: 2, High: 2)

### 发现
| ID | Severity | Path | File |
|----|----------|------|------|
| C-001 | Critical | HTTP param → SQL exec | src/handler.py:42 |
| C-002 | Critical | File upload → os.system | src/upload.py:108 |
| H-001 | High | Cookie → response.write | src/middleware.js:56 |

输出目录: .codeagent/secaudit-secguardian/scans/sec-20260523-143000-b3c4/

💡 **如何使用审计结果？**
- **快速看汇总** → 打开 `manifest.json`
- **★ 人读审计报告** → 打开 `report.md`（每个发现含完整四段式：📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）
- **CI/CD 集成** → 消费 `results.sarif`
- **AI Agent 修复** → 告诉 AI：`读取 report.md §4，按每个发现的 🔧 Fix 方案修改代码`
```

## 可用 Skills

### analysis - 安全分析方法 (5 个)
| Skill | 描述 |
|-------|------|
| attack-surface-analysis | 分析攻击面，识别暴露入口点和接口 |
| data-flow-analysis | 追踪数据从 Source 到 Sink 的完整数据流 |
| state-machine-analysis | 分析状态转换，检测非法跃迁路径 |
| taint-analysis | 标记污点数据源，追踪传播链 |
| trust-boundary-analysis | 识别信任边界，检查跨边界控制 |

### domain - 安全领域审计 (12 个)
| Skill | 描述 |
|-------|------|
| auth-and-session | 认证机制和会话生命周期审计 |
| authorization | 权限模型审计，检测越权 |
| cryptography | 加密实现审计，检测弱算法 |
| data-protection | 敏感数据存储/传输/处理保护 |
| dependency-security | 依赖的已知漏洞和供应链审计 |
| http-security-headers | HTTP 安全头配置审计 |
| infra-hardening | 容器/K8s/云资源加固审计 |
| input-validation | 输入验证和注入漏洞审计 |
| logging-and-monitoring | 日志完整性和安全监控审计 |
| output-encoding | 输出编码和 XSS 防护审计 |
| secrets-management | 密钥/凭证管理方式审计 |
| secure-transport | TLS 配置和传输层安全审计 |

## 派发规则与执行步骤

> **隔离约束**: 本命令只能加载 `skills/` 扩展下的 `secaudit-*` 前缀 skill，禁止加载 `secguard-*` 或 `secreview-*` 前缀的任何文件。审计技能仅从 `skills/secaudit/{name}/SKILL.md` 路由。

你（AI Agent）在接收到 `/secaudit` 命令后，必须按以下步骤执行来构建索引并进行安全审计。

### 前置检查（Pre-flight Checklist）

在执行任何审计步骤之前，必须逐项确认以下所有条件。**任一项未通过，审计不得开始，向用户报告具体错误。**

- [ ] 定位索引器 wrapper：检查 `.opencode/extensions/secguardian/`（项目级）→ `~/.config/opencode/extensions/secguardian/`（用户级）→ `.gemini/` → `.claude/` → `scripts/` 回退（至少一个存在且可执行）
- [ ] 执行 `{indexer} --health` 通过（输出必须包含 `HEALTH:OK` 或 `HEALTH:WARN`，不接受 `HEALTH:FAIL`）
- [ ] 目标路径 `<path>` 存在且包含至少一个源码文件
- [ ] 确认不会启动 clangd/LSP/compile_commands.json/bear 等外部工具 — indexer (tree-sitter) 已提供符号表+调用图+文件清单，所有代码结构数据从 index.json 获取

> 若未通过，报告具体哪一项失败并终止。不要降级为手工逐文件审计。

---

### Step 1: 建立输出目录

- 生成 `scan_id`（格式: `sec-YYYYMMDD-HHMMSS-xxxx`，其中 `xxxx` 为随机4位字符）。
- 创建输出目录: `.codeagent/secaudit-secguardian/scans/<scan_id>/`。
- 记录审计开始时间戳，用于 Step 4 计算 `duration_ms`。

### Step 2: 构建语义索引（必须执行，不可跳过）

> ⚠️ 这是审计的**核心前置步骤**。索引器提供符号表、调用图、数据流路径，是后续深度审计的结构化上下文。**不执行此步骤将导致审计质量严重下降。**

**2a. 执行索引器（阻塞等待完成）：**

```bash
# 定位 indexer wrapper — 项目级 + 用户级全覆盖
find_indexer() {
    INDEXER=""
    for base in "." "$HOME"; do
        for path in \
            ".opencode/extensions/secguardian/scripts/secguardian-index" \
            ".config/opencode/extensions/secguardian/scripts/secguardian-index" \
            ".gemini/extensions/secguardian/scripts/secguardian-index" \
            ".claude/plugins/secguardian/scripts/secguardian-index"; do
            candidate="$base/$path"
            [ -x "$candidate" ] && [ -f "$candidate" ] && INDEXER="$candidate" && break 3
        done
    done
    for candidate in scripts/secguardian-index internal/secguardian-index; do
        [ -x "$candidate" ] && [ -f "$candidate" ] && INDEXER="$candidate" && break
    done
    [ -z "$INDEXER" ] && echo "FATAL: secguardian-index not found (checked project + user paths)" && exit 1
    echo "Using: $INDEXER"
}
find_indexer
$INDEXER --path <path> --output .codeagent/secaudit-secguardian/scans/<scan_id>/index.json
```

**2b. 验证索引完整性 + 生成结构化摘要（必须通过）：**

执行以下脚本。若返回非 0，**立即终止审计**并向用户报告索引生成出错。
若成功，直接读取输出的 JSON 摘要作为后续所有步骤的上下文，**禁止自己写 Python 去探测索引结构**。

```bash
INDEX_FILE=.codeagent/secaudit-secguardian/scans/<scan_id>/index.json
python3 << 'PYEOF'
import json, sys, os
from collections import Counter

with open(os.environ['INDEX_FILE']) as f:
    d = json.load(f)

# ── 校验 ──
assert len(d.get('files',[])) > 0, 'FATAL: index contains no files'
assert 'symbols' in d, 'FATAL: index missing symbols'
assert 'call_graph' in d, 'FATAL: index missing call_graph'

# ── 语言检测（健壮扩展名映射） ──
EXT_MAP = {
    'c': 'cpp', 'h': 'cpp', 'cpp': 'cpp', 'cc': 'cpp', 'cxx': 'cpp', 'hpp': 'cpp', 'hh': 'cpp', 'hxx': 'cpp',
    'java': 'java',
    'py': 'python', 'pyw': 'python',
    'go': 'go',
    'js': 'javascript', 'jsx': 'javascript', 'ts': 'javascript', 'tsx': 'javascript', 'mjs': 'javascript', 'cjs': 'javascript',
    'rs': 'rust', 'swift': 'swift', 'kt': 'kotlin', 'kts': 'kotlin', 'scala': 'scala',
    'rb': 'ruby', 'php': 'php', 'cs': 'csharp', 'fs': 'fsharp',
    'sh': 'shell', 'bash': 'shell', 'zsh': 'shell',
    'cmake': 'cmake', 'mk': 'makefile',
}
def detect_lang(filepath):
    base = os.path.basename(filepath)
    if base.startswith('.'):
        return None
    if '.' not in base:
        return None
    ext = base.rsplit('.', 1)[-1].lower()
    return EXT_MAP.get(ext)

langs = Counter()
for f in d['files']:
    lang = detect_lang(f)
    if lang:
        langs[lang] += 1

primary_lang = langs.most_common(1)[0][0] if langs else 'unknown'

summary = {
    'scan_id': os.environ.get('SCAN_ID', ''),
    'file_count': len(d['files']),
    'function_count': len(d['symbols']['functions']),
    'call_edge_count': len(d['call_graph']['edges']),
    'primary_language': primary_lang,
    'language_distribution': dict(langs.most_common()),
    'index_path': os.environ['INDEX_FILE'],
}
json.dump(summary, sys.stdout, indent=2, ensure_ascii=False)
PYEOF
```

> **关键约束**：此脚本输出 JSON 到 stdout。读取该 JSON 获取 `file_count`、`function_count`、`primary_language` 等，**严禁**自行编写 Python 或 shell 去重新解析 index.json。

### Step 3: 路由并应用 Audit Skill

- 如果用户未指定 skill-name，或输入为 `analysis` / `domain` / `list`，列出对应的 skills 列表。
- 如果指定了具体的 skill-name，精确加载 `../skills/secaudit/{skill-name}/SKILL.md`。
- 根据 `index.json` 提供的符号表和调用图、`SKILL.md` 的审计规范以及 `../knowledge/detectors/` 中相关检测器的威胁定义进行深度推理审计。

### Step 4: 输出结构化 findings（遵循 Findings Protocol v1.0）

> ⚠️ **关键变更**: AI **只输出一个文件** `findings.json`，符合 `knowledge/protocols/findings-schema.json` 协议。**禁止直接写 report.md / results.sarif / 任何其他输出文件** — 这些由渲染器生成。

**4a. 构建 findings.json（含 secaudit 扩展字段）：**

每个检出必须包含完整的四段式数据（`location` + `evidence` + `impact` + `fix`），以及 `secaudit_specific` 扩展字段：

```json
{
  "secaudit_specific": {
    "skill_name": "taint-analysis",
    "skill_category": "analysis",
    "analysis_paths": 15,
    "complete_chains": 4
  },
  "findings": [
    {
      "evidence": {
        "data_flow_path": [
          {"step": "source", "file": "...", "line": 42, "description": "HTTP param"},
          {"step": "propagation", "file": "...", "line": 56, "description": "Assigned to query"},
          {"step": "sink", "file": "...", "line": 108, "description": "db.Query()"}
        ]
      }
    }
  ]
}
```

关键要求：
- `evidence.data_flow_path` — secaudit 必须包含完整的 Source → Propagation → Sink 路径（至少 3 个步骤）
- `secaudit_specific.skill_name` — 本次审计的 skill 名称
- `secaudit_specific.analysis_paths` — 分析的总数据流路径数
- `secaudit_specific.complete_chains` — 完整追踪到的链路数（Source → Sink 全部连通的）

**4b. 自检完整性（必须执行，严格的 3 次重试）：**

在保存 `findings.json` 之前，检查每个 finding 的四段式字段是否齐全。**任一 ❌ → 补充缺失内容 → 重新检查，最多 3 次。**

| 段落 | 必须字段 | Secaudit 额外要求 |
|------|---------|------------------|
| 📍 Location | `location.file_path`, `location.start_line`, `location.function_name`, `location.snippet` | — |
| 📋 Evidence | `evidence.code_context`, `evidence.judgment_rationale`, `evidence.data_flow_path` | data_flow_path 至少含 source + sink 两个节点 |
| ⚠️ Impact | `impact.attack_scenario`, `impact.cvss_score`, `impact.cvss_vector`, `impact.exploit_conditions` | — |
| 🔧 Fix | `fix.description`, `fix.before_code`, `fix.after_code`, `fix.effort_hours`, `fix.verification_method` | — |

3 次后仍未通过 → 在 findings.json 顶层添加 `"quality_gate_warning": "<ID列表>"` + `"quality_gate_retries": 3`。渲染器会在 report.md 头部标注不完整的 finding。

**4c. 写入 findings.json → 渲染器生成所有输出：**

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
    --findings .codeagent/secaudit-secguardian/scans/<scan_id>/findings.json \
    --index .codeagent/secaudit-secguardian/scans/<scan_id>/index.json \
    --output .codeagent/secaudit-secguardian/scans/<scan_id>/
```

> 渲染器自动执行 secaudit 质量门禁（Step 4b 验证），未通过的 finding 会在 report.md 中标记 ⚠️。

> ⚠️ 如果渲染器不存在或执行失败，打印警告：`"Renderer unavailable — findings saved to findings.json only."`

### Step 5: 输出审计摘要

- 渲染器执行完毕后，读取 `manifest.json` 获取审计统计。
- 向用户输出 Markdown 格式的审计摘要，包含：scan_id、skill_name、检出总数、按严重度分组、Top 5 key findings。
- 如果 quality gate 未通过，明确列出不完整的 finding ID。
