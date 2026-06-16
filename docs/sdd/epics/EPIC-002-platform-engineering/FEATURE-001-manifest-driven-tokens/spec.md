# Manifest-Driven Tokens — 消除散弹式修改

> **Feature**: FEATURE-001-manifest-driven-tokens
> **Epic**: EPIC-002-platform-engineering
> **状态**: ✅ 已完成
> **日期**: 2026-06-07
> **作者**: JonyAn + Claude Opus 4.8


## 1. 问题陈述

### 1.1 散弹式修改 (Shotgun Surgery)

向系统添加一个 detector 需要修改 8+ 个文件中的硬编码数字：

| 文件 | 硬编码内容 | 影响 |
|------|-----------|------|
| `manifest.json` | count: 67, namespace counts | 权威源 |
| `knowledge/threat-catalog.md` | 8 处 namespace 计数 | 每次必须手动同步 |
| `extensions/.../extension.json` | description 中的 "67 个检测器" | 部署描述过期 |
| `commands/secguard.md` | description frontmatter | 命令帮助文本过期 |
| `skills/.../detector-index.md` | "全部 67 个检测器" | AI 指令过期 |
| `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` | 多处提及 detector 数量 | AI 入口上下文过期 |
| `scripts/render-report.py` | DETECTOR_RULE_INDEX (70 行) | 代码硬编码 |
| `docs/reference/interview-ppt.md` | 8+ 处 "67 检测器" | PPT 材料过期 |
| `docs/competitive-analysis.md` | "67 active detectors" | 竞品分析过期 |
| `docs/reference/beijing-ai-security-companies.md` | 5+ 处 | 求职材料过期 |
| `docs/reference/` | 5+ 处 | 作品集过期 |

### 1.2 根因

没有一个**单一权威源 + 自动同步机制**。`manifest.json` 理论上承担这个角色，但其他文件不读取它——各自维护自己的数字副本。

### 1.3 设计目标

- **单一权威源 (Single Source of Truth)**：`manifest.json`
- **自动传播 (Auto-Propagation)**：所有衍生文件通过构建流程自动更新
- **可验证 (Verifiable)**：CI 捕获任何未同步的硬编码数字
- **零认知负担 (Zero Cognitive Load)**：开发者加 detector 时只改 manifest.json + 写 detector 文件，其余自动
- **人类可读 (Human-Readable)**：部署后的文件不含占位符，仍是正常文本

## 2. 设计方案

### 2.1 核心思路

借鉴 Helm Chart 的 `{{ .Values.xxx }}` 模板模式，但适配 Markdown 项目：

**源文件（git 中）**：数字后跟隐藏标记
```
67<!-- @secguardian:detector_count -->
```

**构建时**：`scripts/sync-manifest.sh` 读取 `manifest.json`，查找所有 `<!-- @secguardian:xxx -->` 标记，更新前面的数字为权威值。

**部署后**：标记仍在（HTML 注释，不影响渲染），但数字已是正确的。

### 2.2 Token 规范

| Token 标记 | manifest.json 路径 | 示例输出 |
|-----------|-------------------|---------|
| `detector_count` | `knowledge.detectors.count` | `67` |
| `namespace_count` | `len(knowledge.detectors.namespaces)` | `7` |
| `namespace:memory` | `knowledge.detectors.namespaces.memory` | `13` |
| `namespace:concurrency` | `knowledge.detectors.namespaces.concurrency` | `4` |
| `namespace:system` | `knowledge.detectors.namespaces.system` | `8` |
| `namespace:crypto` | `knowledge.detectors.namespaces.crypto` | `9` |
| `namespace:web` | `knowledge.detectors.namespaces.web` | `21` |
| `namespace:error` | `knowledge.detectors.namespaces.error` | `6` |
| `namespace:resource` | `knowledge.detectors.namespaces.resource` | `6` |

### 2.3 文件分级：哪些用 Token，哪些不用

**必须 Token 化**（运行时被 AI Agent/用户读取，过期会影响系统行为）：

| 文件 | Token 使用 |
|------|-----------|
| `knowledge/threat-catalog.md` | 8 处 namespace 计数 + 前端 description |
| `extensions/secguard-secguardian/extension.json` | description 字段 |
| `extensions/secaudit-secguardian/extension.json` | description 字段 |
| `extensions/secreview-secguardian/extension.json` | description 字段 |
| `commands/secguard.md` | frontmatter description |
| `skills/secguard/cpp/references/detector-index.md` | "全部 N 个检测器" |
| `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` | detector 数量提及 |

**建议 Token 化**（对外展示材料，过期影响信任度）：

| 文件 | Token 使用 |
|------|-----------|
| `docs/reference/interview-ppt.md` | 多处 "67 检测器" |
| `docs/competitive-analysis.md` | "67 active detectors" |

**不需要 Token 化**（历史记录或代码逻辑）：

| 文件 | 原因 |
|------|------|
| `manifest.json` | 权威源本身 |
| `docs/sdd/brainstorm-log.md` | 历史决策记录，过时数字反映当时状态 |
| `scripts/render-report.py` | 改为从 manifest.json 动态加载 DETECTOR_RULE_INDEX |

