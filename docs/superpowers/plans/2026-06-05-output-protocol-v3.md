# 输出协议 v3.0 重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将安全扫描输出从摘要型报告升级为完整的人读检视报告（四段式：Location → Evidence → Impact → Fix），同时优化 SARIF 以充分利用 message.markdown 和 relatedLocations。

**Architecture:** 两阶段实施。Phase 1 不改协议文件，在 3 个 command 指令中嵌入强制质量检查清单，确保 AI agent 每次输出完整四段式。Phase 2 升级 2 个协议文件（scan-output.md v3.0 + sarif-output.md v1.1），增加 message.markdown 模板和 relatedLocations 规范。Skill 文件仅需要在有输出阶段的部分添加引用，不需要大规模改写。

**Tech Stack:** Markdown templates, SARIF 2.1.0 JSON Schema, AI agent instruction engineering

**改动范围:** 3 个 command + 2 个协议 + 5 个 secguard skill + 5 个 secreview skill = 15 个文件（secguard skills 5 个已有输出阶段需要增强，secaudit 17 个 skill 通过 command 层质量门禁覆盖无需单独修改）

---

### Task 1: Phase 1 — 更新 commands/secguard.md Step 4 质量门禁

**Files:**
- Modify: `commands/secguard.md`

- [ ] **Step 1: 在 Step 4 的"保存检出并输出摘要"后追加质量检查清单**

当前文件在 `261` 行结束。在 `### Step 4: 保存检出并输出摘要` 的末尾、下一个 `##` 节之前插入质量检查清单。找到 Step 4 中第 260 行附近 `- 向用户输出 Markdown 格式的扫描摘要...` 之后追加。

需要添加的内容（在第 260 行 `- 向用户输出 Markdown 格式的扫描摘要` 之后插入）：

```markdown

### Step 4b: 输出前质量检查（必须执行，不可跳过）

在写入 report.md 和 results.sarif 之前，逐项验证每个检出的完整性。**任一 ❌ → 补充缺失内容 → 重新检查，最多 3 次。**

#### report.md 质量门禁

- [ ] §3 检出清单每个条目包含：ID | 严重度 | CWE | 文件:行 | 标题
- [ ] §4 每个检出包含 **📍 Location** 小节（文件路径 + 行号 + 函数名 + 具体代码行）
- [ ] §4 每个检出包含 **📋 Evidence** 小节（代码上下文 3+ 行 + 判定依据 + 数据流路径）
- [ ] §4 每个检出包含 **⚠️ Impact** 小节（攻击场景描述 + CVSS 3.1 评分 + 利用条件）
- [ ] §4 每个检出包含 **🔧 Fix** 小节（before/after 代码 + 工作量 + 验证方法）
- [ ] §4 每个检出引用对应 detector 的修复指引（来自 `knowledge/detectors/<name>.md` 的 `## 修复指引` 节）
- [ ] §4 每个检出包含 CWE 参考链接
- [ ] §5 修复路线图包含 Phase 1-4 完整四个阶段（含预估工时）

#### SARIF 质量门禁

- [ ] 每个 result 的 `message.text` 以 📍 开头，一句话包含：文件:行 函数名 [严重度] CWE-ID: 标题 — 判定摘要
- [ ] 每个 result 包含 `message.markdown`（完整四段式富文本：📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）
- [ ] 每个 result 包含 `relatedLocations[]`（标注 Source → Propagation → Sink 数据流路径，如适用）
- [ ] 每个 result 包含 `fixes[]`（before/after 代码替换，含 description）
- [ ] 每个 result 包含 `partialFingerprints`（`primary` 指纹用于去重）
- [ ] 每个 result 的 `properties` 包含：`confidence`, `cvss`, `cvss_vector`, `impact`, `effort`, `risk_of_fix`, `verification`, `detector_namespace`
- [ ] `driver.rules[]` 每个 rule 包含 CWE 分类信息

#### 未通过处理

任一 ❌ → 定位缺失的 finding → 从 `knowledge/detectors/<name>.md` 的对应章节获取内容补充 → 重新检查。
3 次后仍未通过 → 在 report.md 开头标注 "⚠️ 以下发现的完整性未完全达标: <ID列表>"
```

- [ ] **Step 2: 验证改动**

```bash
grep -c "质量门禁" commands/secguard.md
```
Expected: >= 2 (report.md 质量门禁 + SARIF 质量门禁)

- [ ] **Step 3: Commit**

```bash
git add commands/secguard.md
git commit -m "feat(secguard): add output quality gate checklist to Step 4

