# Changelog

All notable changes to SecGuardian.

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