### 2.4 `scripts/render-report.py` DETECTOR_RULE_INDEX 改造

当前 `render-report.py` 中硬编码了 68 个 detector 的 CWE 映射表（70 行）。改为从 `manifest.json` 动态加载。

```python
# Before: hardcoded dict
DETECTOR_RULE_INDEX = {
    "system.command-injection": {"index": 0, "cwe": ["CWE-77", "CWE-94"]},
    "web.sql-injection":        {"index": 1, "cwe": ["CWE-89"]},
    # ... 68 entries
}

# After: loaded from manifest or knowledge/detectors/
def load_detector_index():
    """Build detector → CWE mapping from detector files."""
    index = {}
    det_dir = os.path.join(os.path.dirname(__file__), "..", "knowledge", "detectors")
    for i, fname in enumerate(sorted(os.listdir(det_dir))):
        if fname.endswith('.md'):
            name = fname[:-3]  # remove .md
            # Parse CWE from detector file frontmatter
            # ...
    return index
```

### 2.5 `scripts/sync-manifest.sh` — 核心同步脚本

```bash
#!/bin/bash
# sync-manifest.sh — 从 manifest.json 同步所有 token 标记到项目文件
#
# 用法: bash scripts/sync-manifest.sh [--check]
#   (无参数)  更新所有文件中的 token 数字
#   --check   只检查不修改（CI 模式），发现不一致时 exit 1
#
# Token 格式: NNN<!-- @secguardian:token_name -->
# sync-manifest.sh 读取 manifest.json，更新 NNN 为权威值。

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$PROJECT_ROOT/manifest.json"

# 从 manifest.json 提取权威值
DETECTOR_COUNT=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['knowledge']['detectors']['count'])")
NAMESPACE_COUNT=$(python3 -c "import json; print(len(json.load(open('$MANIFEST'))['knowledge']['detectors']['namespaces']))")
# ... 各 namespace 数量

# 更新规则: 在每个文件中查找 "NNN<!-- @secguardian:name -->"，替换为正确的 NNN
update_token() {
    local file="$1"
    local token="$2"
    local value="$3"
    if [ "$CHECK" = "1" ]; then
        # CI 模式: 检查是否匹配
        local actual=$(grep -oP "\d+(?=<!-- @secguardian:$token -->)" "$file" 2>/dev/null)
        if [ "$actual" != "$value" ]; then
            echo "  ❌ $file: @secguardian:$token = $actual (expected $value)"
            return 1
        fi
    else
        # 更新模式
        sed -i "s/[0-9]\+<!-- @secguardian:$token -->/$value<!-- @secguardian:$token -->/g" "$file"
    fi
}
```

### 2.6 集成到构建流程

```
dev-deploy.sh
  └─ package.sh
       ├─ sync-manifest.sh          # ★ 新增：同步所有 token
       ├─ go build (索引器)
       └─ assemble dist/
            └─ 所有 token 数字已更新 → 部署
```

`self-check.sh` 新增检查项：
- `sync-manifest.sh --check` — 验证所有 token 数字与 manifest.json 一致

## 3. 实施计划

### Phase 1: sync-manifest.sh 脚本
- 创建 `scripts/sync-manifest.sh`
- 实现 token 读取、替换、`--check` 模式
- 单元验证：修改 manifest.json count → 运行脚本 → 确认所有文件更新

### Phase 2: 文件 Token 化
- 在 12 个文件中逐个替换硬编码数字为 token 标记
- 每个文件修改后立即运行 `sync-manifest.sh --check` 确认一致

### Phase 3: render-report.py 动态加载
- 移除 DETECTOR_RULE_INDEX 硬编码
- 改为从 knowledge/detectors/ 目录动态构建映射表
- 验证：SARIF 输出 CWE 字段与之前一致

### Phase 4: 集成 + 验证
- `package.sh` 调用 `sync-manifest.sh`
- `self-check.sh` 调用 `sync-manifest.sh --check`
- 端到端验证：添加新 detector → manifest.json count+1 → deploy → 所有文件自动更新

## 4. 设计原则

| 原则 | 实现 |
|------|------|
| **单一权威源** | manifest.json |
| **自动传播** | sync-manifest.sh 在构建时运行 |
| **人类可读** | 数字 + HTML 注释，不影响 Markdown 渲染 |
| **CI 可验证** | `--check` 模式，非零退出码 |
| **零认知负担** | 开发者只改 manifest.json + 写 detector 文件 |

## 5. 与现有验证体系的关系

新增检测在 L1 (`self-check.sh`) 层：
- **现有**: detector ↔ index ↔ manifest 交叉校验 (83 项)
- **新增**: sync-manifest.sh `--check` → 所有 token 数字与 manifest.json 一致
- **总计**: 83 + N 项（N = token 使用点数量）

---

*关联文档: [[2026-06-07-findings-directory-tree-design]], [[brainstorm-log]]*