- Mandate four-segment finding format: Location → Evidence → Impact → Fix
- Add SARIF quality gates: message.markdown, relatedLocations, properties
- Max 3 retry on quality check failure

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Phase 1 — 更新 commands/secaudit.md Step 4 质量门禁

**Files:**
- Modify: `commands/secaudit.md`

- [ ] **Step 1: 在 Step 4 的"保存检出并输出摘要"后追加质量检查清单**

在 `### Step 4: 保存检出并输出摘要` 的末尾（第 229 行附近 `- 向用户展示审计发现和审计摘要。` 之后）插入与 Task 1 相同的质量检查清单。

```markdown

### Step 4b: 输出前质量检查（必须执行，不可跳过）

在写入 report.md 和 results.sarif 之前，逐项验证每个检出的完整性。**任一 ❌ → 补充缺失内容 → 重新检查，最多 3 次。**

#### report.md 质量门禁

- [ ] §3 检出清单每个条目包含：ID | 严重度 | CWE | 文件:行 | 标题
- [ ] §4 每个检出包含 **📍 Location** 小节（文件路径 + 行号 + 函数名 + 具体代码行）
- [ ] §4 每个检出包含 **📋 Evidence** 小节（代码上下文 3+ 行 + 判定依据 + 数据流路径）
- [ ] §4 每个检出包含 **⚠️ Impact** 小节（攻击场景描述 + CVSS 3.1 评分 + 利用条件）
- [ ] §4 每个检出包含 **🔧 Fix** 小节（before/after 代码 + 工作量 + 验证方法）
- [ ] §4 每个检出包含 CWE 参考链接和对应审计 skill 的分析引用
- [ ] §5 修复路线图包含 Phase 1-4 完整四个阶段（含预估工时）

#### SARIF 质量门禁

- [ ] 每个 result 的 `message.text` 以 📍 开头，一句话包含：文件:行 函数名 [严重度] CWE-ID: 标题 — 判定摘要
- [ ] 每个 result 包含 `message.markdown`（完整四段式富文本：📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）
- [ ] 每个 result 包含 `relatedLocations[]`（标注 Source → Propagation → Sink 数据流路径）
- [ ] 每个 result 包含 `fixes[]`（before/after 代码替换，含 description）
- [ ] 每个 result 包含 `partialFingerprints`（`primary` 指纹用于去重）
- [ ] 每个 result 的 `properties` 包含：`confidence`, `cvss`, `cvss_vector`, `impact`, `effort`, `risk_of_fix`, `verification`, `detector_namespace`
- [ ] `driver.rules[]` 每个 rule 包含 CWE 分类信息

#### 未通过处理

任一 ❌ → 定位缺失的 finding → 补充对应内容 → 重新检查。
3 次后仍未通过 → 在 report.md 开头标注 "⚠️ 以下发现的完整性未完全达标: <ID列表>"
```

- [ ] **Step 2: 验证改动**

```bash
grep -c "质量门禁" commands/secaudit.md
```
Expected: >= 2

- [ ] **Step 3: Commit**

```bash
git add commands/secaudit.md
git commit -m "feat(secaudit): add output quality gate checklist to Step 4

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Phase 1 — 更新 commands/secreview.md Step 4 质量门禁

**Files:**
- Modify: `commands/secreview.md`

- [ ] **Step 1: 在 Step 4 的"保存检出并输出摘要"后追加质量检查清单**

在 `### Step 4: 保存检出并输出摘要` 的末尾（第 210 行附近 `- 向用户展示检视发现和检视摘要。` 之后）插入质量检查清单。注意 secreview 的语义差异：检出项称为"不合规项"而非"漏洞"，CWE 映射可能不适用时标注 "N/A（编码规范）"。

