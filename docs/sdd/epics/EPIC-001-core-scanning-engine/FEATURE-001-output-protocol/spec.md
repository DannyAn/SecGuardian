# Output Protocol Evolution — 输出协议演进设计

> **Feature**: FEATURE-001-output-protocol
> **Epic**: EPIC-001-core-scanning-engine
> **状态**: ✅ 已完成
> **周期**: 2026-06-05 ~ 2026-06-07
> **作者**: JonyAn + Claude Opus 4.8
>
> 本 Feature 涵盖输出协议从 v2 摘要型报告到 v5 目录树架构的完整演进。
> 分为两个 Phase：
> - **Phase 1 (v3.0)**: 四段式标准化 + SARIF 双轨策略
> - **Phase 2 (v5.0)**: 单体 JSON → 目录树架构

---

## Phase 1: 输出协议 v3.0 — 四段式 + SARIF 增强


> **状态**: 已确认 | **日期**: 2026-06-05 | **作者**: JonyAn + Claude Opus 4.8

## 1. 问题陈述

### 1.1 当前痛点

1. **report.md 质量不一致**：输出协议 v2.0 的模板设计完善，但 AI agent 实际执行时落地质量波动大——有时生成完整报告（含证据链+修复），有时只输出摘要表格。根源在于**无强制性质量门禁**。

2. **SARIF Viewer 体验差**：当前 `results.sarif` 已填充 `fixes`、`properties`、`contextRegion` 等字段，但：
   - 未使用 `message.markdown`（GitHub Code Scanning 的核心富文本字段）
   - 未使用 `relatedLocations`（无法展示数据流 Source→Sink）
   - 未使用 `taxa`（CWE 分类不可见于 viewer）
   - 大部分 SARIF viewer 不渲染 `fixes` 和自定义 `properties`
   - 用户点击定位后只看到一行 `message.text` 摘要

3. **detector 知识库未充分利用**：60 个 detector 文件已有完整的检测逻辑、修复指引、误报排除规则，但 SARIF 中未体现这些内容。

### 1.2 用户反馈

> "report.md 太简单了，就是 summary 摘要性质的。人读检视报告应该列出问题、指出位置、提供 Evidence 证据和修复建议。SARIF 结果文件点击定位后看不到证据和修改建议。"

## 2. 设计目标

1. **report.md 每个发现四段式标准化**：📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix
2. **SARIF 双轨策略**：`message.markdown`（GitHub viewer 可渲染）+ `properties`（API/仪表盘可消费）
3. **质量门禁**：在 commands/skills 中嵌入强制检查清单，确保每个 finding 完整性
4. **分两阶段实施**：Phase 1（指令强化，1-2h）→ Phase 2（协议升级，3-4h）

## 3. Phase 1：质量门禁 + 指令强化

### 3.1 核心原则

每个安全检出必须满足**四段式完整性**：

| 段 | 图标 | 内容 | 必须包含 |
|----|------|------|---------|
| Location | 📍 | 位置信息 | 文件路径、行号、函数名、具体代码行 |
| Evidence | 📋 | 证据展示 | 代码上下文（前后2-3行）、判定依据、数据流路径（如适用） |
| Impact | ⚠️ | 影响评估 | 攻击场景描述、CVSS评分、利用条件 |
| Fix | 🔧 | 修复方案 | Before/After代码对比、工作量评估、验证方法、参考链接 |

### 3.2 输出前质量检查清单

在每个 command 的 Step 4（保存检出）中嵌入以下强制检查：

