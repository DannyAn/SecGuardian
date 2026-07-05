# Changelog

All notable changes to SecGuardian.

## [0.13.0] — 2026-07-05

### ★ Architecture Refactoring — Signal-LLM Collaboration Model

#### 架构文档 (6 docs rewritten)
- **Signal-LLM 协作模型** — 取消独立 Security Engine 概念，改为确定性信号层（索引器）+ LLM 推理层（AI Agent）通过 index.json 直接协作
- **执行策略合约** — engine_contract.md 重写为行为约束合约（Anchor Rule + Evidence Rule + Pre-Filter Rule），不再定义 Engine API
- **渐进式信号增强路线** — v0.14 跨文件调用图+类型继承 → v0.15 数据流预分析 → v0.16+ CI 快速门禁
- **7 条工程约束 (EP-1~EP-7)** — 防止过度设计，确保架构演进渐进可控

#### 命令层 (4 commands)
- **锚定+证据约束** — 每个 finding 的 file+line 必须可追溯到 index.json 符号，必须包含 snippet/code-context/rationale/attack-scenario
- **跨 shell 状态传递** — `.codeagent/.scan_state` 替代 `/tmp/` 临时文件，消除确权弹窗，跨平台可用
- **heredoc --from-stdin** — record-finding.py 支持 stdin JSON 输入，彻底消除 shell 引号逃逸问题
- **强制信号预筛** — Step 2.5b 改为 mandatory first-pass filter，无信号检测器跳过

#### 技能层 (11 skills)
- 全部 11 个技能文件注入锚定+证据约束 + 语言特定信号预筛规则 + index.json.symbols.functions 驱动读取

#### 工具链
- **record-finding.py** — snippet/code-context/rationale/attack-scenario 改为必填参数；新增 --index-json 锚定校验 (ANCHOR_OK/FAIL/INFO)；新增 --from-stdin heredoc 支持；修复 null 值处理 bug
- **SDD Feature Package** — 完整 FEATURE-005 包（spec + 2 ADR + plan + 7 CHANGE + 15 tasks）

#### README
- 重写为 Security Roles 模型 + Signal-LLM 架构 + 角色使用指南 + CI/CD 快速门禁文档

## [0.12.0] — 2026-07-03

### ★ 共享索引重构

#### 架构
- **共享索引** — index.json 从 per-scan 目录移至 `.codeagent/secguardian/` 根级别，所有命令（secguard/secaudit/secreview）复用同一索引
- **输出结构简化** — 从 `.codeagent/<ext>/scans/<scan-id>/` 改为 `.codeagent/secguardian/<command>/scans/<scan-id>/`
- **wrapper 重写** — 移除缓存逻辑，改为共享索引存在性检查 + `--path` 一致性校验 + `--force` 强制重建
- **路径校验** — 自动检测 `--path` 变更，不同路径自动重建索引

#### 修复
- **AI 探测修复** — 移除前置检查中 `scripts/` fallback 说明，防止 AI `ls scripts/` 错误探测
- **FEATURE-006 回归修复** — 恢复被 squash merge 覆盖的共享索引设计（commit `1ba7e54`）

## [0.11.0] — 2026-07-03

### ★ Audit Framework 架构职责收敛 (CHANGE-002)

#### 重构
- **知识去重** — 删除 `audit-framework/rulepacks/` (17 个规则与 `knowledge/` 完全重复)，`knowledge/audit-rules/` 成为唯一安全知识源 (SSOT)
- **目录归位** — `audit-framework/` 从根级移至 `docs/`（后因冗余删除，架构设计移交 SDD 维护）
- **CLI 入口统一** — 移除 `--rulepack` 参数，`/secaudit <path> <lang>` 与 `/secguard`、`/secreview` 一致
- **框架纯化** — `audit-framework/` 不再包含任何安全规则副本

### ★ SecAudit Domain Model 重构 (FEATURE-009)

#### 领域模型
- **分析方法降级为 AI 内部推理** — Taint Analysis、Data Flow、Attack Surface、Trust Boundary、State Machine 不再作为用户入口，由 AI Workflow 自动选择
- **SecAudit 仅暴露安全审计域** — 13 个审计域 (Authentication、Cryptography、Input Validation 等)
- **新增 information-exposure 域**

