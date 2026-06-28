# Changelog

All notable changes to SecGuardian.

## [0.9.1] — 2026-06-28

### Added
- **FEATURE-006: Finding Identity Redesign** — SHA-256 作为机器标识（12 hex chars），序号 #1~#N 做人读引用。manifest.json 使用 `seq` + `sha` 替代 `id`。报告表格用 `#N` 替代 `placeholder`。SARIF 使用 SHA 作为 `partialFingerprints`。
- **FEATURE-007: 共享索引** — index.json 移至 `.codeagent/secguardian/` 根级别，三个命令复用。新增 `--force` / `-f` 刷新标志。
- **目录结构简化** — 移除 `scans/` 目录层。扫描 ID 前缀统一为 `scan-`。输出：`.codeagent/secguardian/<cmd>/<scan-id>/`

### Changed
- **安全评分** — 指数衰减公式 `100 × exp(-0.2C - 0.1H - 0.04M - 0.01L)`，避免线性公式触底
- **find_indexer()** — `$HOME` 优先 + `-f` 替代 `-x` + `.config/opencode` 优先路径
- **macOS 兼容** — Step 2 增加 `gtimeout` 回退
- **validate-findings.py** — 移除 `id` 字段强制要求，改为 `detector`
- **Step 3.5a/4c** — 协议文件多路径搜索；validate 不阻塞 renderer
- **secaudit/secreview Step 2a** — 引用 secguard 共享索引逻辑

### Fixed
- 11 个源文件的旧路径引用清理（AGENTS.md、DEVELOPER.md、CI 模板、skill 文档等）
- 评分 `security_score` 覆盖 renderer 计算值的问题
- Delta 对比 manifest `sha` 字段读取 bug
- 修复路线图和 quality_gate 中 `item['id']` 崩溃
- macOS `timeout` 命令兼容性
- 跨语言管线测试 5/5 语言全通过

---

## [0.9.0] — 2026-06-25

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
