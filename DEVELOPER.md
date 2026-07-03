# DEVELOPER.md -- SecGuardian 开发指南

## 目录

- [快速开始](#快速开始)
- [项目架构](#项目架构)
- [日常开发](#日常开发)
- [规则微调](#规则微调)
- [构建与部署](#构建与部署)
- [发布流程](#发布流程)
- [CI/CD](#cicd)
- [PR 门禁与分支保护](#pr-门禁与分支保护)
- [测试与验证](#测试与验证)
- [常见任务](#常见任务)
- [故障排除](#故障排除)

---

## 快速开始

### 环境依赖

| 工具 | 最低版本 | 用途 |
|------|---------|------|
| Bash | 4.0+ | 构建脚本 |
| jq | 1.6+ | JSON 处理（打包 extension.json） |
| zip | 任意 | 创建发布包（仅 `--zip` 时需要） |

### 一分钟跑起来

```bash
# 1. 克隆项目
cd /path/to/secguardian

# 2. 一键构建 + 部署到所有平台
bash scripts/deploy.sh all

# 3. 重启 AI CLI（Claude Code / OpenCode / Gemini CLI）

# 4. 验证：执行扫描命令
#    Claude Code / OpenCode 中运行：
#      /secguard examples/python-vuln-demo/src/ critical
#      /secaudit examples/python-vuln-demo/src python
#      /secreview examples/python-vuln-demo/src/
```

---

## 项目架构

### 核心设计理念

SecGuardian 是 **AI-native** 的安全扫描工具。它不包含传统的 SAST 引擎，而是将安全知识（检测规则、语言画像、漏洞模式）编码为 AI Agent 的 skill prompt，由 AI 模型直接阅读源码完成漏洞发现。

这意味着：
- **添加检测规则** = 编写/修改 knowledge 文件中的 Markdown prompt
- **调整检测行为** = 修改 skill 的 SKILL.md 提示词
- **漏洞示例** = examples/ 目录下的真实源码文件，用于验证检测效果

### 三层架构

```
commands/          ← 入口层：3 个 slash command 定义
skills/            ← 执行层：11 个 skill（secaudit 1 + secguard 5 + secreview 5）
knowledge/         ← 知识层：安全概念、语言画像、检测规则、输出协议
extensions/        ← 打包层：3 个 extension 的 extension.json 清单
scripts/           ← 工具层：构建、部署、打包脚本
examples/          ← 验证层：各语言漏洞示例代码
```

### 三个 Extension 的关系

| Extension | Command | 定位 | Skill 数量 | 覆盖语言 |
|-----------|---------|------|-----------|---------|
| secguard | `/secguard` | 安全加固检查：API 级别的漏洞检测 | 5 | C++, Go, Java, Python, JS |
| secaudit-secguardian | `/secaudit` | 全量安全审计：13 个审计域覆盖 | 1 | 语言无关 |
| secreview-secguardian | `/secreview` | 安全编码审查：反模式与设计缺陷 | 5 | C++, Go, Java, Python, JS |

- `/secguard` 关注 "这行 API 调用有没有漏洞"（精确 — 5 语言）
- `/secreview` 关注 "这段代码的设计模式是否安全"（语义 — 5 语言）
- `/secaudit` 关注 "这个安全领域有没有全面覆盖"（纵深 — 1 workflow -> 13 审计域）

### 知识库结构

```
knowledge/
├── audit-rules/         ← 13 个审计域规则（唯一安全知识源）
├── guard-rules/         ← 67 个检测规则（7 安全分类）
├── review-rules/        ← 5 语言审查规则
├── standards/           ← 标准映射（OWASP ASVS、SEI CERT、CWE Mapping）
├── protocols/           ← 输出协议（scan-output、SARIF 2.1.0）
├── languages/           ← 语言画像（5 语言危险 API + 框架安全说明）
└── threat-catalog.md    ← 威胁目录索引
```

### 输出协议

所有扫描结果遵循 Scan Output Protocol 2.0，输出到：

```
.codeagent/<extension-name>/scans/<scan-id>/
├── manifest.json          ← 扫描元信息 + 发现汇总
└── findings/
    └── <finding-id>.json  ← 每个漏洞的详细信息
        ├── id, severity, title
        ├── detector (CWE, CVSS)
        ├── location (file, line, code context, diff_status)
        ├── analysis (description, impact, confidence)
        └── remediation (code_before, code_after, effort)
```

严重度前缀：`C-` (Critical), `H-` (High), `M-` (Medium), `L-` (Low), `I-` (Info)

完整规范见 `knowledge/protocols/scan-output.md`。

---

## 日常开发

### 开发循环

```
1. 修改源码（skills/knowledge/commands 等）
2. bash scripts/deploy.sh all    ← 一键构建 + 部署
3. 重启 AI CLI
4. 运行 /secaudit 或 /secguard 对 examples/ 执行扫描
5. 检查 .codeagent/ 下的输出结果
6. 根据结果调整源码
```

### 使用 build.sh 的精细控制

```bash
# 一键构建 + 全平台部署（开发首选）
bash scripts/deploy.sh all

# 仅构建，不部署
bash scripts/package.sh

# 构建 + 部署到指定平台
bash scripts/deploy.sh cc      # Claude Code
bash scripts/deploy.sh nga     # OpenCode
bash scripts/deploy.sh cac     # Gemini CLI

# 卸载
bash scripts/deploy.sh --uninstall

# 构建发布产物
bash scripts/release.sh 0.4.0
```

### 文件修改影响范围

| 修改位置 | 影响范围 | 需要重新部署 |
|----------|---------|------------|
| `knowledge/threat-catalog.md*.md` | 所有 3 个 extension | `deploy.sh all` |
| `knowledge/languages/*.md` | 所有 3 个 extension | `deploy.sh all` |
| `knowledge/guard-rules/*.md` | 仅 secguard | `deploy.sh all` |
| `knowledge/protocols/*.md` | 所有 3 个 extension | `deploy.sh all` |
| `skills/<cmd>-*/SKILL.md` | 仅对应 extension | `deploy.sh all` |
| `skills/<cmd>-*/references/*.md` | 仅对应 extension | `deploy.sh all` |
| `commands/<cmd>.md` | 仅对应 extension | `deploy.sh all` |
| `extensions/*/extension.json` | 仅对应 extension | `deploy.sh all` |
| `commands/gemini/*.toml` | 仅 Gemini CLI | `deploy.sh all` |

### 部署后的目录结构

```
secguardian/                      ← 项目根目录
├── .claude/extensions/           ← Claude Code 部署目标
│   ├── secguard/
│   ├── secaudit-secguardian/
│   └── secreview-secguardian/
├── .opencode/                    ← OpenCode 部署目标
│   ├── skills/                   ← 所有 25 个 skill 平铺
│   │   └── .knowledge-<ext>/     ← 知识文件按 extension 隔离
│   └── command/                  ← slash command .md
└── .gemini/                      ← Gemini CLI 部署目标
    ├── skills/                   ← 所有 skill
    ├── commands/                 ← TOML 格式 command
    └── GEMINI.md                 ← Gemini 上下文引导
```

---

## 规则微调

### 调整检测灵敏度

检测灵敏度主要通过 knowledge/ 文件控制。

**修改安全概念的检测策略**：

编辑 `knowledge/threat-catalog.md<concept>.md`，调整 Detection Strategy 部分：

```markdown
## Detection Strategy

### Core Principles
- 搜索危险 API 直接调用（fopen/strcpy/gets）
- 检测缺少长度检查的缓冲区操作
- 关注循环中的内存写入

### Patterns to Flag（增加/减少检测模式）
- `memcpy(dest, src, size)`  -- 当 size 为变量时标记
- `strcat(dest, src)`         -- 总是标记
- `sprintf(buf, fmt, ...)`    -- 当 fmt 包含用户输入时标记

### False Positive Exclusion（减少误报）
- 已使用 `strncpy`/`snprintf` 等安全替代函数
- dest 大小已在上一行通过 `sizeof` 验证
- 函数签名中明确传递了缓冲区大小
```

**修改语言危险 API 列表**：

编辑 `knowledge/languages/<lang>.md`，增删 `## Danger API` 表格中的条目：

```markdown
| Function | Risk | Safe Alternative |
|----------|------|-----------------|
| gets()   | Buffer overflow, no size limit | fgets(buf, size, stdin) |
| strcpy() | Buffer overflow | strncpy() + manual null terminator |
| system() | Command injection | execve() with separated args |
| popen()  | Command injection | fork() + execve() + pipe() |
```

### 修改 Detector 检测逻辑

编辑 `knowledge/guard-rules/<detector>.md`。每个 detector 定义了精确的多步检测流程：

```markdown
## Detection Logic

### Step 1: Identify target patterns
- 搜索 `malloc`/`calloc`/`realloc` 调用，追踪返回指针的所有别名
- BAD: `void* p = malloc(n); void* q = p;`
- GOOD: `void* p = malloc(n); /* single-owner, no aliasing */`

### Step 2: Trace free operations
- 追踪每个 unique pointer 对应的 `free()` 调用
- BAD: `free(p); free(q);` (p 和 q 指向同一内存)
- GOOD: `free(p); p = NULL;` (clear pointer after free)

### Step 3: Verify no use after free
- 检查所有指针解引用是否在 free 之前
- BAD: `free(p); *p = 0;`
- GOOD: `*p = 0; free(p); p = NULL;`
```

### 修改 Skill 提示词

编辑 `skills/<cmd>-<name>/SKILL.md`，调整执行步骤或检查清单。

**调整 secguard 扫描行为**（如 `skills/secguard-python/SKILL.md`）：

- 修改优先级表格中的漏洞类型权重
- 调整框架覆盖列表（Django/Flask/FastAPI）
- 变更分析深度要求

**调整 secaudit 审计清单**（如 `skills/secaudit-cryptography/SKILL.md`）：

- 增删审计检查项（`[C]` 严重 / `[H]` 高 / `[M]` 中）
- 修改常见漏洞模式代码示例
- 调整 OWASP/CWE 参考映射

**调整 secreview 审查范围**（如 `skills/secreview-go/SKILL.md`）：

- 修改语义级别检查项
- 增删反模式条目
- 调整编码标准合规要求

### 启用新 Detector

1. 编写 `knowledge/guard-rules/<new-detector>.md`（参考已有 detector 格式）
2. 在 `manifest.json` 的 `knowledge.detectors` 中添加条目
3. 在对应 `extensions/secguard/extension.json` 的 `knowledge.detectors` 中添加
4. 重新部署：`bash scripts/deploy.sh all`
5. 用 examples/ 验证检测效果

### 添加新安全概念

1. 编写 `knowledge/threat-catalog.md<new-concept>.md`（参考已有概念格式）
2. 在 `manifest.json` 的 `knowledge.concepts` 中添加
3. 更新使用该概念的 extension 的 `extension.json` 中的 `knowledge.concepts`
4. 重新部署

### 微调技巧

- **降低误报**：在 concept 文件中加强 `False Positive Exclusion` 描述
- **降低漏报**：在 language 文件中扩展 `Danger API` 列表，降低检测阈值
- **提升置信度**：在 detector 或 skill 中添加更多 evidence 收集步骤
- **加速扫描**：在 skill 中缩小初始搜索范围，使用 namespace filter
- **提升深度**：在 secaudit skill 中添加更多分析阶段

---

## 构建与部署

### 构建流程

```
extensions/<name>/extension.json        → 读取清单
                              ↓
scripts/package.sh                      → 组装 dist/
  │
  ├── .claude-plugin/plugin.json        ← jq 生成
  ├── commands/<cmd>.md                 ← 从 commands/ 复制
  ├── skills/<skill-name>/              ← 从 skills/ 复制
  │   ├── SKILL.md
  │   └── references/                   ← （可选）
  └── knowledge/                        ← 按清单选择性复制
      ├── concepts/
      ├── languages/
      ├── detectors/                    ← 仅 secguard extension
      └── protocols/
                              ↓
dist/<extension-name>/                  → 构建产物
                              ↓
scripts/deploy.sh {cc,nga,cac}  → 平台部署
```

### 单独部署到某个平台

```bash
# Claude Code
bash scripts/deploy.sh cc

# OpenCode
bash scripts/deploy.sh nga

# Gemini CLI
bash scripts/deploy.sh cac
```

### 构建系统依赖

`package.sh` 使用 `jq` 处理 extension.json 中的数据：
- 读取 command name、skill 列表、knowledge 依赖
- 生成 `.claude-plugin/plugin.json`

如果系统未安装 `jq`：`brew install jq` (macOS) 或 `apt-get install jq` (Linux)。

---

## 发布流程

### 版本更新

```bash
# 一键同步版本号到所有文件
bash scripts/sync-version.sh 0.5.0
```

同步范围：

| 文件 | 字段 |
|------|------|
| `manifest.json` | 顶级 `version` |
| `extensions/secguard/extension.json` | `version` |
| `extensions/secaudit-secguardian/extension.json` | `version` |
| `extensions/secreview-secguardian/extension.json` | `version` |
| `internal/main.go` | `const version`（需手动更新） |

### 发布检查清单

- [ ] 所有版本号一致（运行 `bash scripts/ci-check.sh` 验证）
- [ ] 用 examples/ 验证 3 个命令均能正常输出
- [ ] 运行 `bash scripts/deploy.sh all` 确认构建和部署无报错
- [ ] 检查 `.codeagent/` 下的输出符合 Scan Output Protocol 2.0

### 构建发布产物并发布到 Gitee

```bash
# 1. 构建所有发布产物到 dist/release/<version>/
bash scripts/release.sh 0.4.0

# 2. 发布到 Gitee Release（自动创建 tag + 上传产物）
export GITEE_TOKEN="your-token"
bash scripts/gitee-release.sh 0.4.0
```

产物说明见 `scripts/gitee-release.sh` 中的 Release Body，也可在 [Gitee Release 页面](https://gitee.com/jonyan/secguardian/releases) 查看。

---

## CI/CD

SecGuardian 配置了 GitHub Actions 和 Gitee Go 双平台 CI，均在 push/PR 到 develop 或 main 分支时自动触发。

### 本地 CI 检查（push 前推荐运行）

```bash
bash scripts/ci-check.sh           # 完整检查（含 Go 编译 + 索引器冒烟测试）
bash scripts/ci-check.sh quick     # 快速检查（仅 JSON 格式 + 版本号 + 目录完整性）
```

检查内容：项目结构统计 → Extension JSON 格式 → 版本号一致性 → Skill 目录完整性 → Go 编译 + 冒烟测试。

### GitHub Actions

配置文件：`.github/workflows/ci.yml`

- **Build**: Go 编译 + 版本验证 + detector 列表 + scan/audit 调用验证（ubuntu/macos/windows 矩阵）
- **Knowledge File Check**: detector 知识库文件 frontmatter 完整性验证
- **Example Coverage Check**: examples/ 目录的 CWE 标记覆盖率检查

状态入口：GitHub 仓库 → Actions 标签。

### Gitee Go（需手动开通一次）

配置文件：`.gitee-ci.yml`

**开通步骤：**

1. 打开仓库主页：https://gitee.com/jonyan/secguardian
2. 顶部导航点击「**服务**」→「**Gitee Go**」
3. 点击「**新建流水线**」，选择「**代码源配置**」
4. 流水线自动读取 `.gitee-ci.yml`，确认配置无误后保存
5. 之后每次 push 到 develop/main 自动运行

流水线阶段：

| 阶段 | 检查项 |
|------|--------|
| 完整性检查 | 项目结构统计、Extension JSON 格式、版本号一致性 |
| 编译与验证 | Go 编译、`--health` 自检、detector 列表、scan/audit 调用、索引器端到端测试 |

> 如果开通后流水线不触发，检查：Gitee Go 是否有剩余构建时长（设置 → 计费中心查看），以及 `.gitee-ci.yml` 的分支匹配规则是否正确。

---

## IDE 级前置检测

在日常开发中，推荐在代码提交前自动运行检查，避免推送后 CI 才报错。支持两种方式：Git Hook 和 IDE 插件。

### 方式一：Git Pre-push Hook（推荐）

在 `.git/hooks/` 下创建 `pre-push` 钩子，每次 `git push` 前自动运行：

```bash
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash
# SecGuardian pre-push hook
# 每次 push 前自动运行快速 CI 检查

echo ""
echo "### SecGuardian CI Check (pre-push) ###"

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# 快速模式：验证 JSON 格式 + 版本号 + Skill 目录
bash "$PROJECT_ROOT/scripts/ci-check.sh" quick
EXIT=$?

if [ $EXIT -ne 0 ]; then
    echo ""
    echo "❌ CI 检查未通过，push 已阻止。"
    echo "   修复后重试，或跳过检查: git push --no-verify"
    exit 1
fi

echo "✓ 检查通过，继续 push..."
exit 0
EOF

chmod +x .git/hooks/pre-push
```

**注意**：Git hooks 存储在 `.git/` 下，不会被版本控制。团队成员需要各自执行上述命令安装 Hook。

**覆盖推送**：紧急情况下可用 `git push --no-verify` 跳过 Hook。

### 方式二：VS Code / JetBrains 任务集成

在 IDE 中配置保存或提交时自动运行检查。以 VS Code 为例，在 `.vscode/tasks.json` 中配置：

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "SecGuardian CI Check",
      "type": "shell",
      "command": "bash",
      "args": ["scripts/ci-check.sh", "quick"],
      "group": {
        "kind": "test",
        "isDefault": true
      },
      "presentation": {
        "reveal": "always",
        "panel": "new"
      },
      "problemMatcher": []
    }
  ]
}
```

配置后可通过 `Cmd+Shift+P` → `Tasks: Run Test Task` 一键运行，或绑定到保存时触发。

### 方式三：项目级推荐配置

将以下配置添加到 `.vscode/settings.json`（用户级，不会被提交），保存文件时自动格式化：

```json
{
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "[markdown]": {
    "files.trimTrailingWhitespace": false
  },
  "[json]": {
    "editor.formatOnSave": true
  }
}
```

### 检查级别速查

| 场景 | 命令 | 耗时 |
|------|------|------|
| 提交前（最小化） | `bash scripts/ci-check.sh quick` | < 1s |
| Push 前（推荐） | `bash scripts/ci-check.sh quick` | < 1s |
| CI 平台 | `.gitee-ci.yml` / `.github/workflows/ci.yml` | ~60s |
| 发布前（最严格） | `bash scripts/ci-check.sh && bash tools/check.sh` | ~10s |

---

## 测试与验证

### 使用漏洞示例验证

examples/ 目录包含三个语言的有意漏洞代码：

```
examples/
├── cpp-vuln-demo/src/
│   ├── parser.c          ← strcpy overflow, sprintf overflow, format string
│   ├── allocator.c       ← double free, use-after-free, null deref, int overflow
│   └── network.c         ← int overflow bypass, null deref, buffer overflow
├── python-vuln-demo/src/
│   ├── webapp.py         ← SQL injection, cmd injection, SSTI, hardcoded secret
│   ├── crypto_utils.py   ← MD5 hash, pickle deserialization, weak random
│   └── file_handler.py   ← SSRF, path traversal
└── java-vuln-demo/src/
    ├── AuthController.java       ← weak hash, hardcoded secret, session fixation
    ├── UserController.java       ← SQL injection, IDOR, XXE
    └── DeserializationService.java ← unsafe deserialization, weak random
```

### 验证 secguard 命令

```bash
# 全量扫描 C++ 示例
/secguard examples/cpp-vuln-demo/src/ critical

# 仅检查内存类漏洞
/secguard examples/cpp-vuln-demo/src/ memory.*

# Git diff 增量扫描
/secguard examples/cpp-vuln-demo/src/ diff

# Python 示例
/secguard examples/python-vuln-demo/src/ critical

# Java 示例
/secguard examples/java-vuln-demo/src/ critical
```

预期结果：检查 `.codeagent/secguardian/scans/scans/<scan-id>/manifest.json`，应检出对应语言中注释标注的漏洞。

### 验证 secaudit 命令

```bash
# 全量审计（自动加载所有 13 个审计域）
/secaudit examples/python-vuln-demo/src python

# 单项聚焦
/secaudit examples/python-vuln-demo/src python --focus cryptography
/secaudit examples/java-vuln-demo/src java --focus auth-and-session
/secaudit examples/python-vuln-demo/src python --focus input-validation

# 仅查看可用审计域
/secaudit
```

### 验证 secreview 命令

```bash
# C++ 代码安全规范审查
/secreview examples/cpp-vuln-demo/src/

# Python 代码安全规范审查
/secreview examples/python-vuln-demo/src/

# 自动语言检测
/secreview examples/java-vuln-demo/src/
```

### 增加新测试用例

1. 在对应语言示例目录下添加源码文件
2. 用注释标注漏洞：`// VULNERABILITY [CWE-xxx]: description`
3. 重新运行扫描命令验证检出

---

## 常见任务

### 为新语言添加支持

假设要添加 Rust 支持：

```
1. 编写 knowledge/languages/rust.md（危险 API 列表 + 框架安全说明）
2. 编写 knowledge/threat-catalog.md 中 Rust 特有安全概念（如需要）
3. 编写 skills/secguard-rust/SKILL.md（扫描提示词）
4. 编写 skills/secreview-rust/SKILL.md（审查提示词，可选）
5. 在 extensions/secguard/extension.json 中注册
6. 在 extensions/secreview-secguardian/extension.json 中注册（可选）
7. 更新 manifest.json
8. 创建 examples/rust-vuln-demo/ 测试用例
9. bash scripts/deploy.sh all
10. 验证：/secguard examples/rust-vuln-demo/src/
```

### 添加新的 secaudit 审计领域

```
1. 编写 skills/secaudit-<name>/SKILL.md（参考 cryptography 等格式）
2. 在 extensions/secaudit-secguardian/extension.json 的 skills 数组中添加
3. 更新 manifest.json 的 secaudit skill 列表
4. bash scripts/deploy.sh all
```

### 修改命令输出格式

1. 修改 `knowledge/protocols/scan-output.md`（协议定义）
2. 修改对应的 `skills/<cmd>-*/SKILL.md`（让 AI 按照新格式输出）
3. 同步更新 `commands/<cmd>.md`（命令使用说明）
4. 如果修改了 schema，也要更新 commands/gemini/*.toml
5. 重新部署并验证

### 更新 Manifest

```bash
# manifest.json 是项目的中心注册表，修改后需要重新部署
vim manifest.json
bash scripts/deploy.sh all
```

Manifest 的结构：

```json
{
  "version": "0.1.0",
  "knowledge": {
    "concepts": ["sql-injection", "command-injection", ...],
    "languages": ["cpp", "java", "python", "go"],
    "detectors": [
      { "name": "buffer-overflow", "namespace": "memory", "cwe": "CWE-120", "status": "active" },
      ...
    ]
  },
  "extensions": {
    "secguard": {
      "command": "secguard",
      "description": "...",
      "platforms": ["claude-code", "opencode", "gemini-cli"],
      "skills": [
        { "name": "java", "language": "java", ... },
        ...
      ],
      "output": { "base_dir": ".codeagent", "protocol": "scan-output/1.0" }
    }
    ...
  }
}
```

### 调试单个 Skill

1. 在 AI CLI 中直接粘贴 SKILL.md 内容作为 prompt 执行
2. 观察输出是否匹配预期格式
3. 调整 SKILL.md 提示词，重新测试
4. 满意后 `bash scripts/deploy.sh all` 正式部署

---

## 故障排除

### 部署后命令不生效

1. 确认 AI CLI 已完全重启
2. 检查部署目标目录是否有对应文件
3. Claude Code：检查 `.claude/extensions/<name>/` 是否存在
4. OpenCode：检查 `.opencode/skills/` 和 `.opencode/command/`
5. Gemini CLI：检查 `.gemini/skills/` 和 `.gemini/commands/`

### 扫描未检出预期漏洞

1. 检查漏洞是否在当前 active detector 的覆盖范围内
2. 检查对应的 knowledge/languages 文件是否列出了相关危险 API
3. 检查对应的 knowledge/guard-rules 文件的检测策略是否覆盖该模式
4. 尝试降低扫描范围（仅扫描单文件而非整个目录）
5. 调整对应 skill 的 SKILL.md，增加更明确的检测指令

### 误报过多

1. 在对应 `knowledge/threat-catalog.md<concept>.md` 中加强 `False Positive Exclusion` 规则
2. 在对应 detector 的 knowledge 文件中添加 FP 排除条件
3. 在对应 skill 中增加验证步骤（如要求 AI 确认上下文后才报告）

### 构建失败

```bash
# 检查 jq 是否安装
which jq && jq --version

# 检查 extension.json 格式是否正确
jq . extensions/secguard/extension.json > /dev/null && echo "OK"

# 检查 skills 引用是否与文件系统匹配
# extension.json 的 skills[] 中的 name 应与 skills/<cmd>-<name>/ 目录对应
ls skills/ | sort
jq -r '.skills[].name' extensions/secaudit-secguardian/extension.json | sort
```

### package.sh 报错

常见原因：
- extension.json 中声明的 skill 在 `skills/` 目录下不存在
- extension.json 中声明的 knowledge 文件在 `knowledge/` 目录下不存在
- JSON 格式错误（逗号、引号不匹配）

排查方法：
```bash
# 手动检查每个 skill 目录是否存在
ext="secguard"
for skill in $(jq -r '.skills[].name' "extensions/$ext/extension.json"); do
  [ -d "skills/${ext%\-secguardian}-$skill" ] && echo "OK: $skill" || echo "MISSING: $skill"
done
```

### Gemini CLI TOML 命令问题

- 检查 `commands/gemini/` 下的 TOML 文件格式是否正确
- TOML 中的 prompt 使用 `{{args}}` 获取用户参数
- deploy-gemini.sh 会自动将 `commands/<cmd>.md` 中的 `<path>` 替换为 `{{args}}`
- Gemini CLI 部署后会在 `.gemini/` 生成 `GEMINI.md` 上下文文件

---

## 参考资源

- 项目 README: `README.md`
- AI 运行时指引: `CLAUDE.md`（开发时 AI 助手会读取）
- 输出协议: `knowledge/protocols/scan-output.md`
- 检测器索引: `knowledge/language-index.md`
- 各语言速查表: `skills/<cmd>-<lang>/references/<lang>-security-cheatsheet.md`
- 各语言反模式: `skills/secreview-<lang>/references/<lang>-anti-patterns.md`
- OWASP ASVS 认证参考: `knowledge/standards/owasp-asvs-auth.md`

---

## PR 门禁与分支保护

> SecGuardian 使用 GitHub Actions + Branch Protection 实现 PR 合并前的自动化质量门禁。

### 分支策略

| 分支 | 用途 | 保护级别 |
|------|------|---------|
| `develop` | 日常开发、功能集成 | 🔒 全保护 |
| `master` | 发布版本 | 🔒 全保护 |

### 合并流程

```mermaid
gitGraph
  commit id:"日常开发"
  branch feature/xxx
  commit id:"功能开发"
  commit id:"完成"
  checkout develop
  merge feature/xxx tag:"PR → CI 自动触发"
```

1. 从 `develop` 创建功能分支：`git checkout -b feature/xxx`
2. 开发完成后提 PR → `develop`
3. CI 自动运行 10+ 个 job（见下方）
4. **全部通过 + 至少 1 人 Review** → 可合并
5. 合并后 CI 在 `develop` 上再次触发

### 门禁检查清单（PR 必须全部通过）

| # | 检查项 | 脚本/Job | 验证内容 |
|---|--------|---------|---------|
| 1 | Self Check | `bash scripts/self-check.sh` | 107 项：知识库结构、manifest 一致性、command path、skills 数、stale ref、Go 编译、indexer 冒烟 |
| 2 | CI Check | `bash scripts/ci-check.sh` | extension.json 格式、版本号一致性、skill 目录、Go 编译、索引器端到端 |
| 3 | Build | Go 编译 x 3 平台 | ubuntu / macOS / Windows 交叉编译 |
| 4 | Test | Go 单元测试 |  CGO=0 和 CGO=1 两种模式 |
| 5 | Knowledge Check | frontmatter 完整性 | 所有 guard-rules 必含 `description` / `cwe` / `severity` |
| 6 | Example Check | 示例覆盖率 | 每个 CWE 在 examples/ 中至少有 1 条标记 |
| 7 | MarkdownLint | markdownlint-cli2 | Markdown 格式规范 |

### 绕过门禁

**不建议，但紧急时可两种方式：**

```bash
# 方式一：直接 push 到 develop（需要管理员权限 + 临时关闭保护）
# GitHub → Settings → Branches → develop → Unprotect

# 方式二：通过 API 合并（需要管理员权限 + token）
curl -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/DannyAn/SecGuardian/pulls/$PR_ID/merge" \
  -d '{"merge_method":"squash"}'
```

### 配置详情

配置文件：`.github/workflows/ci.yml`

触发条件：
- `push` 到 `develop` / `master`
- `pull_request` 目标为 `develop` / `master`

分支保护设置（通过 GitHub API 配置）：

```json
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "CI / Self Check",
      "CI / CI Check",
      "CI / Build ubuntu-latest",
      "CI / Build macos-latest",
      "CI / Build windows-latest",
      "CI / Test ubuntu-latest CGO=1",
      "CI / Knowledge Check",
      "CI / Example Check",
      "CI / MarkdownLint"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
```

### 本地预检（push 前推荐）

```bash
# 快速预检（~15s）
bash scripts/self-check.sh

# 结构验证（~10s）
bash scripts/ci-check.sh
```

> 这两个脚本合起来就是 PR 上 CI 跑的全部内容的本地版本。本地跑过再 push，基本不会在 CI 上翻车。

### CI 工作流文件位置

| 平台 | 配置文件 | 用途 |
|------|---------|------|
| GitHub Actions | `.github/workflows/ci.yml` | PR 门禁 + push 自动检查 |
| GitHub Actions | `.github/workflows/release.yml` | 版本发布（tag push 触发） |
| Gitee Go | `.gitee-ci.yml` | Gitee 镜像 CI（需手动开通） |

### 常见问题

**Q: PR 提交后 CI 没有触发？**
A: 检查 `.github/workflows/ci.yml` 的 `on.pull_request.branches` 是否包含目标分支名。目前配置了 `develop` 和 `main`。

**Q: CI job 显示 "pending" 状态？**
A: 首次 PR 时 GitHub 需要先完成一次完整运行才能识别 check name。等第一次跑完即可。

**Q: 合并按钮灰色显示 "Required checks must pass"？**
A: 说明有的 check 还没跑完或失败了。点进 PR 的 Checks tab 查看具体哪个失败。

**Q: 如何查看历史 CI 运行结果？**
A: 打开 https://github.com/DannyAn/SecGuardian/actions
