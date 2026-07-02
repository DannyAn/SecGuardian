# SecGuardian 设计决策日志

> 记录项目架构演进过程中的关键头脑风暴、设计权衡和最终方案。
> 按时间倒序排列，最新讨论在前。

---

## 2026-06-28 — Finding ID 重构 + 安全评分修复（Java 扫描实测发现）

### 背景

2026-06-27 对 `/Users/kongan/workbench/gitee/pkmhipster/main/src` 执行 `/secguard ./src java` 扫描，检出 26 个发现（8 Critical + 6 High + 12 Medium）。
扫描输出暴露两个关联问题：所有 Finding 的 `id` 字段显示 "placeholder"，安全评分显示 0/100。

### 讨论要点

#### 1. Finding ID 双重问题

**Bug**: AI Agent 写入 individual finding 文件时 `id` 填的是 `placeholder`，renderer 走 `--findings-dir` 加载后全显 placeholder。
`findings_index` 中 ID 正确（如 `C-SQL-I-QuestionMapper-L70`），但 v5.0 路径不消费索引中的 ID。

**设计问题**: 即使 ID 正确，格式 `C-SQL-I-QuestionMapper-L70` 也是工程师认知负担：
- 缩写不统一（`H-WEAK--SysUserApplicationService-L127` 出现双连字符）
- 行号不稳定，代码插入一行即失效
- 试图同时做机器标识 + 人读引用，两件事都做不好

#### 2. 新 Finding Identity 设计

参照 SARIF 2.1.0 哲学，采用分层方案：

| 职责 | 机制 | 说明 |
|------|------|------|
| 跨扫描去重 | SHA-256(`detector:file:line:cwe`) | 前 12 hex chars 做文件名 |
| 人读定位 | `_${file_slug}-${line}` 后缀 | 文件名后附加可读部分 |
| 人读引用 | 序号 `#1` ~ `#N` | 每次扫描按 severity→file→line 排序 |
| 报告展示 | 序号 + detector + file:line + title | 不再展示 ID 列 |
| SARIF 对齐 | `partialFingerprints` = 同一 SHA | 符合 OASIS 标准 |

**选中方案**: `f42ce940c35c_SignatureUtils-35.json`
- 前 12 位 SHA 前缀 → 去重 + 跨扫描稳定
- `_SignatureUtils-35` → 工程师快速定位
- 目录树已含 detector 命名空间（`findings/crypto/hardcoded-secrets/`）

**否决的方案**:
- **纯 SHA**（`f42ce940c35c.json`）: ls 查看无任何上下文
- **SHA-CWE-file**（`f42ce940c35c_798-SignatureUtils-35.json`）: CWE 编号需要查表，信息密度低
- **旧格式修修补补**: 缩写规则无论如何也做不到紧凑且可读

#### 3. 安全评分问题

Source 代码 renderer 已有指数衰减公式 `100 × exp(-0.2C - 0.1H - 0.04M - 0.01L)`，
对该扫描本应产出 7/100（已确认），但产出 0/100。

**根因**: AI Agent 在 `findings.json` 中写死 `security_score: 0`。虽然 `generate_summary` 和 `generate_status` 会从 findings 列表重新计算评分，但部署管线的某个环节绕过了 renderer 的计算。

**修复方向**:
- 从 `findings.json` 模板中移除 `security_score` 字段（AI 不负责评分）
- Renderer 始终从 findings 列表计算评分
- 确认 `calc_score` 使用的指数衰减公式已部署

### 最终方案

本次特性以 **FEATURE-006-finding-identity-redesign** 立项，覆盖 Finding Identity 重构 + 评分修复，隶属 EPIC-001 Core Scanning Engine。

### 影响范围

（待 spec 详细定义）
- `scripts/render-report.py` — 移除 `security_score` override、manifest/report 改用序号+SHA
- `knowledge/protocols/scan-output.md` — 更新文件命名 + finding 结构
- `commands/secguard.md` / `secaudit.md` / `secreview.md` — 更新 ID 格式描述 + 模板
- `skills/secguard/*/SKILL.md` — 更新 AI 写入 finding 的指令
- `scripts/validate-findings.py` — 更新 schema（id 字段不再强制）

---

## 2026-06-27 — 索引器容错与扫描可靠性系统性缺陷（Java 扫描实测回溯）

#

## 2026-06-21 — 命令接口统一 + SecAudit 工作流旗舰化 + Detector 索引自动生成

## 背景

2026-06-27 对 `/Users/kongan/workbench/gitee/pkmhipster/main/src` 执行 `/secguard ./src java` 扫描。225 个 Java 文件（Spring Boot + MyBatis 后端），含 `src/main/resources/static/` 前端的 Vue/React minified JS bundle。

扫描总耗时 ~18 分钟，其中索引器因 JS bundle 超时 2 次浪费 ~10 分钟。

### 讨论要点

会话分析发现 8 个设计缺陷。按影响面从大到小：

| # | 缺陷 | 根因 | 影响范围 |
|---|------|------|---------|
| 1 | `--lang` 参数未传递 | 所有 SKILL.md Step 2 写死 `$INDEXER --path --output`，没有 `--lang $language`。5 个语言的 SKILL.md 都缺 | 每次扫描：auto 模式把无关文件也解析 |
| 2 | validate 脚本未打包 | `package.sh` 未拷贝 `validate-index.py` / `validate-findings.py` 到 dist/，SKILL.md 引用的验证步骤不可执行 | 验证管道形同虚设 |
| 3 | guard-rules 未部署 | dist/ 有但 `~/.config/opencode/extensions/secguardian/` 没有 `knowledge/guard-rules/`，AI 无法加载 67 个检测器定义 | AI 只能凭 detector 名字推测规则 |
| 4 | 安全评分无区分度 | `100 - 25×Crit - 10×High - 3×Med` → 9Crit+5High+3Med = 0/100，与 15Crit 结果一样 F | 安全评分失去表达力 |
| 5 | JS minified bundle 无限制 | `parser_javascript.go` 正则解析，对 >4000 函数单文件无上限 | 索引器在含前端项目上必卡 |
| 6 | index.json 缺聚合字段 | 顶层只有 path/files/symbols/call_graph/alloc_free/lock_graph，无 file_count/function_count 等 | AI 每次手工算，易错 |
| 7 | `--no-verify` CLI 未定义 | Step 3.5 提到该 flag 但参数解析指令无处理逻辑 | 功能存在但不可用 |
| 8 | 索引器 auto 模式路径排除不全 | 缺 `target/`、`build/`、`static/`、`public/` | Java/Gradle 项目 + 前端项目易中 |

