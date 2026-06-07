# CLAUDE.md - SecGuardian 开发者指引

## 项目概述

SecGuardian 是企业级白盒安全 AI Agent 辅助解决方案，为 Claude Code、OpenCode、Gemini CLI 提供 3 个独立 extension。

## 快速开发

```bash
# 一键构建 + 三平台部署
bash scripts/dev-deploy.sh

# 单独部署到某个平台
bash scripts/deploy.sh cc --user     # Claude Code → ~/.claude/plugins/secguardian/
bash scripts/deploy.sh nga --user     # OpenCode → ~/.config/opencode/
bash scripts/deploy.sh cac --user     # Gemini CLI → ~/.gemini/extensions/secguardian/
```

## Claude Code 插件注册机制 (关键)

**Claude Code v2.1.x 不会自动发现仅靠文件复制的本地插件**。插件必须通过 marketplace 系统注册：

1. 插件文件部署到 `~/.claude/plugins/secguardian/`
2. 创建本地 marketplace 结构：`~/.claude/plugins/marketplaces/secguardian-local/`
3. `marketplace.json` 必须位于 `.claude-plugin/` 子目录下（非根目录）
4. 通过 `claude plugin marketplace add` + `claude plugin install` 注册
5. `deploy.sh` 已自动化以上全部流程（含 CLI 不可用时的 JSON 回退）

**验证插件已安装：**
```bash
claude plugin list                    # 查看 secguardian@secguardian-local 状态
claude plugin validate ~/.claude/plugins/secguardian  # 验证插件结构
```

## 命令命名空间策略 (防冲突)

当其他公司也开发了 `secguard`/`secaudit`/`secreview` 命令时，通过以下机制确保互不影响：

| 机制 | 说明 |
|------|------|
| **短命令名** | `/secguard`、`/secaudit`、`/secreview` — 日常便捷使用 |
| **命名空间命令** | `/secguardian:secguard`、`/secguardian:secaudit`、`/secguardian:secreview` — 通过 `commands/secguardian/` 子目录自动获得插件名前缀 |
| **Claude Code 原生歧义消除** | 命令冲突时 Claude Code 自动展示所有匹配命令及来源插件，用户可选择 |
| **插件名即命名空间** | `plugin.json` 中 `"name": "secguardian"` 作为全局唯一标识 |

**实现方式**：`commands/` 目录同时包含平铺命令文件和 `secguardian/` 子目录副本：
```
commands/
├── secguard.md           # /secguard (短名)
├── secaudit.md           # /secaudit (短名)
├── secreview.md          # /secreview (短名)
└── secguardian/          # 子目录 = 命名空间
    ├── secguard.md       # /secguardian:secguard (命名空间名)
    ├── secaudit.md       # /secguardian:secaudit (命名空间名)
    └── secreview.md      # /secguardian:secreview (命名空间名)
```

## 部署后项目结构

```
~/.claude/
├── plugins/
│   ├── secguardian/                      # 插件源文件（marketplace symlink 目标）
│   │   ├── .claude-plugin/plugin.json
│   │   ├── commands/
│   │   │   ├── secguard.md               # /secguard
│   │   │   ├── secaudit.md               # /secaudit
│   │   │   ├── secreview.md              # /secreview
│   │   │   └── secguardian/              # 命名空间子目录
│   │   │       ├── secguard.md           # /secguardian:secguard
│   │   │       ├── secaudit.md           # /secguardian:secaudit
│   │   │       └── secreview.md          # /secguardian:secreview
│   │   ├── skills/                       # 17 个安全审计 skills
│   │   ├── knowledge/                    # 60 检测器 + 5 语言画像 + 协议
│   │   └── scripts/                      # secguardian-index 二进制
│   ├── cache/secguardian-local/          # 插件缓存（claude plugin install 创建）
│   ├── marketplaces/secguardian-local/   # 本地 marketplace
│   │   ├── .claude-plugin/marketplace.json
│   │   └── plugins/secguardian -> ../../../secguardian  (symlink)
│   └── installed_plugins.json            # 插件注册表
└── settings.json                         # enabledPlugins 条目
```

## 源目录结构

```
secguardian/
├── CLAUDE.md              # AI 运行时指引（本文件）
├── README.md              # 项目说明
├── manifest.json          # 项目级 skill + detector 清单
├── commands/              # 三个全局 slash command
├── skills/                # 每个 skill 一个目录 (SKILL.md + references/)
├── knowledge/             # 可复用知识库
│   ├── threat-catalog.md   # 威胁目录索引
│   ├── languages/          # 语言画像 (5)
│   ├── detectors/          # 检测规则 (60, 自包含 WHAT+HOW+FIX)
│   ├── standards/          # 业界标准映射 (4)
│   └── protocols/         # 输出协议
├── extensions/            # extension 包定义
├── examples/              # 漏洞示例代码仓库
│   ├── cpp-vuln-demo/     # C/C++ (8 个漏洞)
│   ├── python-vuln-demo/  # Python (9 个漏洞)
│   └── java-vuln-demo/    # Java (8 个漏洞)
├── scripts/
│   ├── package.sh         # 构建 dist/
│   ├── dev-deploy.sh      # 一键构建 + 三平台部署
│   ├── deploy.sh          # 统一部署入口（核心脚本）
│   ├── deploy-claude.sh   # 部署到 Claude Code（调用 deploy.sh cc）
│   └── deploy-opencode.sh # 部署到 OpenCode（调用 deploy.sh nga）
└── dist/                  # 构建输出
```

