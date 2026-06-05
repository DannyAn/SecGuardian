# SecGuardian 输出协议 v3.0 重构设计

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