### 回溯：为什么 C/Python/Go 没发现 `--lang` 缺失

这是系统性问题——5 个语言 SKILL.md 的 Step 2 都缺少 `--lang` 传参。C/Python/Go 没触发的原因：

- **C**: 源码树通常只有 `.c` / `.h`，auto 模式无副作用
- **Python**: 偶尔有少量 JS，但不会是 minified bundle，解析迅速
- **Go**: 源码树干净，auto 模式直接匹配 `.go`
- **Java** (首次暴露): `src/main/resources/static/` 含 Vue/React build artifact — `chunk-libs.dc48dc82.js` 单文件 4418 函数，正则解析器卡死 → 超时 → AI 才意识到要用 `--lang java`

**结论**：不是 Java 特有问题，是所有语言的 SKILL.md 都有这个 bug。Java 项目的特定目录结构让它第一个暴露。

### 最终方案

拆成 3 个 Feature Package 并行推进：

| Feature | 范围 | 归属 Epic |
|---------|------|----------|
| **FEATURE-005: Indexer Robustness** | #1 `--lang` 传递 + #5 JS bundle 限制 + #6 index.json 字段 + #8 路径排除 | EPIC-001 |
| **FEATURE-003: Build & Deployment Verification** | #2 validate 脚本打包 + #3 guard-rules 部署 + L3 验证增强 | EPIC-002 |
| **FEATURE-004 changes** | #4 评分公式改造（纳入 v7 协议 scope）| EPIC-001 / FEATURE-004 |

