# SecGuardian 下一版本待办

> 基线: v0.5.3 | 更新: 2026-06-03

## 优先级 P0 — 阻塞性问题

### 1. CI 跨平台 Release 自动化
**现状**：release.sh 只能本地构建（macOS arm64）。Linux/Windows 二进制依赖 CGO_ENABLED=0 交叉编译（正则回退，无 tree-sitter）。
**目标**：GitHub Actions workflow 在 ubuntu/windows/macos 原生 runner 上构建全平台 tree-sitter 二进制，自动挂载到 Gitee Release。
**影响**：Linux/Windows 用户无法享受 tree-sitter 完整 AST 解析。

### 2. Go 测试覆盖
**现状**：`internal/` 零测试。重构后 parser/indexer 无回归保护。
**目标**：parser_re.go + parser_ts.go 对 5 种语言 examples/ 做等价性测试。indexer 对已知输入验证输出正确性。
**影响**：每次改动靠手工验证，不可持续。

### 3. Markdown Linting CI
**现状**：knowledge/detectors/*.md 等 60+ 文件无格式校验。出现过表格格式错误。
**目标**：`.github/workflows/lint.yml` 添加 markdownlint 步骤，CI 阻断 PR。
**影响**：文档质量不可控。

## 优先级 P1 — 功能完善

### 4. `secguardian.sh` 清理
**现状**：独立 CLI 入口，引用了已删除的 prompt-templates 和 CLI 子命令，功能残破。
**方案**：删除（用户明确表示暂时不需要独立 CLI），或重写为轻量 indexer wrapper。
**影响**：docs/ 中多处引用此脚本，需同步更新。

### 5. Docs 清理
**现状**：`docs/` 含 14+ 文件，多个文档引用已删除/重命名的特性（concepts/、cheatsheets/、prompt-templates/）。
**目标**：更新所有 docs 使其与当前架构一致。删除过时文档。
**影响**：新用户看 docs 会被误导。

### 6. `action.yml` 修复
**现状**：引用不存在的 `findings/` 目录和 `latest` 符号链接。
**目标**：更新为读取 `results.sarif`，兼容 GitHub Code Scanning 最新要求。
**影响**：GitHub Actions 集成不可用。

## 优先级 P2 — 增强

### 7. 用户级部署测试
**现状**：`deploy.sh --user` 理论上支持用户级部署，但从未在真实环境验证。
**目标**：在 `~/.config/opencode/` 和 `~/.claude/plugins/` 下完整测试用户级安装+卸载。
**影响**：用户级部署是最推荐的安装方式，但未经验证。

### 8. `benchmark.sh` 修复或删除
**现状**：TP/FP/FN 计数器永远为 0，detector 匹配逻辑从未被调用。
**方案**：删除或重写为 AI agent 驱动的真实基准测试。
**影响**：低。当前仅作为占位脚本存在。

### 9. Security Score 算法落地
**现状**：协议文档定义了评分算法，但各 skill 的输出模板仍使用固定示例值。
**目标**：确保 AI agent 执行扫描后，report.md 的 §1 执行摘要包含真实计算的评分和等级。
**影响**：商业交付物的核心卖点尚未真正执行。

## 技术债

- [ ] `internal/go.sum` 仅 14 行，验证完整性
- [ ] `.gitignore` 含 6 条指向不存在路径的旧规则
- [ ] v0.3.1 Gitee Release 仍含 11 个重复资产（历史遗留）
- [ ] `extensions/secaudit-secguardian/extension.json` 仅声明 4 种语言（缺 javascript）
- [ ] `detector-index.md` 头部说 60 检测器但命名空间计数总和为 61
