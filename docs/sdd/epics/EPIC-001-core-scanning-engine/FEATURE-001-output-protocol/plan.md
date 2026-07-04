# Output Protocol Evolution — 实施计划

> **Feature**: FEATURE-001-output-protocol
> **Epic**: EPIC-001-core-scanning-engine
> **状态**: ✅ 已完成
>
> 本计划覆盖输出协议演进的完整实施：Phase 1 (v3.0 四段式+SARI增强) → Phase 2 (v5.0 目录树架构)

---

## Phase 1: 输出协议 v3.0 重构实施

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
- [ ] §4 每个检出引用对应 detector 的修复指引（来自 `knowledge/guard-rules/<name>.md` 的 `## 修复指引` 节）
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

任一 ❌ → 定位缺失的 finding → 从 `knowledge/guard-rules/<name>.md` 的对应章节获取内容补充 → 重新检查。
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

在文件中找到 `> 遵循`knowledge/protocols/scan-output.md`(v2.0，人读/机读分离)。` 这行（约第 105 行），替换为：

```markdown
> **输出协议**: 遵循 `knowledge/protocols/scan-output.md`(v2.0，人读/机读分离)。
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

---

## Phase 2: Findings 目录树输出实施

**Goal:** 将 findings 输出从单体 `findings.json` 重构为按 detector 组织的目录树，使 AI Agent 可逐文件读写，消除大项目的 token 爆炸问题。

**Architecture:** `findings/<namespace>/<detector-name>/<finding-id>.json` — 每个 finding 一个独立文件（~2KB），文件名直接使用 finding ID（天然唯一，对齐 SARIF/CodeQL 业界实践），渲染器 `os.walk()` 遍历聚合，向后兼容 v4.0 单体格式。

**Tech Stack:** Python 3 stdlib（json, os, argparse, collections, hashlib），Markdown（命令文档）

**关联 Spec:** [spec.md §Phase 2](../spec.md)

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
> **v5.0 变更 (2026-06-07)**: 单体 findings.json 重构为按 detector 组织的目录树。参见: [spec.md §Phase 2](../spec.md)
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
- Modify: `docs/sdd/brainstorm-log.md`

- [ ] **Step 1: 在文件顶部（第一个日期标题之前）插入 v5.0 决策记录**

找到第一个 `## 2026-06-` 开头的标题，在其上方插入新的决策条目。

```bash
# 找到设计日志中第一个日期标题的行号
grep -n "^## 2026-06-03" docs/sdd/brainstorm-log.md
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

详见: [spec.md §Phase 2](../spec.md)

---
```

- [ ] **Step 2: Commit**

```bash
git add docs/sdd/brainstorm-log.md
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

*关联文档: [spec.md](../spec.md), [brainstorm-log](../../../brainstorm-log.md)*

### TASK-005: record-finding.py

AI 记录 finding 的辅助工具。详见 [tasks/TASK-005-record-finding-helper.md](tasks/TASK-005-record-finding-helper.md)。