```
## 输出前质量检查（Step 4 追加）

### report.md 质量门禁
- [ ] §3 检出清单每个条目包含：ID | 严重度 | CWE | 文件:行 | 标题
- [ ] §4 每个检出包含 📍 Location 小节（文件+行号+函数+代码行）
- [ ] §4 每个检出包含 📋 Evidence 小节（代码上下文 3+ 行 + 判定依据）
- [ ] §4 每个检出包含 ⚠️ Impact 小节（攻击场景 + CVSS评分 + 利用条件）
- [ ] §4 每个检出包含 🔧 Fix 小节（before/after 代码 + 工作量 + 验证方法）
- [ ] §4 每个检出引用对应 detector 的修复指引和 CWE 参考链接
- [ ] §5 修复路线图包含 Phase 1-4 全部（含预估工时）

### SARIF 质量门禁
- [ ] 每个 result 包含 message.text（📍 开头一句话定位摘要）
- [ ] 每个 result 包含 message.markdown（完整四段式富文本）
- [ ] 每个 result 包含 relatedLocations（Source → Sink，如适用）
- [ ] 每个 result 包含 fixes[]（before/after 替换）
- [ ] 每个 result 包含 partialFingerprints（去重指纹）
- [ ] 每个 result 的 properties 包含：confidence, impact, cvss, detector_namespace
- [ ] driver.rules[] 每个 rule 包含 taxa 映射（CWE编号+名称+helpUri）

### 未通过处理
任一 ❌ → 补充缺失内容 → 重新检查，最多 3 次。
3 次后仍未通过 → 在 report.md 中标注 "⚠️ 部分发现的完整性未达标"
```

### 3.3 改动文件清单

| 文件 | 改动点 | 目的 |
|------|--------|------|
| `commands/secguard.md` | Step 4 追加质量检查清单 | AI agent 保存前自检 |
| `commands/secaudit.md` | 同上 | 同上 |
| `commands/secreview.md` | 同上 | 同上 |
| `skills/secguard/*/SKILL.md` | Phase 5 增加"输出完整性要求"章节 | 明确每个 finding 必须字段 |
| `skills/secaudit/*/SKILL.md` | 同上 | 同上 |
| `skills/secreview/*/SKILL.md` | 同上 | 同上 |

`knowledge/detectors/*.md` 无需改动——已有完整内容。

## 4. Phase 2：输出协议升级

### 4.1 scan-output.md v3.0

在 v2.0 基础上，report.md 模板中的 §4（详细发现）改为强制四段式结构：

```markdown
### {{ID}}: {{TITLE}}

## 📍 1. Location — 问题位置

| 属性 | 值 |
|------|-----|
| **严重度** | 🔴/🟠/🟡/🔵 (CVSS {{CVSS}}) |
| **CWE** | [{{CWE_ID}}](https://cwe.mitre.org/data/definitions/{{CWE_NUM}}.html) |
| **文件** | `{{FILE}}:{{LINE}}` |
| **函数** | `{{FUNCTION}}()` |
| **代码** | `{{VULNERABLE_LINE}}` |
| **检测器** | `{{NAMESPACE}}.{{DETECTOR}}` |
| **置信度** | {{CONFIDENCE}} — {{CONFIDENCE_REASON}} |

## 📋 2. Evidence — 证据链

**判定依据**: {{WHY_THIS_IS_A_FINDING}}

**代码上下文**:
```{{LANGUAGE}}
// {{FILE}}:{{START_LINE}}-{{END_LINE}}  {{FUNCTION}}()
... // 前 2-3 行
{{VULNERABLE_LINE}}     // ← 漏洞点
... // 后 2-3 行
```

**数据流路径** (如适用):
`{{SOURCE}}` → `{{PROPAGATION}}` → `{{SINK}}` → {{CONSEQUENCE}}

## ⚠️ 3. Impact — 影响评估

**攻击场景**: {{ATTACK_SCENARIO}}

**CVSS 3.1**: {{CVSS_SCORE}} ({{CVSS_VECTOR}})

**利用条件**: {{EXPLOITABILITY}}

## 🔧 4. Fix — 修复方案

```{{LANGUAGE}}
// ❌ Before
{{CODE_BEFORE}}

// ✅ After
{{CODE_AFTER}}
```

| 属性 | 值 |
|------|-----|
| **工作量** | {{EFFORT}} |
| **回滚风险** | {{RISK}} |
| **验证方法** | {{VERIFICATION}} |

**参考资料**:
- [{{CWE_ID}}](https://cwe.mitre.org/data/definitions/{{CWE_NUM}}.html)
- [{{CERT_REF}}]({{CERT_URL}}) (如适用)
- [{{OWASP_REF}}]({{OWASP_URL}}) (如适用)
```

### 4.2 sarif-output.md v1.1

#### 4.2.1 新增字段要求