#### Skills 收敛
- **skills/secaudit/ 从 18 个降为 1 个** — 删除 16 个独立 skill 目录，仅保留 `skills/secaudit/SKILL.md`
- **Skill 路径拍平** — `skills/secaudit/workflow-secaudit/` → `skills/secaudit/`
- **引用文件迁移** — 2 个文件迁移至 `knowledge/standards/`

### ★ 发布质量修复 (2026-07-03)

#### 渲染器修复
- **manifest.json command 字段错误** — renderer 写死了 `"command": "secguard"`，secaudit/secreview 的 manifest 也显示 secguard
- **修复**: 新增 `--command` 参数，三个命令 Step 4c 分别传入 `--command secguard|secaudit|secreview`
- **结果**: manifest.json 的 command 字段现在正确

#### 输出路径修复
- **`.codeagent/` 输出跑到了 SecGuardian 项目根** — 路径是相对于 AI 的 CWD 而非用户项目根
- **修复**: 三个命令文件统一加"输出路径约定"，所有路径使用 `<user-project>/.codeagent/` 前缀
- **索引器输出路径不一致** — 索引器写 `.codeagent/...`，渲染器读 `<user-project>/.codeagent/...`，scope 统计空白
- **修复**: 索引器输出路径也改为 `<user-project>/.codeagent/...`
- **secreview 索引器跑在 scan_id 之前** — 路径不含 scan_id → 渲染器找不到 index.json
- **修复**: 强调 `Generate scan_id FIRST` + ALL 后续路径使用同一 scan_id

#### 部署脚本修复
- **`scripts/dev-deploy.sh` 删除** — 与 `deploy.sh` 重复维护，且文件头已自述弃用
- **`deploy.sh` 默认不构建** — 用户需手动 `--build`，但大部分人不知道
- **修复**: `deploy.sh all` 默认先构建再部署；新增 `--verify` 部署后自动验证
- **`deploy.sh --user` 报错** — 第一参数 `--user` 被当作平台名解析
- **修复**: 首参数以 `--` 开头时默认 `all`

#### 发布产物修复
- **GitHub Release 只有源码包** — `release.yml` 的 `files: dist/release/**/*.zip` 只上传 `.zip`
- **修复**: 改为 `files: dist/release/**`，上传所有产物（5 平台二进制 + .sha256 + 3 插件 .zip + manifest.json）
- **`package.sh` 未处理拍平 skill** — `skills/${cmd}/${skill_name}` 路径不存在（secaudit 的 skill 是拍平的）
- **修复**: 新增 `flat_skill` 回退逻辑 + `references/` 目录复制

#### 验证机制
- **新增 cross-command 一致性检查** — `self-check.sh §11` + `ci-check.sh §6`
- 验证所有 3 个命令文件同步包含：`--command <name>`、`<user-project>/` 前缀、scan_id 排序指令、无陈旧引用
- **self-check 从 107 项扩展到 120 项**

### 其他改进
- `internal/main.go` — 版本号同步至 0.11.0
- `commands/secaudit.md` — 移除"16 阶段审计"（过时）和 `skill_category: "analysis"`（改为 `"domain"`）
- `commands/secreview.md` — 同步输出路径约定、scan_id 顺序、移除旧版 skill 路由引用
- `scripts/sync-language-index.sh` — 新增 regenerated 文件提交
- `knowledge/language-index.md` — 提交重构后版本的自动生成文件
- **总代码量**: +874 / -3692 行 (净削 2818 行)

## [0.11.0] — 2026-07-02

### ★ Audit Framework 架构职责收敛 (CHANGE-002)

#### 重构
- **知识去重** — 删除 `audit-framework/rulepacks/` (17 个规则与 `knowledge/` 完全重复)，`knowledge/audit-rules/` 成为唯一安全知识源 (SSOT)
- **目录归位** — `audit-framework/` 从根级移至 `docs/audit-framework/`（后因冗余删除，架构设计移交 SDD 维护）
- **CLI 入口统一** — 移除 `--rulepack` 参数，`/secaudit <path> <lang>` 与 `/secguard`、`/secreview` 一致
- **框架纯化** — `audit-framework/` 不再包含任何安全规则副本，纯框架设计文档

### ★ SecAudit Domain Model 重构 (FEATURE-009)

