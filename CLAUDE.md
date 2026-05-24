# CLAUDE.md - SecGuardian 开发者指引

## 项目概述

SecGuardian 是企业级白盒安全 AI Agent 辅助解决方案，为 Claude Code、OpenCode、Gemini CLI 提供 3 个独立 extension。

## 快速开发

```bash
# 一键构建 + 双平台部署 (Claude Code + OpenCode)
bash scripts/dev-deploy.sh

# 单独部署到某个平台
bash scripts/deploy-claude.sh       # → .claude/extensions/
bash scripts/deploy-opencode.sh     # → .opencode/skills/ + .opencode/command/
```

## 部署后项目结构

```
secguardian/
├── .claude/extensions/       # Claude Code 项目级 extensions
│   ├── secguard-secguardian/
│   ├── secaudit-secguardian/
│   └── secreview-secguardian/
├── .opencode/                # OpenCode 项目级配置
│   ├── skills/               # 自动发现 skills
│   └── command/              # slash commands
└── .codeagent/               # 扫描输出归档
    ├── secguard-secguardian/scans/<id>/
    ├── secaudit-secguardian/scans/<id>/
    └── secreview-secguardian/scans/<id>/
```

## 源目录结构

```
secguardian/
├── CLAUDE.md              # AI 运行时指引
├── README.md              # 项目说明
├── manifest.json          # 项目级 skill + detector 清单
├── commands/              # 三个全局 slash command
├── skills/                # 每个 skill 一个目录 (SKILL.md + references/)
├── knowledge/             # 可复用知识库
│   ├── concepts/          # 安全概念 (10)
│   ├── languages/         # 语言画像 (4)
│   ├── detectors/         # 检测规则 (26, 6 active)
│   └── protocols/         # 输出协议
├── extensions/            # extension 包定义
├── examples/              # 漏洞示例代码仓库
│   ├── cpp-vuln-demo/     # C/C++ (8 个漏洞)
│   ├── python-vuln-demo/  # Python (9 个漏洞)
│   └── java-vuln-demo/    # Java (8 个漏洞)
├── scripts/
│   ├── package.sh         # 构建 dist/
│   ├── dev-deploy.sh      # 一键构建 + 双平台部署
│   ├── deploy-claude.sh   # 部署到 Claude Code
│   └── deploy-opencode.sh # 部署到 OpenCode
└── dist/                  # 构建输出
```

## 开发循环

```
1. 修改 skills/knowledge/commands 源码
2. bash scripts/dev-deploy.sh   → 一键构建 + 部署双平台
3. 重启 AI CLI
4. 测试命令验证
```

## 输出协议

遵循 Scan Output Protocol 1.0 (`knowledge/protocols/scan-output.md`)。

## 添加新 Skill / Detector

参见 manifest.json 中的 knowledge 和 extensions 字段，修改后重新运行 dev-deploy.sh。
