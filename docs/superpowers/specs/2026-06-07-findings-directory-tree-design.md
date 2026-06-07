# SecGuardian Findings 输出协议 v5.0 — 目录树重构设计

> **状态**: 待确认 | **日期**: 2026-06-07 | **作者**: JonyAn + Claude Opus 4.8

## 1. 问题陈述

### 1.1 当前痛点 (v4.0 单体 findings.json)

v4.0 架构中 AI 一次调用输出一个单体的 `findings.json`，该文件同时承载三项职责：

```
findings.json = 索引(index) + 证据(evidence) + 修复方案(fix)
```

| 项目规模 | 文件数 | 预估 findings | findings.json 大小 | AI 能否读取？ |
|---------|--------|-------------|-------------------|-------------|
| 小型 (当前 demo) | 3 | 27 | ~50KB | ✅ |
| 中型项目 | 100 | 300-500 | ~1-2MB | ⚠️ 接近极限 |
| 大型项目 | 1000 | 2000-5000 | ~10-25MB | ❌ 无法读取 |
| 企业级 | 10000+ | 20000+ | ~100MB+ | ❌ 完全不可行 |

**核心矛盾**: AI Agent 的输出能力（单次 Write ~100KB 可行）与后续消费能力（读取 25MB JSON 直接爆 token 上限）之间严重不匹配。3 个 Python 文件 27 个 finding 已经花了 ~9 分钟（瓶颈在输出 token），1000 文件项目根本跑不完。

### 1.2 用户设计哲学

> "我们是世界顶尖解决方案，级别只是危险程度，级别低不代表不是问题。所有检出来的问题，我都要用户认可，愿意去修正。"

核心原则：
- **每个 finding 都是独立的安全问题**，不因 severity 低而被忽略
- **按技术类别（detector）组织**，而非按严重度分堆
- **不要 severity 维度的重复输出**，避免给客户造成困惑
- **生产环境同类问题会有多个**，需要合理的去重命名规则

## 2. 设计方案

### 2.1 核心思路：单体 JSON → 目录树

AI 不再输出单体 `findings.json`，而是**每个 finding 输出一个独立文件**，按 detector 分类存放在目录树中。**文件名直接使用 finding ID**，利用其天然唯一性（同文件同行同 detector 只会产生一个 finding，ID 不会碰撞）：

