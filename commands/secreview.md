---
name: secreview
description: "安全编码规范检视 — 5 语言反模式检测矩阵 + 最佳实践合规审查"
---

# /secreview - 通用安全规范检视

检视危险函数使用、安全函数规范、代码反模式和最佳实践合规。

## 使用方式

```
/secreview <path> [language]

/secreview ./src                 # 自动检测语言
/secreview ./src java            # Java 安全规范检视
/secreview ./src python          # Python 安全规范检视
/secreview ./src cpp             # C/C++ 安全规范检视
/secreview ./src go              # Go 安全规范检视
/secreview ./src java --sarif    # 输出 SARIF 格式 (CI/CD)
```

## 输出

遵循 [Scan Output Protocol 3.0](../knowledge/protocols/scan-output.md)。人读/机读分离。

```
.codeagent/secreview-secguardian/scans/<scan-id>/
├── report.md               # ★ 人读检视报告 (Markdown)
├── results.sarif            # 机读: SARIF 2.1.0 (CI/CD)
├── summary.json             # 仪表盘统计
├── manifest.json            # 检视元数据 + 发现索引
├── status.json              # CI 门禁
└── delta.json               # 增量对比 (vs 上次扫描)
```

**执行完毕后必须输出检视摘要：**

```
## secreview 检视完成

Scan ID: 2026-05-23T14-30-00-c4d5
Path: ./src
Language: Java (auto-detected)

### 结果
- 扫描文件: 45
- 检视项: 32 checked
- 检出: 5 (Critical: 0, High: 2, Medium: 3)

### 发现
| ID | Severity | Category | File | 修复建议 |
|----|----------|----------|------|---------|
| H-001 | High | 异常吞掉 | src/service/UserService.java:89 | 空 catch 块至少添加错误日志；安全关键操作（认证/鉴权）必须传播异常 |
| H-002 | High | 字段注入 | src/controller/AdminController.java:23 | 使用构造函数注入替代 `@Autowired` 字段注入 |
| M-001 | Medium | 日志含敏感信息 | src/handler/AuthHandler.java:156 | 日志脱敏：`logger.info("User: {}", username)` 而非 `logger.info(user.toString())` |
| M-002 | Medium | ThreadLocal 未清理 | src/filter/RequestFilter.java:42 | 在 `finally` 块中调用 `ThreadLocal.remove()` |
| M-003 | Medium | @Transactional 自调用 | src/service/OrderService.java:203 | 通过代理调用或提取到独立的 Service 方法 |

> 每个发现的修复建议来自反模式检测矩阵和对应语言的 `## 修复指引` 节。

输出目录: .codeagent/secreview-secguardian/scans/2026-05-23T14-30-00-c4d5/

💡 **如何使用检视结果？**
- **快速看汇总** → 打开 `manifest.json`
- **★ 人读检视报告** → 打开 `report.md`（每个不合规项含完整四段式：📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）
- **CI/CD 集成** → 消费 `results.sarif`
- **AI Agent 修复** → 告诉 AI：`读取 report.md §4，按每个发现的 🔧 Fix 方案修改代码`
```

## 与 /secguard 的区别

| 维度 | secguard | secreview |
|------|----------|-----------|
| 粒度 | 具体 API 调用级 + detector 过滤 | 函数/模块级语义 + 语言 |
| 关注点 | 是否存在可利用漏洞 | 是否符合安全编码规范 |
| 输出 | CWE + CVSS | 反模式 + 最佳实践违规 |
| 严重度 | Critical → Info | High → Info |

## 派发规则与执行步骤

> **隔离约束**: 本命令只能加载 `skills/` 扩展下的 `secreview-*` 前缀 skill，禁止加载 `secguard-*` 或 `secaudit-*` 前缀的任何文件。反模式检测矩阵仅从 `skills/secreview/{language}/SKILL.md` 和对应 `references/` 加载。

你（AI Agent）在接收到 `/secreview` 命令后，必须按以下步骤执行来构建索引并进行安全编码规范检视。

### 前置检查（Pre-flight Checklist）

在执行任何检视步骤之前，必须逐项确认以下所有条件。**任一项未通过，检视不得开始，向用户报告具体错误。**

- [ ] 定位索引器 wrapper：检查 `.opencode/extensions/secguardian/`（项目级）→ `~/.config/opencode/extensions/secguardian/`（用户级）→ `.gemini/` → `.claude/` → `scripts/` 回退（至少一个存在且可执行）
- [ ] 执行 `{indexer} --health` 通过（输出必须包含 `HEALTH:OK` 或 `HEALTH:WARN`，不接受 `HEALTH:FAIL`）
- [ ] 目标路径 `<path>` 存在且包含至少一个源码文件
- [ ] 确认不会启动 clangd/LSP/compile_commands.json/bear 等外部工具 — indexer (tree-sitter) 已提供符号表+调用图+文件清单，所有代码结构数据从 index.json 获取

> 若未通过，报告具体哪一项失败并终止。不要降级为手工逐文件检视。

---

### Step 1: 建立输出目录

- 生成 `scan_id`（格式: `rv-YYYYMMDD-HHMMSS-xxxx`，其中 `xxxx` 为随机4位字符）。
- 创建输出目录: `.codeagent/secreview-secguardian/scans/<scan_id>/`。
- 记录检视开始时间戳，用于 Step 4 计算 `duration_ms`。

### Step 2: 构建语义索引（必须执行，不可跳过）

> ⚠️ 这是检视的**核心前置步骤**。索引器提供符号表、调用图，是后续规范检视的结构化上下文。**不执行此步骤将导致检视质量严重下降。**

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
$INDEXER --path <path> --output .codeagent/secreview-secguardian/scans/<scan_id>/index.json
```