#### 领域模型
- **分析方法降级为 AI 内部推理** — Taint Analysis、Data Flow、Attack Surface、Trust Boundary、State Machine 不再作为用户入口，由 AI Workflow 自动选择
- **SecAudit 仅暴露安全审计域** — 13 个审计域 (Authentication、Cryptography、Input Validation 等)，用户只需理解安全领域
- **新增 information-exposure 域** — 补齐用户列出的 12 个核心域

#### Skills 收敛
- **skills/secaudit/ 从 18 个降为 1 个** — 删除 16 个独立 skill 目录（5 分析方法 + 11 领域），仅保留 `skills/secaudit/SKILL.md`
- **Skill 路径拍平** — `skills/secaudit/workflow-secaudit/SKILL.md` → `skills/secaudit/SKILL.md`
- **引用文件迁移** — 2 个参考文件 (owasp-asvs-auth.md、tls-config.md) 从 skill 目录迁移至 `knowledge/standards/`

#### 入口界面
- `commands/secaudit.md` — 移除 skill 列表、分析算法引用、简化 Step 3
- `commands/gemini/secaudit.toml` — 同步清理
- `--focus` 支持 13 个审计域 (原 17 个)

#### 文档
- `docs/audit-framework/` — 已删除，所有架构设计决策由 `docs/sdd/` 维护 (FEATURE-008, CHANGE-002, FEATURE-009)
- `README.md` — 更新目录树和产品描述
- `manifest.json` + `extensions/*/extension.json` — 技能清单同步更新

### 其他改进

- `scripts/self-check.sh` — skills 计数从 `ls -d` 改为 `find -name SKILL.md`，兼容 zsh 空 glob
- `scripts/ci-check.sh` — 支持拍平 skill 结构验证 (`SKILL.md (flat)`)
- `internal/main.go` — 版本号同步至 0.11.0
- **总代码量** — +35 / -2324 行 (净削 2289 行，清理大量冗余知识)

## [0.9.0] — 2026-06-26

### ★ 输出协议 v7.0 — 消费者导向设计

输出协议从 scanner 内部视角重构为消费者视角。完整设计历程见 FEATURE-004-output-protocol-v7。

#### 新增

- **human/executive-summary.md** — 统一入口仪表盘。评分、发现分布交叉表(检测器×文件数)、风险集中度(文件×发现数占比)、Top 3 Critical、导航引导。
- **ai/remediation-pack.json** — AI 修复包。每条 finding 含 root_cause、fix_strategy、before/after code、related_findings(同文件/同函数关联)。
- **report.html** — 自动 HTML 报告（stdlib only），管理层/审计双击打开。
- **report.md 数据检索** — §2 按文件分组 + §3 按检测器分组，覆盖工程师双检索需求。

#### 精简

