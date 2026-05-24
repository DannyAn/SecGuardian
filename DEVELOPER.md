# DEVELOPER.md -- SecGuardian 开发指南

## 目录

- [快速开始](#快速开始)
- [项目架构](#项目架构)
- [日常开发](#日常开发)
- [规则微调](#规则微调)
- [构建与部署](#构建与部署)
- [发布流程](#发布流程)
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
bash scripts/dev-deploy.sh

# 3. 重启 AI CLI（Claude Code / OpenCode / Gemini CLI）

# 4. 验证：执行扫描命令
#    Claude Code / OpenCode 中运行：
#      /secguard examples/python-vuln-demo/src/ critical
#      /secaudit taint-analysis examples/python-vuln-demo/src/
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
skills/            ← 执行层：25 个 skill，每个定义扫描/审查/审计的提示词
knowledge/         ← 知识层：安全概念、语言画像、检测规则、输出协议
extensions/        ← 打包层：3 个 extension 的 extension.json 清单
scripts/           ← 工具层：构建、部署、打包脚本
examples/          ← 验证层：各语言漏洞示例代码
```

### 三个 Extension 的关系

| Extension | Command | 定位 | Skill 数量 | 覆盖语言 |
|-----------|---------|------|-----------|---------|
| secguard-secguardian | `/secguard` | 安全加固检查：API 级别的漏洞检测 | 4 | C++, Java, Python, Go |
| secaudit-secguardian | `/secaudit` | 安全专项审计：纵深领域深入分析 | 17 | 语言无关 |
| secreview-secguardian | `/secreview` | 安全规范审查：编码规范与反模式 | 4 | C++, Java, Python, Go |

- `/secguard` 关注 "这行 API 调用有没有漏洞"（精确）
- `/secreview` 关注 "这段代码的设计模式是否安全"（语义）
- `/secaudit` 关注 "这个安全领域有没有全面覆盖"（纵深）

### 知识库结构

```
knowledge/
├── protocols/scan-output.md    ← 输出协议 1.0：manifest + finding JSON schema
├── concepts/                   ← 安全概念（10 个）：漏洞原理、检测策略、修复指南
├── languages/                  ← 语言画像（4 个）：危险 API 列表、框架安全说明
└── detectors/                  ← 检测规则（6 active + 20 planned）：详细检测逻辑
```

#### Detector 状态

- **active (6)**: 实际参与扫描，在 `secguard-*` skill 中被加载
- **planned (20)**: 规则已定义但尚未激活，需要完善后启用

Active detectors（全部针对 C/C++ 内存安全）：

| Detector | CWE | 严重度 |
|----------|-----|--------|
| null-dereference | CWE-476 | High |
| double-free | CWE-415 | Critical |
| use-after-free | CWE-416 | Critical |
| buffer-overflow | CWE-120 | Critical |
| format-string | CWE-134 | High |
| integer-overflow | CWE-190 | High |

### 输出协议

所有扫描结果遵循 Scan Output Protocol 1.0，输出到：

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
2. bash scripts/dev-deploy.sh    ← 一键构建 + 部署
3. 重启 AI CLI
4. 运行 /secaudit 或 /secguard 对 examples/ 执行扫描
5. 检查 .codeagent/ 下的输出结果
6. 根据结果调整源码
```

### 使用 build.sh 的精细控制

```bash
# 仅构建，不部署
bash scripts/package.sh

# 构建 + 仅部署到 Claude Code
bash scripts/build.sh cc

# 构建 + 仅部署到 OpenCode
bash scripts/build.sh nga

# 构建 + 仅部署到 Gemini CLI
bash scripts/build.sh cac

# 构建 + 全平台部署 + 创建 zip 发布包
bash scripts/build.sh all --zip

# 创建发布包（不部署）
bash scripts/build.sh --zip
```

### 文件修改影响范围

| 修改位置 | 影响范围 | 需要重新部署 |
|----------|---------|------------|
| `knowledge/concepts/*.md` | 所有 3 个 extension | `dev-deploy.sh` |
| `knowledge/languages/*.md` | 所有 3 个 extension | `dev-deploy.sh` |
| `knowledge/detectors/*.md` | 仅 secguard | `dev-deploy.sh` |
| `knowledge/protocols/*.md` | 所有 3 个 extension | `dev-deploy.sh` |
| `skills/<cmd>-*/SKILL.md` | 仅对应 extension | `dev-deploy.sh` |
| `skills/<cmd>-*/references/*.md` | 仅对应 extension | `dev-deploy.sh` |
| `commands/<cmd>.md` | 仅对应 extension | `dev-deploy.sh` |
| `extensions/*/extension.json` | 仅对应 extension | `dev-deploy.sh` |
| `commands/gemini/*.toml` | 仅 Gemini CLI | `dev-deploy.sh` |

### 部署后的目录结构

```
secguardian/                      ← 项目根目录
├── .claude/extensions/           ← Claude Code 部署目标
│   ├── secguard-secguardian/
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

编辑 `knowledge/concepts/<concept>.md`，调整 Detection Strategy 部分：

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

编辑 `knowledge/detectors/<detector>.md`。每个 detector 定义了精确的多步检测流程：

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

1. 编写 `knowledge/detectors/<new-detector>.md`（参考已有 detector 格式）
2. 在 `manifest.json` 的 `knowledge.detectors` 中添加条目
3. 在对应 `extensions/secguard-secguardian/extension.json` 的 `knowledge.detectors` 中添加
4. 重新部署：`bash scripts/dev-deploy.sh`
5. 用 examples/ 验证检测效果

### 添加新安全概念

1. 编写 `knowledge/concepts/<new-concept>.md`（参考已有概念格式）
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
scripts/deploy-{claude,opencode,gemini}.sh  → 平台部署
```

### 单独部署到某个平台

```bash
# Claude Code
bash scripts/deploy-claude.sh

# OpenCode
bash scripts/deploy-opencode.sh

# Gemini CLI
bash scripts/deploy-gemini.sh
```

### 构建系统依赖

`package.sh` 使用 `jq` 处理 extension.json 中的数据：
- 读取 command name、skill 列表、knowledge 依赖
- 生成 `.claude-plugin/plugin.json`

如果系统未安装 `jq`：`brew install jq` (macOS) 或 `apt-get install jq` (Linux)。

---

## 发布流程

### 创建发布包

```bash
# 构建 + 全平台部署 + 生成 zip
bash scripts/build.sh all --zip

# 产物在 dist/archives/
ls dist/archives/
# secguard-secguardian-0.1.0.zip
# secaudit-secguardian-0.1.0.zip
# secreview-secguardian-0.1.0.zip
```

### 版本更新

需要同步修改以下位置的版本号：

| 文件 | 字段 |
|------|------|
| `manifest.json` | 顶级 `version` |
| `extensions/secguard-secguardian/extension.json` | `version` |
| `extensions/secaudit-secguardian/extension.json` | `version` |
| `extensions/secreview-secguardian/extension.json` | `version` |

### 发布检查清单

- [ ] 所有 3 个 extension.json 版本号一致
- [ ] manifest.json 版本号一致
- [ ] 用 examples/ 验证 3 个命令均能正常输出
- [ ] 检查 `.codeagent/` 下的输出符合 Scan Output Protocol 1.0
- [ ] 运行 `bash scripts/build.sh all --zip` 确认无报错
- [ ] 检查 `dist/archives/*.zip` 内容完整
- [ ] 更新 README.md 中的版本号（如有引用）

### 发布到内部仓库

```bash
# 构建并打包
bash scripts/build.sh all --zip

# dist/archives/ 下的 zip 即为可分发产物
# 将其上传到内部发布平台或 Git Releases
```

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

预期结果：检查 `.codeagent/secguard-secguardian/scans/<scan-id>/manifest.json`，应检出对应语言中注释标注的漏洞。

### 验证 secaudit 命令

```bash
# 污点分析
/secaudit taint-analysis examples/python-vuln-demo/src/webapp.py

# 加密审计
/secaudit cryptography examples/python-vuln-demo/src/crypto_utils.py

# 认证审计
/secaudit auth-and-session examples/java-vuln-demo/src/AuthController.java

# 攻击面分析
/secaudit attack-surface-analysis examples/python-vuln-demo/src/
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
2. 编写 knowledge/concepts/ 中 Rust 特有安全概念（如需要）
3. 编写 skills/secguard-rust/SKILL.md（扫描提示词）
4. 编写 skills/secreview-rust/SKILL.md（审查提示词，可选）
5. 在 extensions/secguard-secguardian/extension.json 中注册
6. 在 extensions/secreview-secguardian/extension.json 中注册（可选）
7. 更新 manifest.json
8. 创建 examples/rust-vuln-demo/ 测试用例
9. bash scripts/dev-deploy.sh
10. 验证：/secguard examples/rust-vuln-demo/src/
```

### 添加新的 secaudit 审计领域

```
1. 编写 skills/secaudit-<name>/SKILL.md（参考 cryptography 等格式）
2. 在 extensions/secaudit-secguardian/extension.json 的 skills 数组中添加
3. 更新 manifest.json 的 secaudit skill 列表
4. bash scripts/dev-deploy.sh
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
bash scripts/dev-deploy.sh
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
    "secguard-secguardian": {
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
4. 满意后 `bash scripts/dev-deploy.sh` 正式部署

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
3. 检查对应的 knowledge/concepts 文件的检测策略是否覆盖该模式
4. 尝试降低扫描范围（仅扫描单文件而非整个目录）
5. 调整对应 skill 的 SKILL.md，增加更明确的检测指令

### 误报过多

1. 在对应 `knowledge/concepts/<concept>.md` 中加强 `False Positive Exclusion` 规则
2. 在对应 detector 的 knowledge 文件中添加 FP 排除条件
3. 在对应 skill 中增加验证步骤（如要求 AI 确认上下文后才报告）

### 构建失败

```bash
# 检查 jq 是否安装
which jq && jq --version

# 检查 extension.json 格式是否正确
jq . extensions/secguard-secguardian/extension.json > /dev/null && echo "OK"

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
ext="secguard-secguardian"
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
- 检测器索引: `skills/secguard-cpp/references/detector-index.md`
- 各语言速查表: `skills/<cmd>-<lang>/references/<lang>-security-cheatsheet.md`
- 各语言反模式: `skills/secreview-<lang>/references/<lang>-anti-patterns.md`
- OWASP ASVS 认证参考: `skills/secaudit-auth-and-session/references/owasp-asvs-auth.md`