**2b. 验证索引完整性 + 生成结构化摘要（必须通过）：**

执行以下脚本。若返回非 0，**立即终止检视**并向用户报告索引生成出错。
若成功，直接读取输出的 JSON 摘要作为后续所有步骤的上下文，**禁止自己写 Python 去探测索引结构**。

```bash
INDEX_FILE=.codeagent/secreview-secguardian/scans/<scan_id>/index.json
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

### Step 3: 语言检测与 Skill 路由

- 从摘要中的 `primary_language` 获取目标语言。
- 加载对应语言的 skill：`../skills/secreview/{language}/SKILL.md`。
- 参考 `../knowledge/languages/{language}.md` 中的危险 API 列表和框架安全说明。

- **利用 index.json 中的符号表定位检视目标**，而非逐文件遍历。

### Step 4: 输出结构化 findings（遵循 Findings Protocol v1.0）

> ⚠️ **关键变更**: AI **只输出一个文件** `findings.json`，符合 `knowledge/protocols/findings-schema.json` 协议。**禁止直接写 report.md / results.sarif / 任何其他输出文件** — 这些由渲染器生成。

**4a. 构建 findings.json（含 secreview 扩展字段）：**

每个检出必须包含完整的四段式数据（`location` + `evidence` + `impact` + `fix`），以及 `secreview_specific` 扩展字段：

```json
{
  "secreview_specific": {
    "review_type": "full",
    "review_focus": ["security", "code-quality"]
  },
  "findings": [
    {
      "severity": "High",
      "cwe": "CWE-390",
      "detector": "error.exception-swallow",
      "evidence": {
        "judgment_rationale": "空 catch 块吞掉异常 — 违反了 SEI CERT ERR00-J"
      }
    }
  ]
}
```

关键要求：
- `evidence.judgment_rationale` — 必须引用对应语言的安全编码规范（SEI CERT Oracle / SEI CERT C / OWASP / Go Security Guidelines）
- `secreview_specific.review_focus` — 本次检视的焦点领域

**4b. 自检完整性（必须执行）：**

在保存 `findings.json` 之前，检查每个 finding 的四段式字段是否齐全。**任一 ❌ → 补充缺失内容 → 重新检查，最多 3 次。**

| 段落 | 必须字段 | Secreview 额外要求 |
|------|---------|------------------|
| 📍 Location | `location.file_path`, `location.start_line`, `location.function_name`, `location.snippet` | — |
| 📋 Evidence | `evidence.code_context`, `evidence.judgment_rationale` | judgment_rationale 需引用违反的安全编码规范 |
| ⚠️ Impact | `impact.attack_scenario` | 说明不合规的潜在安全风险 |
| 🔧 Fix | `fix.description`, `fix.before_code`, `fix.after_code`, `fix.effort_hours`, `fix.verification_method` | — |

3 次后仍未通过 → 在 findings.json 顶层添加 `"quality_gate_warning": "<ID列表>"`。

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
    --findings .codeagent/secreview-secguardian/scans/<scan_id>/findings.json \
    --index .codeagent/secreview-secguardian/scans/<scan_id>/index.json \
    --output .codeagent/secreview-secguardian/scans/<scan_id>/
```

> ⚠️ 如果渲染器不存在或执行失败，打印警告：`"Renderer unavailable — findings saved to findings.json only."`

### Step 5: 输出检视摘要

- 渲染器执行完毕后，读取 `manifest.json` 获取检视统计。
- 向用户输出 Markdown 格式的检视摘要，包含：scan_id、language、检出总数、按严重度/类别分组、Top 5 key findings。