## 开发循环

```
1. 修改 skills/knowledge/commands 源码
2. bash scripts/dev-deploy.sh   → 一键构建 + 部署三平台
3. 重启 AI CLI
4. 测试命令验证:
   - /secguard ./src            # 短命令
   - /secguardian:secguard ./src # 命名空间命令（冲突时使用）
```

## 输出协议

遵循 Scan Output Protocol (`knowledge/protocols/scan-output.md`)。

### AI/Renderer 分离架构 (v4.0+)

扫描性能优化：AI 只输出结构化 `findings.json`（遵循 `knowledge/protocols/findings-schema.json`），
由 `scripts/render-report.py` 渲染生成 report.md + results.sarif + summary.json + manifest.json + status.json + delta.json。

```bash
# 渲染器使用
python3 scripts/render-report.py \
  --findings .codeagent/<ns>/scans/<id>/findings.json \
  --index .codeagent/<ns>/scans/<id>/index.json \
  --output .codeagent/<ns>/scans/<id>/

# CI 模式（设置 exit_code）
python3 scripts/render-report.py --ci \
  --findings findings.json --output ./output/

# 只生成特定文件
python3 scripts/render-report.py --format sarif \
  --findings findings.json --output ./output/
```

**AI 职责**: 语义分析 → 输出 findings.json（每个 finding 含完整四段式数据）
**Renderer 职责**: 模板渲染 → 安全评分计算 → CI 门禁 → 所有格式化输出

## 验证流程 — L1-L5 分层验证体系

> 这是 SecGuardian 的可推广验证方法论。新工程师或 AI Agent 修改代码后，按"改了什么 → 跑哪层"执行。
> 完整方法论见 AGENTS.md §验证流程，本文件提供快速参考和 Claude Code 特定补充。

### 五层验证

| 层 | 命令 | 覆盖范围 | 耗时 | 何时运行 |
|----|------|---------|------|---------|
| **L1 设计一致性** | `bash scripts/self-check.sh` | detector ↔ index ↔ manifest 交叉校验、stale references、Go 编译 (~82 项) | ~5s | 每次 commit 前 |
| **L2 结构完整性** | `bash scripts/ci-check.sh` | JSON 格式、版本一致性、skill 目录、Go 编译+冒烟 | ~15s | push 前 |
| **L3 部署环境** | `bash scripts/dev-verify.sh` | 5 平台二进制、indexer health、三平台部署结构 (23 项) | ~10s | 部署后 |
| **L4 架构端到端** | `bash scripts/e2e-verify.sh` | findings schema 合规、渲染器 6 文件、SARIF 2.1.0、4-segment 质量门禁、安全评分、CI gate、delta、3 命令、5 语言 (37 项) | ~15s | 修改架构层后 (**必须**) |
| **L5 全量发布** | L1 → L2 → L3 → L4 顺序执行 | 全覆盖 | ~45s | 发布前 |

### 按修改范围选择验证层

```bash
# 日常修改 (skills/knowledge/commands) — L1
bash scripts/self-check.sh

# 修改了 deploy.sh / extension.json — L1 + L2
bash scripts/self-check.sh && bash scripts/ci-check.sh

# 修改了 render-report.py / findings-schema.json — L1 + L4
bash scripts/self-check.sh && bash scripts/e2e-verify.sh

# 修改了 internal/ (Go 索引器) — L1 + L2 + L3 + L4
bash scripts/self-check.sh && bash scripts/ci-check.sh && bash scripts/dev-verify.sh && bash scripts/e2e-verify.sh

# 发布前全量 — L5
bash scripts/self-check.sh && bash scripts/ci-check.sh && bash scripts/dev-verify.sh && bash scripts/e2e-verify.sh
```

### CI 模式

```bash
bash scripts/e2e-verify.sh --ci     # 失败时 exit 1，适合 CI pipeline
bash scripts/e2e-verify.sh --quick  # 跳过第 9 节 (多语言索引)，快速反馈
```

### 可推广模式

这套 L1-L5 分层验证体系可用于任何 AI Agent Native 项目：
1. 每个 AI 入口文件（CLAUDE.md / AGENTS.md / GEMINI.md）必须包含验证流程
2. 分层命名：L1(设计) → L2(结构) → L3(部署) → L4(架构) → L5(全量)
3. 每层一个独立脚本，非零退出码
4. "改了什么 → 跑哪层"映射表，新工程师无需猜测
5. CI 模式确保 pipeline 可集成

## 添加新 Skill / Detector

参见 manifest.json 中的 knowledge 和 extensions 字段，修改后重新运行 dev-deploy.sh。