`--no-verify` (#7) 归入 FEATURE-003 (Verification Pipeline) 原有 scope。

### 影响范围

- 5 个 SKILL.md 文件（cpp/go/java/python/js 的 Step 2 指令）
- `internal/main.go`（auto 模式排除路径 + index.json 聚合字段）
- `internal/parser_javascript.go`（minified bundle 大小阈值）
- `scripts/package.sh`（validate 脚本拷贝）
- `scripts/deploy.sh`（guard-rules 部署完整性）
- `scripts/dev-verify.sh`（L3 增加 guard-rules 和 validate 脚本检查）
- `knowledge/protocols/scan-output.md`（评分公式修正）

### 背景

2026-06-21 对 project-codeguard（CoSAI/OASIS 开源项目）进行全量代码学习。识别出 SecGuardian 三个核心差距：

1. **命令参数歧义**：三个命令各有一套参数格式（secguard=`<path> [mode] [filters]`, secreview=`<path> [language]`, secaudit=`<skill-name> [path]`）。language 有时是第二参数、有时自动检测、有时不存在，AI 解析容易出歧义。
2. **Detector 索引手工维护**：`skills/secguard/cpp/references/language-index.md` 是手工抄写的 detector 列表，和 61 个 detector 的 frontmatter `language` 字段不同步，必然产生 drift。
3. **SecAudit 不是工作流**：secaudit 暴露 17 个独立 skill 给用户逐个调用，违背了"旗舰产品是出一份完整审计报告"的原始设计意图。用户需要 `/secaudit ./src python` 一次性跑全部 17 项 + 整合报告，而不是自己一项一项选。

### 讨论要点

#### 1. 命令参数统一方向（方式 A：language 固定为第二位置参数）

- **方案 A (选中)**: `/secguard <path> <language> [filters]` — language 是必需的第二个位置参数。README 示例 `/secguard examples/cpp-vuln-demo/src cpp` 原本就这么写，但 commands/secguard.md 丢失了 language，导致两套格式不一致。选择此方案是因为它消除了解析歧义，AI 不再需要猜第二个参数是 filter 还是 language。
- **方案 B (否决)**: 用 flag 消除歧义（`--lang python --filter memory.*`）— 太长，不符合 slash command 的简洁直觉。
- **方案 C (否决)**: AI 自动检测语言（保留现状）— 用户指定 `memory.*` 时 AI 无法判断这是 filter 还是 language。

**secreview 对齐**：从 `/secreview <path> [language]`（language 可选）改为 `/secreview <path> <language>`（language 显式）。向后兼容：如果用户不提供 language，AI 从 index.json 自动检测作为 fallback。

**secaudit 反思**：secaudit 的原始设计是 `/secaudit taint-analysis`（skill 名作为主参数），但用户指出这不符合"旗舰产品出一份完整审计报告"的预期。讨论后决定：
- 保留 secaudit 的 position 1 为 `path`、position 2 为 `language`，和 secguard/secreview 统一
- 移除"选 skill 跑"作为默认入口。17 个独立 skill 降级为 workflow 内部的 phase
- user 可通过 `--focus <skill-name>` 跳过其他 phase（开发中的性能优化选项）

最终三个命令格式统一为：

```
/secguard  <path> <language> [filters]    # 漏洞发现
/secreview <path> <language>              # 规范检视
/secaudit  <path> <language>              # ★ 旗舰：完整审计报告
```

#### 2. Detector 索引自动化

- **问题**: 61 个 detector 各有 `language` 字段，但 AI 必须全部读取才能知道哪些给 cpp、哪些给 python。`language-index.md` 是手工维持的"索引缓存"，必然 drift。
- **方案 A (选中)**: 构建时自动生成 `knowledge/guard-rules/language-index.md`。扫描 `knowledge/guard-rules/*.md` 的 frontmatter `language` 字段，按语言归类。AI 一步步读 Markdown（`## cpp` 一行就知道目标位置），不需要解析 JSON。
- **方案 B (否决)**: `language-index.json` — JSON 的引号/逗号 token 开销比纯 Markdown 大 30-50%，对 LLM 上下文不友好。
- **方案 C (否决)**: 在 Go indexer 层面加语言过滤（`--lang cpp`）— 做不到，indexer 是 AST 解析器，不做 detector 过滤。

`language-index.md` 在 `language-index.md` 生效后退役，所有引用它的 10+ 个文件统一指向新索引。

#### 3. Gemini .toml 同步

`commands/gemini/*.toml` 是三个 `.md` 的 TOML 副本，人工维护必然 drift。决定在 build 时从 `.md` 自动生成 `.toml`，三份 `.toml` 不再手工编辑。

对 project-codeguard 的 format converter 模式进行了评估。它的 Python 转化管线（`BaseFormat` → 10 个 IDE 子类）对我们过于重量级——我们只有 3 个输出格式（Claude Code 读 `.md`、OpenCode 读 `.md`、Gemini 读 `.toml`），不需要抽象基类体系。一个 shell-level 的 wrapper 函数即可。

#### 4. SecAudit 工作流 skill

**设计反思——第零版（否决）**：最初设想将 17 个独立 SKILL.md 保留在 `skills/secaudit/` 下，全量时 workflow 编排它们，单项时 `--focus` 直接引用。这个方案被否决，原因是：

- 17 个 skill = 17 个调度入口，command 层必须解决并行/串行/依赖管理——这不是 command 该做的事
- `skills/` 是 workflow 层，不是知识层。17 个 skill 的审计逻辑本质上是**审计知识**，不应嵌在 workflow 层
- 与 secguard 的架构不一致：secguard 的 60+ detector 放在 `knowledge/guard-rules/`，不是做成 60 个 skill

**正确方案：知识层与 worklow 层分离。**

```
knowledge/
  guard-rules/   ← 61 个 API 级规则（已有，改名）
  audit-rules/          ← ★ 新增：17 个审计领域知识，替代 skills/secaudit/*/SKILL.md
    input-validation.md   ← 审计 checklist + OWASP 引用 + 检测模式
    cryptography.md
    auth-and-session.md
    attack-surface-analysis.md
    ...（共 17 个）

skills/
  secaudit/
    workflow-secaudit/    ← ★ 唯一 skill：编排审计工作流
      SKILL.md             ← Phase 1-17 编排 + 路由逻辑
```

**project-codeguard 的参考**：它的 `security-review` skill 就是一个 SKILL.md，23 个规则全在 `sources/rules/core/`（知识层）。workflow 从知识层加载规则，不依赖子 skill。没有"23 个 skill 怎么调度"的问题——因为根本没有 23 个 skill，只有 1 个。

**对称性**：

| 产品 | Workflow 层（skills/） | 知识层（knowledge/） |
|------|----------------------|--------------------|
| secguard | 5 个语言 skill | `guard-rules/` 61 个检测规则 |
| secaudit | **1 个** workflow skill | `guard-rules/` + `audit-rules/` 17 个审计领域规则 |

两个产品的 workflow 层都保持极薄，真正的逻辑在 knowledge 层。

**全量/单项路由逻辑由唯一 skill 内部处理**，不做 command 层分发：

```
/secaudit ./src python
  → workflow-secaudit 加载：
      - knowledge/guard-rules/ （语言过滤后的检测规则，按 namespace 匹配）
      - knowledge/audit-rules/ （全部 17 个审计领域）
  → Phase 1-17 顺序执行，整合报告

/secaudit ./src python --focus input-validation
  → workflow-secaudit 加载：
      - knowledge/guard-rules/ （语言过滤后的检测规则，按 namespace 匹配）
      - knowledge/audit-rules/input-validation.md （仅这个领域）
  → 只跑 input-validation phase
```

17 个原始 `skills/secaudit/*/SKILL.md` 迁移到 `knowledge/audit-rules/*.md`，知识内容不变，位置变了。

#### 5. Step 2.5 的职责纠正

之前的误设计：Step 2.5 试图用 index.json 符号表"确认代码是否真的需要跑某些 detector"。这错误的根本原因是 Step 2.5 试图做 detector 选择，而这已经是 language + filter 两层筛完的事了。

修正后：Step 2.5 只做**执行效率优化**。加载了完整的 detector 集合后，读 index.json 给每个 detector 找靶子（alloc_free.pairs → memory.double-free 的检查目标；call_graph → 被调用危险函数的入口）。不跳过任何 detector。

#### 4.5 三个知识库 vs 一个知识库

三个产品对应三个不同的知识粒度，各自有独立的组织方式：

| 产品 | 知识目录 | 粒度 | 组织方式 | 数量 |
|------|---------|------|---------|------|
| secguard | `knowledge/guard-rules/` | API/函数调用级 | 按 namespace | 61 |
| secaudit | `knowledge/audit-rules/` | 架构/领域级 | 按安全领域 | 17 |
| secreview | `knowledge/review-rules/` | 代码样式/模式级 | 按语言 | 5 |

**命名原则**：统一使用 `{product}-rules/` 模式。不引入 `detectors`、`domains`、`rules` 三个不同后缀，降低认知负担。所有知识都是"规则"，只是服务于不同产品。

**为什么不合并到同一个目录加 type 字段？**

考虑过统一放到 `knowledge/rules/` 下用 `type: guard | audit | review` 区分。
否决原因：三种知识的粒度不同，AI 消费方式不同。

```
guard-rules/ 的消费方式：AI 按 language + filter 加载多个独立文件
audit-rules/ 的消费方式：AI 按 domain 加载一个领域文件，内部引用相关 secguard 规则
review-rules/ 的消费方式：AI 按语言加载一个语言文件，逐条对照检测
```

消费方式的差异决定了目录层级是最好的区分方式——AI 不需要读 `type` 字段来判断文件归属，目录名本身就是身份。每个目录的 frontmatter schema 也可以独立演进。

**迁移路径**：

| 当前路径 | 迁移到 |
|---------|-------|
| `knowledge/guard-rules/*.md`（61 个） | `knowledge/guard-rules/*.md` |
| `skills/secaudit/*/SKILL.md`（17 个审计领域） | `knowledge/audit-rules/*.md` |
| `skills/secreview/*/references/*-anti-patterns.md`（5 个） | `knowledge/review-rules/*.md` |

### 最终方案

本次特性以 EPIC-004 立项，覆盖 6 项改造：

| # | 改造 | 类型 | 文件影响量 |
|---|------|------|-----------|
| 1 | 三命令参数统一 `<path> <language>` | 接口 | 3 commands + 3 gemini |
| 2 | `language-index.md` 自动生成（替换手工 `language-index.md`） | 构建 | 新增 sync 脚本，删除 1 手工文件 |
| 3 | `commands/gemini/*.toml` 构建时自动生成 | 构建 | 3 个 .toml 变 gitignore |
| 4 | SecAudit 旗舰工作流（1 workflow skill + `knowledge/audit-rules/` 17 个审计领域规则） | 产品 | 新增 workflow skill + 迁移 17 个 skills → audit-rules |
| 5 | SecReview 反模式知识迁移（`skills/*/references/*.md` → `knowledge/review-rules/`） | 知识层 | 迁移 5 个反模式文件 |
| 6 | Step 2.5 职责纠正（只优化，不跳过） | 流程 | 1 commands |

### 不纳入本次特性的

- MCP Server（已有 FEATURE-002-mcp-server 独立追踪，后续第二轮审视）
- 三轮验证管道（已有 FEATURE-003-verification-pipeline 独立追踪）
- Detector 内容本身的修改（不改 frontmatter schema，只新增 consumer）

### 待决问题

| # | 问题 | 影响 |
|---|------|------|
| Q1 | secaudit 的 `--focus <skill-name>` 是否 v1 就做？还是 v2 再说？ | 接口设计 |
| Q2 | `language-index.md` 是否应该 git 跟踪？还是 build artifact？ | 开发工作流 |
| Q3 | secguard 的 git-diff 增量模式参数如何对齐新的 `<path> <language>` 格式？ | 接口设计 |

## 2026-06-17 — 五轮→三轮设计修正（端到端数据反推）

### 背景

完成初版五轮设计后，执行了完整的端到端验证（L1 84/84 + L4 33/33 全部通过），并深入分析了 python-vuln-demo 的 17 条真实 Finding 数据。实测发现两个关键事实迫使设计修正。

### 发现

1. **Detector 产出不是"浅层模式匹配"**: 每条 Finding 已包含 `data_flow_path`（source→propagation→sink）、`judgment_rationale`（CWE 映射推理 100-200 字）、`cvss_score`+`cvss_vector`（CVSS 3.1 完整评分）、`before_code`+`after_code`（具体到行的修复代码）、`verification_method`（可执行验证命令）。这不是传统 SAST 的裸 pattern match。

2. **P1/P2 冗余判定**: 原设计的 P1 (Fact Certification) 与 Detector 的 `judgment_rationale` 有 80% 重叠（都是确认代码事实存在）。原 P2 (Flow Certification) 与 Detector 的 `data_flow_path` 有 100% 重叠（都是追踪 source→sink）。这两轮不提供增量价值。

### 修正

```
五轮 (v1)                    三轮 (v2)

P1: Fact (冗余, 砍掉)       —
P2: Flow (冗余, 砍掉)       —
P3: Semantic  ─────────→   P1: Semantic
P4: Counter   ─────────→   P2: Counter-Evidence
P5: Court     ─────────→   P3: Adjudication Court
```

同时修正了原 Claim 设计——Detector 继续产出完整 Finding，不降级为轻量 Claim（ADRR-001）。

### 保留原则

- "Detector 不能最终定罪" — 改为"Detector 是检察官，验证管道是法庭"
- Evidence-Centric — 三轮都有证据门禁
- Judge 禁止访问源码 — 保持不变
- index.json 保持不变 — 保持不变

详见: [FEATURE-003-verification-pipeline/spec.md](epics/EPIC-001-core-scanning-engine/FEATURE-003-verification-pipeline/spec.md) (v2)

---

## 2026-06-17 — 五轮验证消减系统设计

### 背景

生产环境扫描 294 文件产生 74 条告警（28 High + 46 Medium），用户直接崩溃不愿分析。当前 `Detector → Finding` 模式无独立验证环节——检测器既是检察官又是法官。业界 ZeroFalse (F1=0.912-0.955) 和 CodeX-Verify (多 Agent 72.4% vs 单 Agent 32.8%) 提供了证据门禁 + 多 Agent 验证的成熟范式。

### 讨论要点

- **核心矛盾**: Detector 直接产出 Finding 意味着每次模式匹配都是一次不可推翻的判决
- **ECVA 参考架构**: 来自同行的 Architecture Baseline v1.0 — "Detector 不能产出 Finding，只能产出 Claim。Finding 是法律判决"——作为设计起点
- **五轮 vs 并行**: 考虑过 CodeX-Verify 式 4 Agent 并行验证，但 FP 消减是渐进收敛过程（74→55→38→28→18→15），后轮依赖前轮产出，顺序管道更适合
- **index.json 扩展**: 讨论过在 Go 索引器层构建完整 Fact Graph（类型化节点/边、source/sink/sanitizer 标注），但量化分析显示当前 index.json 已满足导航需求，扩展到 Fact Graph 会 3.5x 数据膨胀且 AI Agent 读源码可获得更丰富上下文。决定保持不变
- **用户标记 vs AI 自精炼**: 实践发现用户标记 FP 几乎不可行（用户面对 74 条告警就崩溃），采用纯 AI 自精炼路线（五轮验证管道），开发者反馈循环作为长期补充途径
- **Tree-sitter 文档化**: 设计过程中发现 CLAUDE.md/AGENTS.md/GEMINI.md 缺少 Tree-sitter 架构的系统文档，已在三个文件中补全

### 最终方案

```
Tree-sitter Indexer (不变)
       ↓
67 Detector → Claim[] (非 Finding)
       ↓
P1: Fact Certification    → 剔除证据不实
P2: Flow Certification    → 剔除数据流断裂
P3: Semantic Verification → 剔除框架已消除
P4: Counter-Evidence Hunt → 剔除有反证
P5: Adjudication Court    → 三方 Agent 合议
       ↓
Certified Finding[] + Dismissed[]
```

### 影响范围

- 67 个 detector — MATCH 输出类型从 Finding 改为 Claim（检测逻辑不变）
- `commands/secguard.md` — 新增 Step 3.5 验证管道
- `scripts/render-report.py` — 适配 certified-findings.json + 验证漏斗
- `knowledge/protocols/` — 新增 verification-protocol.md + findings-schema.json 扩展
- `internal/` — 零改动

详见: [FEATURE-003-verification-pipeline](epics/EPIC-001-core-scanning-engine/FEATURE-003-verification-pipeline/)

---

## 2026-06-07 — Findings 输出架构重构：单体 JSON → 目录树

### 背景

v4.0 单体 `findings.json` 在 3 文件 295 行 demo 扫描中产出 50KB JSON，耗时 ~9 分钟。1000 文件项目预估 25MB JSON，AI Agent 无法读取。用户明确指出："级别低不代表不是问题，所有检出的问题都要用户认可去修正"，不应按 severity 暗示某些问题不重要。

### 讨论要点

- **核心矛盾**：AI 单次 Write 50KB 可行，但后续读取 25MB JSON 直接爆 token
- **文件命名演进**：`<file>__<func>.json`（两次讨论后否定，同文件同函数同 detector 不同行碰撞）→ `<finding-id>.json`（天然唯一，对齐 SARIF/CodeQL/Semgrep）
- **`findings.json` 同名升级**：v4.0 单体→v5.0 轻量索引，用户无需学习新概念。早期过渡设计错误引入了 `findings-index.json`（与 indexer 的 `index.json` 产生认知混淆），最终回退到同名升级方案
- **不按 severity 重复输出**：避免"低严重度=不重要"的暗示，保持每个 finding 的严肃性

### 最终方案

```
scans/<scan-id>/
├── index.json       # 索引器输出（不变）
├── findings.json    # ★ 同名升级：v4.0 单体四段式 → v5.0 轻量索引+元数据（<50KB）
├── findings/        # ★ 四段式数据按 detector 分文件
│   ├── web/sql-injection/H-SQLI-webapp-L47.json
│   ├── crypto/password-storage/H-CRYPTO-crypto_utils-L20.json
│   └── ...
├── report.md, results.sarif, ... (渲染器生成)
```

### 影响范围

- `scripts/render-report.py` — `--findings-dir` + `load_findings_from_tree()`
- `knowledge/protocols/scan-output.md` — 目录结构 + finding-ID 命名规范
- `knowledge/protocols/findings-schema.json` — SingleFindingFile + FindingsIndex
- `commands/secguard.md` — Step 4 逐文件输出流程
- `commands/secaudit.md`, `commands/secreview.md` — 同步更新

详见: [FEATURE-001-output-protocol/spec.md §Phase 2](epics/EPIC-001-core-scanning-engine/FEATURE-001-output-protocol/spec.md)

---

## 2026-06-03 — 输出协议升级：商业交付物设计

### 背景

工程师提出灵魂问题：每一次扫描结果要能拿出来展示产品价值，`manifest.json` 只够给工程师看，缺少能给决策者/客户看的商业交付物。

### 讨论要点

- **业界参考**：研究了 Coverity、Snyk、SonarQube、CodeQL 的报告格式
- **核心洞察**：一份报告同时服务三个角色（决策者、技术负责人、工程师），不应该分散在多个文件中
- **差异化优势**：Markdown 格式天然支持人 + AI 双重消费，竞品的 HTML/PDF 报告不具备这一特性

### 最终方案

`report.md` 升级为六章结构的专业审计报告：

| 章节 | 受众 | 内容 |
|------|------|------|
| §1 执行摘要 | 决策者/客户 | 安全评分 A-F + 趋势 + 关键数字 |
| §2 合规仪表盘 | 决策者 | OWASP Top 10 + CWE Top 25 覆盖率矩阵 |
| §3 检出清单 | 技术负责人 | 可排序表格：ID/严重度/CWE/文件/标题 |
| §4 详细发现 | 工程师/AI | 证据链 + before/after 修复代码 + CWE 参考 |
| §5 修复路线图 | 技术负责人 | 四阶段优先级排序 + 预估工时 |
| §6 附录 | 所有人 | 方法论、工具信息、PDF 导出指南 |

**安全评分算法**：`100 - (Critical×25 + High×10 + Medium×3 + Low×1)`，A(90+)~F(0-39)

**与竞品对比**：SecGuardian 是唯一同时提供 A-F 评分 + OWASP/CWE 双覆盖 + AI 可执行 + 免费 PDF 导出的方案。

### 影响范围

- `knowledge/protocols/scan-output.md` — 完全重写 report.md 模板
- `commands/*.md` — 添加"如何使用扫描结果"指引

---

## 2026-06-03 — 输出协议重构：人读 Markdown + 机读 SARIF

### 背景

原先 Phase 5 叫"生成 Findings"，输出 `findings/<id>.json`。命名不专业，JSON 对人类不友好，缺少机读标准格式。

### 讨论要点

- **业界标准**：SARIF 2.1.0 是 OASIS 国际标准，GitHub Code Scanning / GitLab SAST / Azure DevOps 三家原生支持
- **人读 vs 机读分离**：Markdown 给人和 AI Agent 消费，SARIF 给 CI/CD 系统消费
- **GitHub 2025-07 强制要求**：每个 tool/category 独立上传 SARIF，禁止合并多工具结果

### 最终方案

```
.codeagent/<extension>/scans/<scan-id>/
├── report.md         ← 人读（Markdown，证据链 + before/after 修复）
├── results.sarif     ← 机读（SARIF 2.1.0 OASIS 标准）
├── manifest.json     ← 入口（元数据 + 检出索引）
├── summary.json      ← 仪表盘（按严重度/命名空间统计）
├── status.json       ← CI 门禁（pass/fail + 阈值）
└── delta.json        ← 增量对比（vs 上次扫描）
```

Phase 命名统一为"持久化输出"，所有 6 个命令和 12 个 skill 的 Output Phase 统一升级。

### 影响范围

- `knowledge/protocols/scan-output.md` — v2.0 协议定义
- `commands/*.md` + `commands/gemini/*.toml` — Step 4 全部升级
- `skills/*/*/SKILL.md` — Output Phase 统一引用 v2.0
- `skills/secguard/cpp/references/examples/output-schemas.md` — 重写为 Markdown + SARIF 示例

---

## 2026-06-03 — 项目瘦身：移除 CLI 死代码和 prompt-templates

### 背景

对项目做全面审视时发现：
- `internal/` 含 4 个死代码包（prompt, budget, reflection, scheduler），零 import
- `knowledge/prompt-templates/` 是独立 CLI 的 prompt 拼装，与 AI Agent 主流程无关
- `main.go` 含 scan/audit/review/detectors 等 CLI 子命令，被 AI Agent 命令完全取代

### 最终方案

**删除内容**：
- `internal/prompt/` (1 file)
- `internal/budget/` (1 file)
- `internal/reflection/` (4 files)
- `internal/scheduler/` (1 file)
- `knowledge/prompt-templates/` (4 files)
- `main.go` CLI 子命令 + 60-entry 检测器注册表

**保留核心**（indexer only）：
- `parser/` — 双模解析（tree-sitter + 正则回退）
- `indexer/` — 文件遍历、调用图、alloc/free、锁图
- `context/` — 分析上下文结构体

### 结果

`internal/`：13 files / 5 packages → 7 files / 3 packages。`main.go`：507 → 193 行 (-62%)

### 影响范围

- `internal/` 全部 Go 源文件
- `scripts/secguardian.sh` — 移除 prompt-template 引用

---

## 2026-06-03 — Skills 目录重构：27 平铺 → 3 命名空间

### 背景

`skills/` 下 27 个平铺目录（`secaudit-attack-surface-analysis/`），前缀表达归属。随着 skill 增多，维护困难。

### 讨论要点

- 每个 command（secaudit/secguard/secreview）天然对应一个 skills 子目录
- 目录层级即可表达归属，`SKILL.md` 的 `name` 不再需要前缀
- 打包脚本 `package.sh` 可以按 command 精准组装

### 最终方案

**源码结构**（干净）：
```
skills/
  secaudit/{17 skills}/
  secguard/{5 skills}/
  secreview/{5 skills}/
```

**部署结构**（防碰撞）：
```
.opencode/plugins/secguardian/skills/
  secaudit-attack-surface-analysis/   ← deploy.sh 自动加回前缀
  secguard-cpp/
  secreview-cpp/
```

### 关键设计

`deploy.sh` 在部署时从 dist 目录名提取 command 前缀（`secaudit-secguardian` → `secaudit`），加到 skill 目录名前面。源码干净，部署无碰撞。

### 影响范围

- `skills/` 全部 27 个目录重命名
- `scripts/package.sh` — path 拼接 `${cmd}/${name}`
- `scripts/deploy.sh` — copy 时加前缀
- `commands/*.md` + `commands/gemini/*.toml` — skill 引用路径更新

---

## 2026-06-03 — 删除 knowledge/cheatsheets

### 背景

上一轮重构新建了 `knowledge/cheatsheets/` 作为 detectors 和 skills 之间的速查层。经审视发现：

### 结论

**过度设计。** 4 个文件里 2 个是 detectors 的摘要复读，1 个分类错误，只有 1 个有增量价值。

| 文件 | 处置 |
|------|------|
| `crypto-algorithms.md` | 删除 — 9 个 crypto detectors 已逐个覆盖 |
| `injection-patterns.md` | 删除 — detectors 已含逐语言检测逻辑 |
| `secrets-detection.md` | 迁移 → `knowledge/guard-rules/` |
| `tls-config.md` | 迁移 → `skills/secaudit/secure-transport/references/` |

### 教训

不要在已有完备数据层（detectors）和流程层（skills）之间硬塞中间层。如果新增内容有价值，应该归入 detectors（执行原语）或 skill references（辅助资料）。

### 影响范围

- `knowledge/cheatsheets/` — 整个目录删除
- 15 个文件中的 cheatsheets 引用全部清理

---

## 2026-06-02 — 跨平台双模 Parser

### 背景

原 `secguardian-index` 依赖 tree-sitter CGO 绑定，只能本地编译（macOS arm64）。Linux/Windows 用户无法使用。

### 讨论要点

- **业界调研**：tree-sitter 纯 Go 实现（gotreesitter）、Python 绑定、Rust 绑定
- **方案 A**：换用 gotreesitter（纯 Go，零 CGO）— 改动最小
- **方案 B**：改用 Python tree-sitter — 需完全重写
- **方案 C**：改用 Rust — 需完全重写

### 最终方案

**方案 A-改**：不换库，而是双模编译：

```
parser_ts.go   //go:build cgo      → tree-sitter 完整 AST
parser_re.go   //go:build !cgo     → 纯 Go 正则回退
```

同一套公开 API（ParseFile、ParseResult 等），根据 CGO 是否可用自动选择。CGO 可用时享受完整 tree-sitter 解析，不可用时正则回退仍能提取函数/类型/变量。

### 结果

- 四平台全部可编译：darwin-arm64(tree-sitter)、darwin-amd64(regex)、linux-amd64(regex)、linux-arm64(regex)、windows-amd64(regex)
- 正则回退：60 functions vs 60 functions (tree-sitter)，功能等价
- 二进制大小：tree-sitter 8.4M vs regex 3.3M

### 影响范围

- `internal/parser/parser_ts.go` — CGO 版（原 parser.go）
- `internal/parser/parser_re.go` — 纯 Go 正则版（新增）
- `scripts/package.sh` — 五平台并行编译

---

## 2026-06-02 — 品牌扩展名设计：三平台统一

### 背景

OpenCode 项目级部署将 27 个 skill 平铺在 `.opencode/skills/` 下，没有品牌命名空间。用户研究发现 OpenCode 的 `skills/` 和 `commands/` 顶层目录是给项目手写文件用的，扩展应该放在 `plugins/<brand>/` 下。

### 最终方案

三平台统一品牌命名空间：

| 平台 | 路径 |
|------|------|
| Claude Code | `.claude/plugins/secguardian/` |
| OpenCode | `.opencode/plugins/secguardian/` |
| Gemini CLI | `.gemini/extensions/secguardian/` |

每个平台都包含 `commands/` + `skills/` + `knowledge/` + `scripts/` + plugin manifest。

### 关键设计

- `deploy.sh` 的 `deploy_opencode()` 完全重写
- 二进制在 zip 内统一命名为 `secguardian-index`（无平台后缀）
- Shell wrapper 优先查 canonical 名，回退到平台特定名
- 旧平铺部署自动检测并清理

### 影响范围

- `scripts/deploy.sh` — deploy_opencode 重写, deploy_claude 补全 knowledge+scripts
- 6 个命令文件 — indexer 搜索路径更新

---

## 2026-06-02 — Knowledge cheatsheets 架构

### 背景（已废弃）

原先 `knowledge/` 下只有 detectors（执行原语）和 languages（语言画像）。审计 skill 的大段检查清单内联在 SKILL.md 中，导致文件过长（150-200 行）。

### 当时方案（后于 2026-06-03 删除）

新建 `knowledge/cheatsheets/` 作为跨 skill 共享速查层，包含 4 个领域聚合表。

### 删除原因

2026-06-03 经审视认定该层为过度设计，所有内容已迁移或删除。详见上方"删除 knowledge/cheatsheets"条目。

### 教训

知识库的层次应该尽量扁平。如果 detectors 已经完备，不要为了"好看"而创建中间层。新增的参考内容如果是对单个 skill 的辅助，放入 `skills/<name>/references/`；如果是对多个 skill 都有价值，应该设计为正规 detector。

---

## 2026-06-02 — Bug 修复：Parser slice bounds panic

### 背景

`secguardian-index` 解析 `crypto.c` 时 panic：`slice bounds out of range [:1382] with capacity 1024`

### 根因

`safeUtf8Text()` 使用固定 1024 字节 buffer 调用 `node.Utf8Text(buf)`。tree-sitter 要求 buffer >= 节点字节数，crypto.c 中某节点 1382 字节超出限制。

### 修复

- 删除 `safeUtf8Text()`
- `extractTypeName()` 改用 `safeText(content, start, end)` 直接从源文件读取
- `safeText()` 增加 `start >= len(content)` 和 `start > end` 边界检查

### 影响范围

- `internal/parser/parser.go` — 1 function deleted, 1 hardened

---

## 2026-06-02 — 27 Skills 规范化

### 背景

27 个 `SKILL.md` 存在 frontmatter 不一致、描述缺乏触发引导、secguard-* 缺少 topic 字段、Phase/Step 命名不统一等问题。

### 最终方案

| 改动 | Before | After |
|------|--------|-------|
| topic 字段 | 单值/缺失/数组混用 | 统一 YAML 数组 |
| description | 仅"做什么" | 增加"当用户请求...时使用"触发短语 |
| H1 标题 | 含英文括号 | 纯中文描述 |
| Phase 命名 | secguard 用 Step | 统一 Phase |
| 前置声明 | 格式不统一 | 统一 blockquote |
| 输出协议 | 仅 secguard 引用 | 23/27 明确引用 |

Secreview 5 个 skill 从 ~45 行扩展到 ~100 行，增加结构化 Phase 1-5 + 检测表 + 代码示例。

### 影响范围

- 全部 27 个 SKILL.md

---

## 设计原则总结

通过本轮（2026-06-02 ~ 2026-06-03）密集重构，沉淀出以下原则：

1. **源码干净，部署隔离** — skills 按 command 分目录，deploy 时自动加前缀
2. **知识扁平，不做过度抽象** — detectors + languages 两层足够，不要再塞中间层
3. **核心做小，不要 CLI 包袱** — internal/ 只保留 indexer，AI agent 命令覆盖全部交互
4. **输出即交付物** — report.md 是一个人+AI 通读的商业报告，不是 JSON dump
5. **人读/机读分离** — Markdown 给人 + AI，SARIF 给 CI/CD，各司其职
6. **命名即文档** — Phase 持久化输出 > Phase 生成 Findings
7. **平台感知，用户无感** — 双模 parser + 五平台二进制 + 品牌扩展名，用户只管下载解压

---

## 2026-06-21 — Code Health & Hygiene — 首次 Codex 审计修复

---

## 2026-06-30 — 战略定位升级 + /secfix 第四门

### 背景

2026-06-30 与 ChatGPT 深度讨论项目未来方向，输出 README-EN.md 作为临时愿景文件。
结合这条线，与 Codex 进行了两轮重构：

1. **README.md 全面英文化 + 战略叙事迁移**
2. **/secreview 微重构**：从"安全编码规范检视"→"AI Security Code Review for PRs"
3. **新增 /secfix 第四门**：AI Remediation，补全 Prevent → Detect → Fix → Verify 闭环

### 讨论要点

#### 1. ChatGPT 的战略警告与定位升级

ChatGPT 指出核心风险：**"AI 比传统 SAST 更聪明"这个卖点的生命周期不会很长。**
12 个月后 AI 推理能力是所有产品的共同能力，不再是独特优势。

真正长期不贬值的，是另外三件事：

| 资产 | 说明 |
|------|------|
| **Rule Packs** | OWASP ASVS、NIST SSDF、企业安全红线 → 可执行的审计规则 |
| **Workflow** | 编码 → Review → 发布验收，完整 Secure SDLC，不是单次扫描 |
| **Enterprise Outputs** | 给开发负责人、安全团队、审计部门、CI/CD 直接使用的输出 |

建议的演进路径：
> **AI Security Scanner → AI Security Workflow → AI Security Governance Platform**

#### 2. /secfix 命名的推导

| 候选名 | 评估 |
|--------|------|
| **/secfix** ✅ | sec- 前缀一致，2 音节，语义直接，"fix" 是工程师修代码时最自然的动词 |
| /fixit ❌ | 太像随口叫 AI 改代码的语气，不像安全工具 |
| /secremediate ❌ | 4 音节太长，破坏简洁性 |
| /secpatch ❌ | 容易联想到 OS 补丁管理 |

选中 /secfix。

#### 3. /secfix 的位置决策

不在 SDLC 中新增一个 Gate（"修复"本身不是决策点），而是作为 **/secreview 的出口动作**：

```
/secreview — 检出发现
    │
    ├── Clean → Merge
    │
    └── Findings → /secfix → patches → git commit → /secreview re-run
```

同时被 /secguard 和 /secaudit 按需调用，但主入口是 /secreview 的 remediation 出口。

#### 4. /secfix 的商业价值分析

企业不会为"AI 替人修代码"买单，但会为"把修复耗时从 30 分钟降到 2 分钟"买单。

正确的叙事：
> /secfix 不是用 AI 替工程师修代码。
> 而是给每个安全发现预先写好修复草稿，让工程师在 30 秒内 review 完、应用、提交。
> 决策权始终在工程师手里。他们可以改、可以驳回、可以调整。
> 我们只是帮他们省掉"查资料写代码"的那 30 分钟。

| 价值点 | 谁在乎 | 为什么付钱 |
|--------|--------|-----------|
| 减少修复耗时 10x | 工程 VP | dev 工时就是钱 |
| 标准化修复质量 | 安全负责人 | AI 修的永远正确、一致 |
| 降低修复门槛 | 团队新人 | junior 也能提交正确修复 |
| 可审计的修复记录 | 合规团队 | finding → fix patch 一一对应 |
| 修复 backlog 归零 | 所有人都爱 | 不存在"扫描发现 200 个、只修 50 个" |

#### 5. README.md 定位升级

从旧版"卖 AI 更聪明"→ 新版"卖三件 durable 的东西"：

| 旧叙事 | 新叙事 |
|--------|--------|
| "AI 深度安全审计" | "AI Security Workflow for Secure SDLC" |
| "传统 SAST 做不到" | "AI reasoning is becoming a commodity" |
| "5 项分析方法" | "The value is in Rule Packs + Workflow + Outputs" |
| "年省 $50K+" | "Fix security defects in minutes, not hours" |

### 设计决策

| 决策 | 选项 | 选中 | 理由 |
|------|------|------|------|
| /secfix 命名 | secfix / fixit / secremediate / secpatch | **secfix** | 前缀一致 + 语义直接 |
| /secfix 位置 | 第四 Gate / secreview 出口 / 跨阶段工具 | **secreview 出口** | Gate 是决策点，fix 是动作 |
| 第四门总称 | Three Gates / Four Gates | **Four Gates** | 四门 = Prevent→Detect→Fix→Verify |
| 新 README 聚焦 | AI 能力 / 知识工作流 | **知识工作流** | AI 12 个月后是 commodity |

### 关联产品

| 命令 | 定位 | 输出 |
|------|------|------|
| /secguard | Secure Coding Guidance — coding 阶段 | findings with CWE + CVSS + fix |
| /secreview | AI Security Code Review — PR 阶段 | findings + exploit scenarios + CWE |
| /secfix | AI Remediation — PR 阶段出口 | patch files from finding fix fields |
| /secaudit | AI Release Security Audit — 发布阶段 | audit report + pass/fail decision |

### 下一步

- [ ] /secaudit 命令重构（等用户提供新设计方案）
- [ ] /secfix MVP 实现（消费 findings/ 目录 → 生成 patch files）
- [ ] README 中补全 /secfix 的四门图已在本日完成

---

## 2026-07-02: Audit Framework 架构职责收敛（Architecture Refinement）

**背景**: FEATURE-008 在 `audit-framework/` 下创建了 `rulepacks/` 目录，将 `knowledge/audit-rules/` 中的 17 个规则文件复制到 `audit-framework/rulepacks/secguardian/rules/`。这造成了安全知识的重复维护。

**讨论要点**:
- `audit-framework/` 应该是"Audit Execution Framework"——描述 SecAudit 如何完成一次安全验收
- `audit-framework/` 不应拥有任何安全知识（rules、standards、references）
- `knowledge/` 必须是唯一安全知识源（Single Source of Truth）
- 规则复制导致两个地方维护 17 个文件，违背 SSOT 原则
- `pack.json` 作为规则索引的概念有用，但不应放在 `audit-framework/rulepacks/` 下

**最终方案**:
- 删除 `audit-framework/rulepacks/` 整个目录（17 个重复规则 + pack.json + README）
- 将 `audit-framework/README.md` 重新定位为 Audit Execution Framework 概述
- 新增 `architecture.md`、`workflow.md`、`evidence.md`、`report-schema.md` 作为框架设计文档
- `knowledge/audit-rules/` 保持为唯一规则源，不做任何修改
- 更新 `audit-framework/engine/README.md` 指向 `knowledge/audit-rules/`
- 更新 `commands/secaudit.md` 中的路径引用（从 `audit-framework/rulepacks/` → `knowledge/audit-rules/`）

**影响范围**:
- `audit-framework/`: 删除 rulepacks/，重写 README.md，新增 4 个框架文档，更新 engine/README.md
- `commands/secaudit.md`: 路径引用更新（6 处）
- `knowledge/`: 无变更（已经是 SSOT）

**关联参考**: 用户提供的 [Audit Framework 重构指导](#)

---

## 2026-07-02: SecAudit 领域模型重构 (Domain Model Redefinition)

**背景**: 当前 skills/secaudit/ 和 knowledge/audit-rules/ 将分析方法（Taint Analysis、Attack Surface 等）与安全领域（Authentication、Cryptography 等）混在同一级。用户需要选择 "我到底要用 taint-analysis 还是 cryptography？"，增加了认知负担。

**讨论要点**:
- 分析方法（Taint Analysis、Data Flow、Attack Surface、Trust Boundary、State Machine）应该是 AI 内部推理能力，不是用户入口
- 安全领域（Authentication、Cryptography、Input Validation 等）是产品能力，应该暴露给用户
- Skills 概念收敛为 "AI Workflow"——SecAudit 只保留 workflow-secaudit 一个 skill
- 未来新增标准（OWASP ASVS、PCI DSS、CIS Benchmark）通过 Mapping 实现，不新增 Rule
- Analysis Method 可以持续演进（Symbolic Execution、CPG、Graph Reasoning），不影响产品接口

**最终方案**:
- knowledge/audit-rules/: 删除 5 个分析方法文件，新增 information-exposure.md
- skills/secaudit/: 删除 15 个独立 skill（5 分析方法 + 12 领域），仅保留 workflow-secaudit
- commands/secaudit.md: 简化为单一入口，无 skill 路由
- docs/audit-framework/: 更新架构图和工作流描述

**影响范围**:
- knowledge/audit-rules/: 17→13 文件（-5 +1）
- skills/secaudit/: 18→1 目录（仅保留 workflow-secaudit）
- commands/secaudit.md: 大幅简化
- manifest.json: 更新计数