```markdown

### Step 4b: 输出前质量检查（必须执行，不可跳过）

在写入 report.md 和 results.sarif 之前，逐项验证每个检出的完整性。**任一 ❌ → 补充缺失内容 → 重新检查，最多 3 次。**

#### report.md 质量门禁

- [ ] §3 检出清单每个条目包含：ID | 严重度 | 类别 | 文件:行 | 标题
- [ ] §4 每个检出包含 **📍 Location** 小节（文件路径 + 行号 + 函数名 + 具体代码行）
- [ ] §4 每个检出包含 **📋 Evidence** 小节（代码上下文 3+ 行 + 判定依据 — 指出违反了哪条安全编码规范）
- [ ] §4 每个检出包含 **⚠️ Impact** 小节（不合规可能导致的潜在安全风险 + 适用场景）
- [ ] §4 每个检出包含 **🔧 Fix** 小节（before/after 代码 + 工作量 + 验证方法）
- [ ] §4 每个检出包含对应语言的反模式检测矩阵引用和修复指引
- [ ] §4 每个检出包含参考链接（SEI CERT / OWASP / 语言安全指南）
- [ ] §5 修复路线图包含 Phase 1-4 完整四个阶段（含预估工时）

#### SARIF 质量门禁

- [ ] 每个 result 的 `message.text` 以 📍 开头，一句话包含：文件:行 函数名 [严重度] 类别: 标题 — 判定摘要
- [ ] 每个 result 包含 `message.markdown`（完整四段式富文本：📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）
- [ ] 每个 result 包含 `relatedLocations[]`（如涉及多处代码上下文）
- [ ] 每个 result 包含 `fixes[]`（before/after 代码替换，含 description）
- [ ] 每个 result 包含 `partialFingerprints`（`primary` 指纹用于去重）
- [ ] 每个 result 的 `properties` 包含：`confidence`, `impact`, `effort`, `risk_of_fix`, `verification`, `category`
- [ ] `driver.rules[]` 每个 rule 包含 SEI CERT / OWASP 分类引用

#### 未通过处理

任一 ❌ → 定位缺失的 finding → 补充对应内容 → 重新检查。
3 次后仍未通过 → 在 report.md 开头标注 "⚠️ 以下发现的完整性未完全达标: <ID列表>"
```

- [ ] **Step 2: 验证改动**

```bash
grep -c "质量门禁" commands/secreview.md
```
Expected: >= 2

- [ ] **Step 3: Commit**

```bash
git add commands/secreview.md
git commit -m "feat(secreview): add output quality gate checklist to Step 4

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Phase 1 — 更新 secguard skills 输出完整性要求

**Files:**
- Modify: `skills/secguard/cpp/SKILL.md` (Phase 5 已有，增强)
- Modify: `skills/secguard/go/SKILL.md`
- Modify: `skills/secguard/java/SKILL.md`
- Modify: `skills/secguard/js/SKILL.md`
- Modify: `skills/secguard/python/SKILL.md`

- [ ] **Step 1: 更新 skills/secguard/cpp/SKILL.md 的 Phase 5**

当前 `skills/secguard/cpp/SKILL.md` 第 107 行有 `### Phase 5: 持久化输出`。在其 `遵循...` 行之后增加完整性要求段落：

在文件中找到 `> 遵循 `knowledge/protocols/scan-output.md` (v2.0，人读/机读分离)。` 这行（约第 105 行），替换为：

```markdown
> **输出协议**: 遵循 `knowledge/protocols/scan-output.md` (v2.0，人读/机读分离)。
>
> **每个检出必须满足四段式完整性**（Command 层 Step 4b 质量门禁强制检查）：
> 1. **📍 Location** — 文件路径 + 行号 + 函数名 + 代码行内容
> 2. **📋 Evidence** — 代码上下文（前后 3 行）+ 判定依据（引用 detector 的检测逻辑）+ 数据流路径
> 3. **⚠️ Impact** — 攻击场景描述 + CVSS 3.1 评分 + 利用条件
> 4. **🔧 Fix** — Before/After 代码 + 工作量 + 验证方法 + CWE 参考链接
>
> SARIF 结果同样要求：`message.markdown` 包含完整四段式，`relatedLocations` 标注 Source → Sink 路径，`fixes` 包含 before/after 替换。
```

- [ ] **Step 2: 对其他 4 个 secguard skill 做相同更新**

以下 4 个文件需要相同的完整性要求段落（替换其输出协议引用行）：
- `skills/secguard/go/SKILL.md`
- `skills/secguard/java/SKILL.md`
- `skills/secguard/js/SKILL.md`
- `skills/secguard/python/SKILL.md`