```
.codeagent/secguard-secguardian/scans/<scan-id>/
├── index.json                    # 索引器输出：符号表+调用图+文件清单（Step 2，只读）
├── findings.json                 # ★ v5.0 轻量化：同名文件，职责从"单体四段式"升级为"元数据+检出索引"（<50KB）
├── findings/                     # ★ 新：finding 目录树（四段式数据按 detector 分文件存放）
│   ├── web/
│   │   ├── sql-injection/
│   │   │   └── H-SQLI-webapp-L47.json           # 完整四段式，文件名 = finding ID
│   │   ├── ssrf/
│   │   │   ├── H-SSRF-file_handler-L35.json
│   │   │   ├── H-SSRF-file_handler-L43.json
│   │   │   └── H-SSRF-webapp-L76.json
│   │   ├── xss/
│   │   │   └── M-XSS-webapp-L69.json
│   │   ├── path-traversal/
│   │   │   ├── H-PTRAV-file_handler-L26.json
│   │   │   └── H-PTRAV-file_handler-L47.json
│   │   ├── csrf/
│   │   │   └── M-CSRF-webapp-L83.json
│   │   ├── auth-bypass/
│   │   │   └── M-AUTH-webapp-L94.json
│   │   ├── idor/
│   │   │   └── M-IDOR-webapp-L100.json
│   │   ├── xxe/
│   │   │   └── H-XXE-webapp-L112.json
│   │   ├── open-redirect/
│   │   │   └── M-REDIR-webapp-L130.json
│   │   ├── input-validation/
│   │   │   └── M-INPUT-webapp-L147.json
│   │   ├── missing-authn/
│   │   │   └── M-AUTHN-webapp-L170.json
│   │   ├── missing-authz/
│   │   │   └── M-AUTHZ-webapp-L164.json
│   │   ├── deserialization/
│   │   │   └── C-DESER-crypto_utils-L40.json
│   │   └── unrestricted-upload/
│   │       └── L-UPLOAD-webapp-L157.json
│   ├── crypto/
│   │   ├── password-storage/
│   │   │   └── H-CRYPTO-crypto_utils-L20.json
│   │   ├── custom-crypto/
│   │   │   └── H-CRYPTO-crypto_utils-L46.json
│   │   ├── hardcoded-credentials/
│   │   │   └── H-SECRET-webapp-L27.json
│   │   ├── jwt-misuse/
│   │   │   └── H-JWT-webapp-L120.json
│   │   └── weak-random/
│   │       └── L-RAND-crypto_utils-L32.json
│   ├── system/
│   │   ├── command-injection/
│   │   │   └── C-CMD-webapp-L60.json
│   │   └── code-injection/
│   │       └── C-CODE-webapp-L138.json
│   ├── resource/
│   │   ├── insecure-permissions/
│   │   │   └── M-PERM-webapp-L178.json
│   │   └── resource-exhaustion/
│   │       └── L-DOS-webapp-L186.json
│   └── error/
│       └── debug-mode-production/
│           └── M-DEBUG-webapp-L195.json
├── report.md                    # 渲染器基于 findings/ 目录树生成
├── results.sarif
├── summary.json
├── manifest.json
├── status.json
├── delta.json
└── latest → <scan-id>/
```

### 2.2 文件命名规范：以 Finding ID 为文件名

**业界参考**：SARIF 用 `partialFingerprints`（哈希），CodeQL 用 `<rule-id>/<file-hash>`，Semgrep 用 `<rule-id>.<finding-hash>`。共同特征：**用全局唯一 ID 做文件名，而非从文件路径拼接**。

SecGuardian 的 finding ID 格式天然满足唯一性要求：

```
<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>.json
```

例如：`H-SQLI-webapp-L47.json`

| 组成部分 | 说明 | 唯一性保证 |
|---------|------|-----------|
| `SEVERITY` | C=Critical, H=High, M=Medium, L=Low, I=Info | — |
| `DETECTOR_ABBREV` | 3-5 字符 detector 缩写（如 SQLI, SSRF, CRYPTO） | 同一行不同 detector = 不同 ID |
| `FILE_SLUG` | 文件名去扩展名，特殊字符替换为 `_` | 不同文件 = 不同 ID |
| `L<LINE>` | 行号前缀 `L` + 数字 | **同一文件同一行同一 detector 只产生一个 finding** |

**为什么不会碰撞？**
- 同一行代码不会被同一 detector 重复报告（每个 detector 对每行最多产生一个 finding）
- 不同 detector 的缩写不同（`SQLI` vs `SSRF` vs `CRYPTO`）
- 不同文件不同行号天然隔离
- **从根本上消除碰撞可能**，无需 `__N` 后缀补丁

**与 `<file_slug>__<function>.json` 方案对比**：

| 维度 | `<file>__<func>.json` | **`<finding-id>.json`（本方案）** |
|------|----------------------|----------------------------------|
| 唯一性 | ❌ 同文件同函数同 detector 不同行碰撞 | ✅ finding ID 天然唯一 |
| 可读性 | 需要解析 `__` 分隔符 | ID 自描述（严重度+漏洞类型+文件+行号） |
| 简洁性 | 需要 file_slug + function 双重编码 | 一个 ID 全搞定 |
| 业界对齐 | 无对应（自创约定） | ✅ 对齐 SARIF/CodeQL/Semgrep 的 ID-as-key 模式 |

### 2.3 单个 Finding 文件格式