| 字段 | v1.0 状态 | v1.1 要求 | 说明 |
|------|----------|----------|------|
| `message.markdown` | 不存在 | **必须** | 完整四段式富文本 |
| `relatedLocations[]` | 不存在 | **必须**（如有数据流） | Source→Propagation→Sink |
| `taxa[]` | 不存在 | **必须** | CWE 分类信息 |
| `contextRegion` | 存在 | 增强（前后 3 行） | 更多上下文 |
| `fixes[]` | 存在 | 保持 | 不变 |
| `properties` | 存在 | 增强 | 增加 cvss/impact/effort/verification |

#### 4.2.2 message.markdown 模板

```markdown
## 📍 Location
| 属性 | 值 |
|------|-----|
| **文件** | `src/parser.c:42` |
| **函数** | `parse_input()` |
| **检测器** | `memory.buffer-overflow` |
| **CWE** | [CWE-120](https://cwe.mitre.org/data/definitions/120.html) |
| **CVSS** | 9.8 (Critical) |

## 📋 Evidence
{{判定依据说明}}

```c
// 代码上下文
char buf[64];
strcpy(buf, user_input);  // ← 漏洞点
process(buf);
```

**数据流**: `argv[1]` → `user_input` → `strcpy(buf, ...)` → 栈溢出

## ⚠️ Impact
{{攻击场景描述}}

**CVSS 3.1 Vector**: AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H

## 🔧 Fix
```c
// ❌ Before
strcpy(buf, user_input);