对于每个文件，找到包含 `knowledge/protocols/scan-output.md` 的行，在其后追加四段式完整性要求。

```bash
# 检查每个文件是否已有输出协议引用
for f in skills/secguard/go/SKILL.md skills/secguard/java/SKILL.md skills/secguard/js/SKILL.md skills/secguard/python/SKILL.md; do
  echo "=== $f ==="
  grep -n "scan-output\|输出" "$f" | head -5
done
```

根据每个文件的结构，在输出协议引用后追加与 cpp/SKILL.md 相同的四段式完整性要求段落。

- [ ] **Step 3: 验证改动**

```bash
# 每个文件都应包含四段式完整性要求
for f in skills/secguard/*/SKILL.md; do
  echo "=== $f ==="
  grep -c "Location\|Evidence\|Impact\|Fix" "$f"
done
```
Expected: 每个文件 >= 4 (Location, Evidence, Impact, Fix 各至少出现一次)

- [ ] **Step 4: Commit**

```bash
git add skills/secguard/
git commit -m "feat(secguard-skills): add four-segment output completeness requirements

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Phase 1 — 更新 secreview skills 输出完整性要求

**Files:**
- Modify: `skills/secreview/cpp/SKILL.md`
- Modify: `skills/secreview/go/SKILL.md`
- Modify: `skills/secreview/java/SKILL.md`
- Modify: `skills/secreview/js/SKILL.md`
- Modify: `skills/secreview/python/SKILL.md`

- [ ] **Step 1: 在每个 secreview skill 中添加输出完整性要求**

每个 secreview skill 的结构通常为：前置条件 → 执行流程（多个 Phase）→ 结尾。在最后一个 Phase 之后、文件末尾之前插入：

```markdown

## 输出完整性要求