- **report.md 7→5 节** — 去掉管理层摘要/验证漏斗/合规表，管理内容归到 executive-summary。
- **移除 developer/by-file/** — 1000+ 文件项目不可行。
- **移除 ai/attack-graph.json** — 无真实消费者，relationships 嵌入 remediation-pack。

#### 修复模式变更

- **修复建议动态生成** — AI Agent 根据代码上下文动态组装，不从 detector 知识库拷贝固定模板。

## [0.8.0] — 2026-06-25

### ★ Renderer & Artifact Pipeline Overhaul

- **Finding 规范化层** (**`_ensure_fields`**): location.file_path→file、function→function_name 自动字段适配，消除 KeyError 系统性风险
- **前置工件验证** (新增 **`scripts/validate-findings.py`**): findings 进入渲染器前必须校验通过，残缺数据拒绝而非填充缺省值
- **SARIF 生成器健壮性**: 兼容两种 detector 格式，修复 IndexError 崩溃
- **质量门禁宽松化**: quality_rating/fix 字段非必需时后端容忍
- **验证脚本抽取**: 命令模板中 50 行内联 Python heredoc 抽为独立 **`scripts/validate-index.py`**
- **模板检查** (新增 **`scripts/check-command-templates.py`**): 模板常见错误检测
- **跨语言全管线验证** (新增 **`scripts/verify-lang-pipeline.sh`**): 5 语言索引器→端到端流水线

### ★ SecReview 质量提升

- **前置语言推断**: /secreview 自动推理语言
- **Detector 命名规范**: Step 4a 要求 **`namespace.name`** 格式
- **模板例补全**: Step 4a 示例扩展为完整 finding 结构

### ★ OpenCode Plugin 修复

- **Knowledge path 注册**: opencode-plugin.js 补充 **`cfg.knowledge`** 路径注册
- **验证增强**: dev-verify.sh + e2e-verify.sh 新增插件内容检查

### ★ Scripts & Release

- **release.sh**: 动态规则计数
- **gitee-release.sh**: 命令格式更新为 `<path> <language> [filters]`
- **Agent 字段命名对齐**: 三命令模板 Step 4a 标准字段名，消除 120 条验证错误

---

## [0.7.0] — 2026-06-21

### ★ Command Interface Unification
- 三命令参数统一为 `<path> <language>` 格式
  - `/secguard  <path> <language> [filters]`
  - `/secaudit  <path> <language> [--focus <domain>]`
  - `/secreview <path> <language>`
- 消除 `<path> <language>` vs `<path> [mode] [filters]` 的解析歧义
- SecAudit 从 17 个独立 skill 入口改为单一 workflow（`--focus` 保留单项审计能力）
- Step 2.5 职责纠正：只优化执行效率，不跳过任何检测器

### ★ Knowledge Layer Restructuring
- `knowledge/detectors/` → `knowledge/guard-rules/` (67 个 API 级检测规则)
- `knowledge/audit-rules/` (17 个审计领域规则，从 `skills/secaudit/*/SKILL.md` 迁移)
- `knowledge/review-rules/` (5 个语言反模式规则，从 `skills/secreview/*/references/*.md` 迁移)
- 统一命名模式：`{command}-rules/`，降低认知负担
- `knowledge/language-index.md` 构建时自动生成（替换手工维护的 `detector-index.md`）

### ★ SecAudit Workflow
- 新增 `skills/secaudit/workflow-secaudit/SKILL.md`（17 phase 编排）
- 全量模式：加载全部 17 个审计领域，产出一份完整审计报告
- 单项模式：`--focus <domain>` 加载单一领域，用于团队分工/局部验证
- 17 个原始 SKILL.md 内容不变，从 workflow 层移到 knowledge 层

### ★ Build Automation
- `scripts/sync-language-index.sh` — 从 guard-rules/audit-rules frontmatter 自动生成 language-index.md
- `scripts/sync-toml.sh` — `.md` → `.toml` 自动转换（消除 Gemini drift）
- `commands/gemini/*.toml` 构建时生成，gitignored，不再手工维护
- `scripts/package.sh` / `scripts/deploy.sh` 同步更新为新知识结构

### ★ L5 Pipeline Verification
- `e2e-verify.sh` section 12: Build → Package → Execute 完整流水线验证
- 构建 → 包结构检查 → 部署 → indexer 执行 → index.json 结构验证 → 知识层一致性检查
- `--quick` 模式跳过 L5（49 项），完整模式包含 L5（50 项）

### ★ Documentation
- AGENTS.md: 验证矩阵增加 L5 行
- README.md / DEVELOPER.md / GEMINI.md / SECURITY.md: 更新路径引用
- EPIC-004 SDD Feature Package: brainstorm / spec / adr / plan / progress 完整记录

### Fixes
- `self-check.sh` section 1/4 重写为新知识结构格式
- `package.sh`: 添加 audit-rules/review-rules/language-index.md copy loops
- `deploy.sh`: 三个平台各添加新知识目录的 cp -r 命令
- `scripts/dev-verify.sh`, `scripts/ci-check.sh` 同步更新路径

---

## [0.6.0] — 2026-06-07

### ★ Output Protocol v5.0 — Per-Finding File Directory Tree
- 每个 finding 独立文件 + `FindingsIndex` 索引，增量扫描友好
- `SingleFindingFile` 和 `FindingsIndex` JSON Schema
- secguard/secaudit/secreview 三个命令 Step 4 同步到 v5.0 输出格式
- `render-report.py --findings-dir` 支持 v5.0 目录树（向后兼容）

### ★ AI/Renderer Pipeline (v3.0 → v4.0)
- `findings.json` (Schema v1.0) → `render-report.py` 渲染 6 文件输出
- 输出: report.md + results.sarif + summary.json + manifest.json + status.json + delta.json
- `render-report.py` 部署到全部 3 平台 (Claude Code / OpenCode / Gemini CLI)
- `--ci` 模式（exit_code）和 `--format sarif` 独立生成
- SARIF v1.1: partialFingerprints 去重 + GitHub/GitLab/Azure 兼容

### ★ L1-L5 Layered Verification System
- `self-check.sh` — L1 设计一致性: detector↔index↔manifest 交叉校验, 82+ checks
- `ci-check.sh` — L2 结构完整性: JSON 格式、版本一致性、Go 编译+冒烟
- `dev-verify.sh` — L3 部署环境: 5 平台二进制、indexer health, 23 checks
- `e2e-verify.sh` — L4 架构端到端: findings schema、SARIF 2.1.0、quality gate, 37 checks
- `cwe-coverage.sh` — CWE Top 25 + OWASP Top 10 + OWASP API Top 10 自动化验证
- 5 个 AI 入口文件 L1-L5 验证流程统一 (CLAUDE.md/AGENTS.md/CODEBUDDY.md/COPILOT.md/GEMINI.md)

### ★ Manifest-Driven Token System
- `@secguardian` 标记扩散到全部系统文件
- `sync-manifest.sh` 自动同步 tokens（修改 detector 数量只需改 manifest.json）
- `--check` 模式已集成到 self-check.sh §7.6

### Output Quality
- 17 skills 四段式输出完整性要求 (WHAT/HOW/FIX/VERIFY)
- 输出质量门禁检查清单（secguard/secaudit/secreview Step 4）

### Platform & Deployment
- OpenCode: 插件注册自动化 + 命令脚本 + extension.json 格式修复
- `deploy.sh` 插件注册 + 命名空间命令 + CLI/JSON 双回退
- `.superpowers/` 添加到 .gitignore

### JavaScript Support
- 综合 JS 漏洞示例代码仓库 (9 个漏洞)
- indexer JavaScript 支持

### Documentation
- CWE 覆盖率 PPT 更新: 88% (claimed) → 100% (verified)
- 15 页 AI 安全面试技术 PPT
- 北京 AI 安全公司岗位目标分析
- v5.0 findings directory tree 设计决策记录

### Fixes
- threat-catalog 同步 + 移除死 report-template
- detector 文件名统一: 67 个 namespace-name.md 格式
- detector 数量动态化 (dev-verify.sh)
- 版本号修正: 0.5.3 → 0.5.5
- self-check.sh section 7 regex 兼容 HTML 注释标记
- OpenCode extension.json 格式修复
- indexer 使用指令具体化，消除 brute-force 扫描

---

## [0.5.5] — 2026-05-31

- CI 修复 + 跨平台 release workflow
- YAML frontmatter 标准化 (61 个 detector)
- resource 命名空间新增 (6 个检测器)
- 版本号修正: 0.5.3 → 0.5.5

## [0.5.4] — 2026-05-31

- 61 个 detector 文件名标准化为 namespace-name.md 格式
- extension 路径引用对齐 (commands/docs/deploy)
- v3 输出协议设计 (report.md + SARIF)

## [0.5.3] — 2026-05-31

- 跨平台二进制 (15 zips, 5 OS/ARCH × 3 brands)
- 双模解析器 (tree-sitter + pure-Go regex fallback)
- release 脚本平台后缀 zip

## [0.5.2] — 2026-05-31

- 27 skills 扁平化为 3 个父目录
- 死代码删除 (prompts, internal pkgs)
- CodePlan 合并 concept 到 detector
- JS 语言支持 + 16 检测器新增 (60 total)

## [0.5.1] — 2026-05-31

- ★ 输出协议升级 v2.0: 人读/机读分离 — findings/*.json 废弃
- report.md + results.sarif + summary.json 三文件输出
- manifest.json 精简为元数据+检出索引

## [0.5.0] — 2026-05-31

- ★ 架构重构: concept+detector 合并为自包含 detector (WHAT+HOW+FIX 一体化)
- 检测器: 45 → 60 (+33%), 多语言占比: 38% → 69%
- 新增 error 命名空间 (6 检测器) + crypto 扩展 (4→9) + web 扩展 (17→22)
- JavaScript/Node.js 语言支持
- CWE Top 25 覆盖率: 88% → 100%, OWASP API Top 10: → 100%
- 4 个 knowledge/standards (SEI CERT C/C++/Java + OWASP Cheat Sheet)

## [0.4.0] — 2026-05-28

- 初始公开版本
- 60 检测器, 5 语言画像
- Claude Code / OpenCode / Gemini CLI 三平台 extension