每个 finding 文件遵循 `findings-schema.json` 中 `$defs/Finding` 的完整四段式结构，自包含、可独立阅读：

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

**文件大小预估**: 单个 finding 文件约 2-4KB（含完整四段式），远低于 AI Agent 的 token 上限。

### 2.4 `findings.json` — 同名文件，职责升级

v4.0 的 `findings.json` 是单体文件（索引+四段式数据），v5.0 升级为纯索引文件：保留扫描元数据和检出清单，**四段式数据移至 `findings/` 目录下的独立文件**。文件名不变，用户无需学习新概念。

`path` 字段相对于 scan root（`findings/` 前缀开头），指向单个 finding 文件的完整路径：

```json
{
  "scan_id": "sc-20260607-120000-a1b2",
  "command": "secguard",
  "path": "./src",
  "mode": "full",
  "language": "python",
  "timing": { "started": "...", "completed": "...", "duration_ms": 76000 },
  "scope": { "files": 3, "lines": 295, "functions": 15, "call_edges": 1 },
  "detectors": {
    "matched": 27,
    "executed": 27,
    "namespaces_used": ["crypto", "web", "system", "error", "resource"]
  },
  "security_score": 0,
  "score_grade": "F",
  "summary": {
    "total": 27,
    "by_severity": { "Critical": 3, "High": 11, "Medium": 10, "Low": 3, "Info": 0 },
    "by_detector": {
      "web.ssrf": 3,
      "web.path-traversal": 2,
      "web.sql-injection": 1,
      "...": "..."
    }
  },
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

**索引文件大小**: 每个 finding 条目约 300 字节，1000 个 finding 的索引约 300KB，仍在可读范围。

### 2.5 AI 执行流程变更

**当前 (v4.0)**:
```
Step 4a: AI 构建单体 findings.json（所有 27 个 finding）
Step 4b: 自检完整性 → Step 4c: 渲染器
```
**瓶颈**: 单次 Write 输出 50KB+ JSON，token 消耗巨大。

**新方案 (v5.0)**:
```
Step 4a: AI 按 detector 分组，逐文件输出 finding（每个 2-4KB）
  → findings/web/sql-injection/H-SQLI-webapp-L47.json
  → findings/crypto/password-storage/H-CRYPTO-crypto_utils-L20.json
  → ... (27 次 Write 调用，每次 ~2KB)
Step 4b: AI 输出轻量 findings.json（同名文件，不含四段式，~8KB）
Step 4c: 自检完整性（验证 findings.json 条目数 = findings/ 目录下 finding 文件数）
Step 4d: 渲染器读取 findings/ 目录树 + indexer 的 index.json → 生成 6 个输出文件
```

**Token 消耗对比**:

| 阶段 | v4.0 (单体) | v5.0 (目录树) |
|------|-----------|-------------|
| Finding 输出 | 1 次 Write, ~50KB | 27 次 Write, 每次 ~2KB |
| 索引输出 | 与四段式数据混在一起 | findings.json（纯索引，~8KB） |
| AI 读取（后续） | 必须读整个 50KB+ | 按需读单个 2KB 文件 |
| 1000 文件项目 | ❌ 无法完成 | ✅ 可扩展 |

### 2.6 渲染器改造

`scripts/render-report.py` 改造点：

| 当前 | 改造后 |
|------|--------|
| `--findings findings.json` (单文件) | `--findings-dir findings/` (目录) |
| `json.load()` 一次读入所有 finding | `os.walk()` 遍历目录，逐个 `json.load()` |
| finding 数据在内存中聚合成列表 | 同样聚合为列表，后续生成逻辑不变 |

渲染器内部逻辑（生成 report.md / SARIF / summary / manifest / status / delta）保持不变，只改变数据读取方式。

伪代码（findings/ 目录下只有 finding 文件，无 index/元数据文件，故无需过滤）：
```python
def load_findings_from_tree(findings_dir):
    """Walk findings/<namespace>/<detector>/<finding-id>.json and aggregate."""
    findings = []
    for root, dirs, files in os.walk(findings_dir):
        for fname in sorted(files):
            if fname.endswith('.json'):
                with open(os.path.join(root, fname)) as f:
                    data = json.load(f)
                    # Support {"finding": {...}} wrapper (v5.0) and bare object
                    findings.append(data.get('finding', data))
    return findings