> **输出协议**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。
>
> Command 层 Step 4b 质量门禁强制检查每个检出的四段式完整性：
> 1. **📍 Location** — 文件路径 + 行号 + 函数名 + 违规代码行
> 2. **📋 Evidence** — 代码上下文（前后 3 行）+ 判定依据（指出违反的安全编码规范条款）
> 3. **⚠️ Impact** — 不合规可能导致的安全风险 + 适用攻击场景
> 4. **🔧 Fix** — Before/After 代码 + 工作量 + 验证方法 + SEI CERT/OWASP 参考链接
>
> SARIF 结果同样要求：`message.markdown` 包含完整四段式，`relatedLocations` 标注关联代码位置，`fixes` 包含 before/after 替换。
```

- [ ] **Step 2: 验证改动**

```bash
for f in skills/secreview/*/SKILL.md; do
  echo "=== $f ==="
  grep -c "四段式\|Location.*Evidence.*Impact.*Fix" "$f"
done
```
Expected: 每个文件 >= 1

- [ ] **Step 3: Commit**

```bash
git add skills/secreview/
git commit -m "feat(secreview-skills): add four-segment output completeness requirements

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Phase 2 — 升级 knowledge/protocols/scan-output.md 到 v3.0

**Files:**
- Modify: `knowledge/protocols/scan-output.md`

- [ ] **Step 1: 更新版本号和设计原则表**

将文件头部的 `version: "2.0"` 改为 `"3.0"`。在 `## 设计原则` 表格后增加新行说明 v3.0 变更：

```markdown
> **v3.0 变更 (2026-06-05)**: report.md §4 详细发现改为强制四段式结构（📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）。增加输出前质量门禁（Step 4b）。SARIF 增加 `message.markdown` 和 `relatedLocations` 要求。
```

- [ ] **Step 2: 替换 §4 详细发现模板**

将 `### 完整模板` 中的 §4 部分（第 146-193 行，从 `## 4. 详细发现` 到 `---` 分隔符之前）替换为新的四段式模板：

```markdown
## 4. 详细发现

每个检出按以下四段式结构展示。**每个段为强制项**，质量门禁（Step 4b）逐项验证。

### {{ID}}: {{TITLE}}

### 📍 1. Location — 问题位置

| 属性 | 值 |
|------|-----|
| **严重度** | {{SEVERITY_EMOJI}} {{SEVERITY_LABEL}} (CVSS {{CVSS}}) |
| **CWE** | [{{CWE_ID}}](https://cwe.mitre.org/data/definitions/{{CWE_NUM}}.html) |
| **文件** | `{{FILE}}:{{LINE}}` |
| **函数** | `{{FUNCTION}}()` |
| **代码** | `{{VULNERABLE_LINE}}` |
| **检测器** | `{{NAMESPACE}}.{{DETECTOR}}` |
| **置信度** | {{CONFIDENCE}} — {{CONFIDENCE_REASON}} |

### 📋 2. Evidence — 证据链

**判定依据**: {{WHY_THIS_IS_A_FINDING}}（引用 detector 的检测逻辑）

**代码上下文**:

```{{LANGUAGE}}
// {{FILE}}:{{CONTEXT_START}}-{{CONTEXT_END}}  {{FUNCTION}}()
... // 前 2-3 行上下文
{{VULNERABLE_LINE}}     // ← 漏洞点
... // 后 2-3 行上下文
```

**数据流路径** (如适用):

`{{SOURCE}}` → `{{PROPAGATION}}` → `{{SINK}}` → {{CONSEQUENCE}}

### ⚠️ 3. Impact — 影响评估

**攻击场景**: {{ATTACK_SCENARIO}}

**CVSS 3.1**: {{CVSS_SCORE}} — {{CVSS_VECTOR_STRING}}

**利用条件**: {{EXPLOITABILITY}}

### 🔧 4. Fix — 修复方案

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
- {{CERT_REF}} (如适用)
- {{OWASP_REF}} (如适用)

---
```

- [ ] **Step 3: 更新生成规则引用**

在 `### 生成规则` 中，将第 261-266 行的规则 2 更新为：

```markdown
2. **每个检出必须包含完整四段式** — 📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix，来自 detector 的 `## 检测逻辑` 和 `## 修复指引` 节
```

并在末尾增加规则 6：

```markdown
6. **质量门禁强制执行** — 写入报告前执行 Step 4b 检查清单，每个 finding 四段式完整性不达标则补充后重试（最多 3 次）
```

- [ ] **Step 4: 更新协议演进节**

在 `## 协议演进` 最前面新增 v3.0 条目：

```markdown
- **3.0** (当前): report.md §4 强制四段式结构（📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）。增加质量门禁（Step 4b）。SARIF 要求 `message.markdown` + `relatedLocations`。
```

- [ ] **Step 5: 验证改动**

```bash
grep -c "四段式\|Location.*Evidence.*Impact.*Fix\|质量门禁" knowledge/protocols/scan-output.md
```
Expected: >= 3

- [ ] **Step 6: Commit**

```bash
git add knowledge/protocols/scan-output.md
git commit -m "feat(protocol): upgrade scan-output.md to v3.0

- Mandate four-segment finding format: Location → Evidence → Impact → Fix
- Add quality gate requirement (Step 4b)
- Update generation rules and evolution section

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Phase 2 — 升级 knowledge/protocols/sarif-output.md 到 v1.1

**Files:**
- Modify: `knowledge/protocols/sarif-output.md`

- [ ] **Step 1: 更新版本号和新增 message.markdown 规范**

将文件头部的 `version: "1.0"` 改为 `"1.1"`。在 `## SARIF Schema 完整示例` 之前插入新节：

```markdown
## v1.1 新增要求

| 字段 | v1.0 状态 | v1.1 要求 | 说明 |
|------|----------|----------|------|
| `message.markdown` | 不存在 | **必须** | 完整四段式富文本（📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix） |
| `relatedLocations[]` | 不存在 | **必须**（如有数据流） | Source → Propagation → Sink 路径标注 |
| `taxa[]` | 不存在 | 推荐 | CWE 分类引用 |
| `contextRegion` | 已支持 | 增强（前后 3 行） | 更多代码上下文 |
| `properties` | 已支持 | 增强 | 增加 `cvss_vector`, `verification` |

### message.markdown 模板

每个 result 的 `message.markdown` 必须包含完整四段式，格式如下：

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
// 代码上下文（前后 3 行）
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
```

- [ ] **Step 2: 更新 message.text 格式规范**

在 `## SARIF 字段映射速查` 表中更新 `message.text` 行：

```markdown
| `title` | `message.text` (格式: `📍 {FILE}:{LINE} {FUNC}() [{SEVERITY}] {CWE}: {TITLE} — {EVIDENCE_SUMMARY}`，SARIF viewer 主要展示) |
```

- [ ] **Step 3: 更新 SARIF Schema 完整示例中的 result**

在示例的 `results[]` 中，将当前的 `message: { "text": "..." }` 更新为包含 `markdown` 的版本：

```json
"message": {
  "text": "📍 src/parser.c:42 parse_input() [Critical] CWE-120: strcpy(buf, user_input) 缓冲区溢出 — user_input 来自 argv[1]，无长度检查",
  "markdown": "## 📍 Location\n\n| 属性 | 值 |\n|------|----|\n| **文件** | `src/parser.c:42` |\n| **函数** | `parse_input()` |\n| **CWE** | [CWE-120](https://cwe.mitre.org/data/definitions/120.html) |\n| **CVSS** | 9.8 (Critical) |\n\n## 📋 Evidence\n\n**判定依据**: `strcpy()` 的目标缓冲区 `buf[64]` 是固定大小栈缓冲区，源 `user_input` 来自 `argv[1]`（攻击者完全可控），拷贝无任何长度检查。\n\n```c\nchar buf[64];\nstrcpy(buf, user_input);  // ← 漏洞点\nprocess(buf);\n```\n\n**数据流**: `argv[1]` → `user_input` → `strcpy(buf, ...)` → 栈溢出\n\n## ⚠️ Impact\n\n攻击者可构造超长输入（>64字节）覆盖栈帧返回地址 → **远程代码执行 (RCE)**。\n\n**CVSS 3.1**: 9.8 (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H)\n\n## 🔧 Fix\n\n```c\n// ❌ Before\nstrcpy(buf, user_input);\n\n// ✅ After\nstrncpy(buf, user_input, sizeof(buf) - 1);\nbuf[sizeof(buf) - 1] = '\\0';\n```\n\n**工作量**: ~5 min | **风险**: 无 | **验证**: 输入 > 64 字节测试 | **参考**: [CWE-120](https://cwe.mitre.org/data/definitions/120.html) | [SEI CERT STR31-C](https://wiki.sei.cmu.edu/confluence/x/1dUxBQ)"
}
```

同时为示例中第二个 result 也添加 `markdown` 字段。为每个 result 增加 `relatedLocations` 示例：

```json
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
      "region": { "startLine": 15, "snippet": { "text": "parse_input(argv[1]);" } }
    },
    "message": { "text": "⬆️ Source: user_input = argv[1] (攻击者可控)" }
  }
]
```

- [ ] **Step 4: 更新生成规则**

在 `## 生成规则` 中增加规则 6：

```markdown
6. **message.markdown 必须包含完整四段式** — 格式见上文 `message.markdown 模板`，不可省略任何一段
```

- [ ] **Step 5: 验证改动**

```bash
grep -c "message.markdown\|relatedLocations\|四段式\|v1.1" knowledge/protocols/sarif-output.md
```
Expected: >= 4

- [ ] **Step 6: Commit**

```bash
git add knowledge/protocols/sarif-output.md
git commit -m "feat(protocol): upgrade sarif-output.md to v1.1

- Add message.markdown requirement with four-segment template
- Add relatedLocations for Source → Sink data flow
- Update message.text format to include Location prefix
- Add taxa CWE classification support

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Phase 2 — 更新 commands 引用协议版本

**Files:**
- Modify: `commands/secguard.md`
- Modify: `commands/secaudit.md`
- Modify: `commands/secreview.md`

- [ ] **Step 1: 更新三个 command 中的协议版本引用**

对于每个文件，将 `Scan Output Protocol 2.0` 替换为 `Scan Output Protocol 3.0`：

```bash
# 替换所有引用
for f in commands/secguard.md commands/secaudit.md commands/secreview.md; do
  sed -i '' 's/Scan Output Protocol 2\.0/Scan Output Protocol 3.0/g' "$f"
  sed -i '' 's/scan-output\.md) (v2\.0/scan-output.md) (v3.0/g' "$f"
done
```

- [ ] **Step 2: 验证改动**

```bash
grep "Protocol 2.0\|v2.0" commands/*.md
```
Expected: 无输出（所有 v2.0 引用已替换为 v3.0）

```bash
grep "Protocol 3.0\|v3.0" commands/*.md | wc -l
```
Expected: >= 3 （每个文件至少一个引用）

- [ ] **Step 3: Commit**

```bash
git add commands/secguard.md commands/secaudit.md commands/secreview.md
git commit -m "chore(commands): bump protocol references from v2.0 to v3.0

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: Phase 1 — 更新 secguard 摘要模板中四段式描述

**Files:**
- Modify: `commands/secguard.md`

- [ ] **Step 1: 更新命令摘要输出中的提示文字**

在 `commands/secguard.md` 的输出摘要提示部分（第 79-82 行附近），更新"如何使用扫描结果"文字，增加四段式说明：

找到：
```markdown
💡 **如何使用扫描结果？**
- **快速看汇总** → 打开 `manifest.json`（JSON 索引，列出所有检出 ID/严重度/文件）
- **看详情 + 改代码** → 打开 `report.md`（每个检出含证据链 + before/after 修复代码）
- **CI/CD 集成** → 消费 `results.sarif`（GitHub Code Scanning / GitLab SAST / Azure DevOps）
- **AI Agent 修复** → 告诉 AI：`读取 report.md，按修复方案修改代码`（修复方案来自 detector 的 FIX 指引，可直接执行）
```

替换为：
```markdown
💡 **如何使用扫描结果？**
- **快速看汇总** → 打开 `manifest.json`（JSON 索引，列出所有检出 ID/严重度/文件/行号）
- **★ 人读检视报告** → 打开 `report.md`（每个检出含完整四段式：📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）
- **CI/CD 集成** → 消费 `results.sarif`（GitHub Code Scanning / GitLab SAST / Azure DevOps）
- **AI Agent 修复** → 告诉 AI：`读取 report.md §4，按每个发现的 🔧 Fix 方案修改代码`
```

- [ ] **Step 2: 对 secaudit.md 和 secreview.md 做相同更新**

类似地更新另外两个 command 中的输出摘要提示。

- [ ] **Step 3: Commit**

```bash
git add commands/
git commit -m "docs(commands): update scan result usage tips with four-segment format

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 10: 验证 — 检查全部改动的完整性

**Files:**
- 所有已修改文件

- [ ] **Step 1: 运行 lint 检查（如有）**

```bash
# 检查 Markdown lint（如果项目已配置）
if [ -f .markdownlint.jsonc ]; then
  npx markdownlint-cli2 commands/*.md knowledge/protocols/*.md "skills/**/SKILL.md" 2>&1 | tail -5