// ✅ After
strncpy(buf, user_input, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';
```

**工作量**: ~5 min | **风险**: 无 | **验证**: 输入 > 64 字节测试

**参考**: [CWE-120](https://cwe.mitre.org/data/definitions/120.html) | [SEI CERT STR31-C](https://wiki.sei.cmu.edu/confluence/x/1dUxBQ)
```

#### 4.2.3 SARIF result 完整结构

```json
{
  "ruleId": "SECGUARD-memory-buffer-overflow",
  "ruleIndex": 0,
  "level": "error",
  "message": {
    "text": "📍 parser.c:42 parse_input() [Critical] CWE-120: strcpy(buf, user_input) 缓冲区溢出 — user_input 来自 argv[1]，无长度检查",
    "markdown": "## 📍 Location\n\n| 属性 | 值 |\n|------|----|\n| **文件** | `src/parser.c:42` |\n..."
  },
  "locations": [{
    "physicalLocation": {
      "artifactLocation": { "uri": "src/parser.c", "uriBaseId": "%SRCROOT%" },
      "region": { "startLine": 42, "startColumn": 5, "endLine": 42, "endColumn": 35,
        "snippet": { "text": "    strcpy(buf, user_input);" } },
      "contextRegion": { "startLine": 39, "endLine": 45,
        "snippet": { "text": "char buf[64];\nif (input) {\n    strcpy(buf, user_input);\n    process(buf);\n}\n..." } }
    }
  }],
  "relatedLocations": [
    {
      "physicalLocation": {
        "artifactLocation": { "uri": "src/parser.c" },
        "region": { "startLine": 38, "snippet": { "text": "char buf[64];" } }
      },
      "message": { "text": "📋 目标缓冲区: 64字节栈缓冲区 buf" }
    },
    {
      "physicalLocation": {
        "artifactLocation": { "uri": "src/main.c" },
        "region": { "startLine": 15, "snippet": { "text": "parse_task_name(task, argv[1]);" } }
      },
      "message": { "text": "⬆️ Source: user_input = argv[1] (攻击者可控)" }
    }
  ],
  "fixes": [{
    "description": { "text": "将 strcpy 替换为 strncpy，确保 null 终止" },
    "artifactChanges": [{
      "artifactLocation": { "uri": "src/parser.c" },
      "replacements": [{
        "deletedRegion": { "startLine": 42, "startColumn": 5, "endLine": 42, "endColumn": 35 },
        "insertedContent": { "text": "strncpy(buf, user_input, sizeof(buf) - 1);\nbuf[sizeof(buf) - 1] = '\\0';" }
      }]
    }]
  }],
  "taxa": [{
    "id": "CWE-120",
    "name": "Buffer Copy without Checking Size of Input ('Classic Buffer Overflow')",
    "helpUri": "https://cwe.mitre.org/data/definitions/120.html"
  }],
  "properties": {
    "finding_id": "C-BOF-parser_c-L42",
    "confidence": "high",
    "cvss": "9.8",
    "cvss_vector": "AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
    "impact": "RCE via stack buffer overflow",
    "effort": "low",
    "risk_of_fix": "none",
    "verification": "Input > 64 bytes test",
    "detector_namespace": "memory",
    "detector_name": "buffer-overflow"
  },
  "partialFingerprints": {
    "primary": "sha1:C-BOF-parser_c-L42/strcpy/memory.buffer-overflow",
    "ruleLocation": "sha1:SECGUARD-memory-buffer-overflow/src/parser.c:42"
  }
}
```

#### 4.2.4 message.text 单行格式

```
📍 {FILE}:{LINE} {FUNCTION}() [{SEVERITY}] {CWE}: {ONE_LINE_DESCRIPTION} — {EVIDENCE_SUMMARY}
```

示例：
```
📍 parser.c:42 parse_input() [Critical] CWE-120: strcpy(buf, user_input) 缓冲区溢出 — user_input 来自 argv[1]，无长度检查
```

### 4.3 改动文件清单

| 文件 | 改动 | 版本变更 |
|------|------|---------|
| `knowledge/protocols/scan-output.md` | 升级到 v3.0，定义四段式结构和质量门禁 | v2.0 → v3.0 |
| `knowledge/protocols/sarif-output.md` | 升级到 v1.1，增加 message.markdown + relatedLocations + taxa 规范 | v1.0 → v1.1 |
| `commands/secguard.md` | Step 4 嵌入质量检查清单 + 四段式要求 | — |
| `commands/secaudit.md` | 同上 | — |
| `commands/secreview.md` | 同上 | — |
| `skills/secguard/*/SKILL.md` | Phase 5 增加输出完整性要求章节 | — |
| `skills/secaudit/*/SKILL.md` | 同上 | — |
| `skills/secreview/*/SKILL.md` | 同上 | — |

## 5. 验证方案

### 5.1 回归验证

重新扫描 `examples/cpp-vuln-demo`，验证：

1. **report.md 完整性**：每个 finding 包含四段式（📍📋⚠️🔧），无缺失小节
2. **SARIF 完整性**：每个 result 包含 `message.markdown`、`relatedLocations`、`taxa`
3. **SARIF Viewer 体验**：在 VS Code SARIF Explorer + GitHub Code Scanning 中查看效果
4. **对比报告**：与 Phase 1 前的 `sc-20260602-072257-7dcd/report.md` 对比质量提升

### 5.2 成功指标

- 100% 的 finding 满足四段式完整性（通过质量门禁）
- SARIF `message.markdown` 在 GitHub Code Scanning 中正确渲染
- SARIF `relatedLocations` 在 VS Code SARIF Explorer 中可点击导航
- 用户能从 report.md/SARIF 中看到一个漏洞的完整证据链和修复方案

## 6. 风险与约束

| 风险 | 缓解措施 |
|------|---------|
| AI agent 忽略质量检查清单 | 在清单中加入 "3次未通过则标注⚠️" 的兜底机制 |
| message.markdown 在不同 SARIF viewer 中渲染不一致 | 以 GitHub Code Scanning 为准，message.text 作为降级展示 |
| 协议版本升级导致旧版本消费者不兼容 | 保持向后兼容——只增加字段，不删除或重命名现有字段 |
| detector 内容未充分流入报告 | 在质量检查清单中明确要求引用 detector 的修复指引 |

## 7. 参考

- [SARIF 2.1.0 Specification (OASIS Standard)](https://docs.oasis-open.org/sarif/sarif/v2.1.0/)
- [GitHub Code Scanning SARIF 要求](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning)
- [CodeQL SARIF 输出参考](https://codeql.github.com/docs/codeql-overview/sarif-output/)
- [CWE Top 25 (2024)](https://cwe.mitre.org/top25/)
- [OWASP Top 10 (2021)](https://owasp.org/www-project-top-ten/)
- [CVSS 3.1 Specification](https://www.first.org/cvss/v3-1/)

---

## Phase 2: 输出协议 v5.0 — 目录树架构


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

*关联文档: [[2026-06-05-output-protocol-v3-design]], [[brainstorm-log]]*