```

注：`findings.json` 在 scan root，`findings/` 目录内只有 finding 文件，`os.walk()` 天然不会遍历到索引文件。

### 2.7 向后兼容

渲染器同时支持两种模式：
- `--findings findings.json` → v4.0 单体模式（兼容旧扫描结果）
- `--findings-dir findings/` → v5.0 目录树模式（新默认）

## 3. 设计原则对照

| 原则 | 实现方式 |
|------|---------|
| **每个 finding 独立可读** | 单文件自包含四段式，AI Agent 可精准读取 |
| **按 detector 组织** | 目录结构 `findings/<namespace>/<detector>/` |
| **不按 severity 重复** | 无 severity 维度目录，避免给客户"某些问题不重要"的暗示 |
| **防冲突命名** | finding ID 即文件名，天然唯一（同行同 detector 不会重复报告） |
| **可扩展** | 企业级 10 万文件项目的 finding 也能正常存取 |
| **人类友好** | 文件浏览器可直接按 detector 分类浏览 |

## 4. 用户使用流程

| 我想做什么 | 操作 |
|-----------|------|
| **看全局摘要** | 打开 `findings.json`（同名文件，v5.0 已轻量化）— 统计 + 检出列表 |
| **按漏洞类型审查** | 进入 `findings/web/sql-injection/` — 查看所有 SQL 注入问题 |
| **看某个具体漏洞** | 打开 `findings/web/sql-injection/H-SQLI-webapp-L47.json` — 完整四段式 |
| **给团队分工** | "小王负责 `findings/crypto/` 下所有问题，小李负责 `findings/web/`" |
| **AI 批量修复** | 告诉 AI："读取 `findings/crypto/` 下所有文件，按 fix.after_code 修改源码" |
| **看修复报告** | 打开 `report.md`（渲染器自动聚合所有 finding 生成） |

## 5. 实施计划

### Phase 1: 渲染器适配（向后兼容）
- `scripts/render-report.py` 增加 `--findings-dir` 参数
- 同时保留 `--findings` 参数兼容旧格式
- 验证：用当前 findings.json → 和用目录树 → 生成相同的 report.md

### Phase 2: 协议文档更新
- `knowledge/protocols/scan-output.md` — 更新目录结构章节
- `knowledge/protocols/findings-schema.json` — 增加单 finding 文件 schema
- `skills/secguard-python/references/` — 更新 scanner 指令

### Phase 3: Command 指令更新
- `commands/secguard.md` — Step 4 改为逐文件输出
- `commands/secaudit.md` — 同步更新
- `commands/secreview.md` — 同步更新

### Phase 4: 端到端验证
- 用 python-vuln-demo 完整跑一次扫描
- 对比新旧格式生成报告的一致性
- 验证 AI Agent 可以按需读取单个 finding 文件

## 6. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 文件数量爆炸 | 1000 finding = 1000 个 2KB 文件 = 2MB 总存储，现代文件系统完全可承受。Git 建议加入 `.gitignore` |
| 渲染器性能 | `os.walk()` 遍历 1000 目录约 10ms；逐个读 JSON 约 100ms。总耗时 < 1s |
| 文件名冲突 | finding ID 天然唯一（同行同 detector 不重复），无需去重机制 |
| AI 输出 27 次 Write | 比 1 次 Write 50KB 更快（每次只需生成 2KB），总 token 略增但每步更可控 |

---

*关联文档: [[2026-06-05-output-protocol-v3-design]], [[design-journal]]*