fi
```

- [ ] **Step 2: 验证关键 grep 检查**

```bash
echo "=== 1. 四段式完整性引用计数 ==="
grep -r "Location.*Evidence.*Impact.*Fix\|📍.*📋.*⚠️.*🔧" commands/ knowledge/protocols/ --include="*.md" | wc -l

echo "=== 2. 质量门禁引用 ==="
grep -rl "质量门禁\|质量检查" commands/ knowledge/protocols/ skills/ --include="*.md" | wc -l

echo "=== 3. message.markdown 引用 ==="
grep -r "message.markdown" knowledge/protocols/ commands/ --include="*.md" | wc -l

echo "=== 4. relatedLocations 引用 ==="
grep -r "relatedLocations" knowledge/protocols/ commands/ --include="*.md" | wc -l

echo "=== 5. 残留 v2.0 引用（应为 0）==="
grep -r "v2\.0\|2\.0" commands/ --include="*.md" | grep -i "protocol\|scan.output" | wc -l
```

Expected:
- (1) >= 3
- (2) >= 5 (3 commands + 2 protocols at minimum)
- (3) >= 2 (sarif-output.md + commands referencing it)
- (4) >= 2
- (5) = 0

- [ ] **Step 3: 查看 git diff 统计**

```bash
git diff --stat HEAD
```

- [ ] **Step 4: Commit 最终验证**

```bash
git add -A
git diff --cached --stat
```

---

## 实施顺序

```
Task 1 → Task 2 → Task 3     (并行: 3 个 command 质量门禁)
    ↓
Task 4 → Task 5               (并行: secguard + secreview skills)
    ↓
Task 6 → Task 7               (并行: 2 个协议升级)
    ↓
Task 8 → Task 9               (顺序: 协议引用更新 + 提示文字)
    ↓
Task 10                       (验证)
```

**预计总时间**: 2-3 小时
