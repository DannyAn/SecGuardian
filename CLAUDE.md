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

## 验证流程 (修改后必须执行)

每次修改代码后，按修改范围执行对应验证层级：

| 你改了什么 | 执行命令 | 耗时 |
|-----------|---------|------|
| skills/knowledge/commands (Markdown) | `bash scripts/self-check.sh` | ~5s |
| deploy.sh / extension.json / 项目结构 | `bash scripts/self-check.sh && bash scripts/ci-check.sh` | ~20s |
| render-report.py / findings-schema.json (架构层) | `bash scripts/self-check.sh && bash scripts/e2e-verify.sh` | ~20s |
| internal/ Go 索引器 | `bash scripts/self-check.sh && bash scripts/ci-check.sh && bash scripts/e2e-verify.sh` | ~35s |
| 发布前全量验证 | `bash scripts/self-check.sh && bash scripts/ci-check.sh && bash scripts/dev-verify.sh && bash scripts/e2e-verify.sh` | ~45s |

### 四条验证命令

| 脚本 | 范围 | 失败时 |
|------|------|--------|
| `self-check.sh` | detector ↔ index ↔ manifest 交叉校验、stale references、Go 编译 | 设计不一致 |
| `ci-check.sh` | JSON 格式、版本号、skill 目录、Go 编译+冒烟 | CI 会失败 |
| `dev-verify.sh` | 二进制、indexer health、部署结构 | 部署环境异常 |
| `e2e-verify.sh` | findings schema、渲染器 6 文件、SARIF 合规、评分、CI gate、delta、3 命令、5 语言 | 架构层损坏 |

### E2E 覆盖矩阵 (10 节, ~37 检查项)

1. Findings Schema 合规 → 4 项 (JSON 有效性、required 字段、4-segment、ID pattern)
2. Renderer 输出 → 9 项 (6 文件生成、单格式、空 findings 处理)
3. SARIF 2.1.0 结构 → 1 项聚合 (version/driver/rules/results/fingerprints/fixes/properties)
4. 4-Segment 质量门禁 → 2 项 (不完整不崩溃、完整全通过)
5. 安全评分计算 → 1 项 (score = 100 - 25×C - 10×H - 3×M - 1×L)
6. CI 门禁 → 2 项 (Critical → FAILED+exit 1; Clean → PASSED+exit 0)
7. Delta 对比 → 1 项 (new/fixed/still_open 计数)
8. 3 命令类型 → 6 项 (manifest.json + report.md 标题)
9. 多语言 → 8 项 (5 语言文件+索引器可用性)
10. 渲染器性能 → 1 项 (单 finding < 5s)

## 添加新 Skill / Detector

参见 manifest.json 中的 knowledge 和 extensions 字段，修改后重新运行 dev-deploy.sh。
