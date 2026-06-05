# SecGuardian - 安全守卫

**AI 深度安全审计 + 代码漏洞发现 + 安全规范审查。年省 $50K+ 安全顾问费用。**

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)](https://github.com/secguardian/secguardian)
[![Version](https://img.shields.io/badge/version-0.3.0-blue)](https://github.com/secguardian/secguardian/blob/develop/CHANGELOG.md)
[![Go](https://img.shields.io/badge/Go-1.22%2B-00ADD8)](https://go.dev)
[![Detectors](https://img.shields.io/badge/detectors-45-brightgreen)](https://github.com/secguardian/secguardian/blob/develop/skills/secguard-cpp/references/detector-index.md)
[![CWE Top 25](https://img.shields.io/badge/CWE_Top_25-100%25-brightgreen)](https://github.com/secguardian/secguardian/blob/develop/skills/secguard-cpp/references/detector-index.md)

SecGuardian 是为 **Claude Code**、**OpenCode**、**Gemini CLI**、**GitHub Actions** 提供的企业级白盒安全 AI 解决方案。支持 **Windows / macOS / Linux** 全平台 CLI。

---

## ★ 旗舰产品：SecAudit — AI 深度安全审计

传统安全审计需要资深工程师逐项审查，单次审计费用 $10K-$50K。SecAudit 使用 AI 在数秒内完成同等深度的 17 项专业安全分析：

- **5 项分析方法**：污点分析、数据流分析、攻击面分析、状态机分析、信任边界分析
- **12 个安全领域**：认证/授权/加密/输入验证/密钥管理/安全传输/数据保护/依赖安全/基础设施加固 等

```bash
/secaudit taint-analysis              # 污点分析 — Source→Sink 追踪
/secaudit cryptography                # 密码学完整审计
/secaudit auth-and-session            # 认证机制审计
/secaudit attack-surface-analysis     # 攻击面枚举
```

> **与传统 SAST 的本质区别**：传统工具做模式匹配，SecAudit 做深度推理。它理解代码的上下文、业务逻辑和数据流，能发现传统工具遗漏的隐蔽漏洞。

---

## 安装

### 全平台 CLI（推荐）

SecGuardian 提供独立的 Go 二进制文件，无需依赖任何 AI CLI 平台即可运行：

**macOS / Linux:**
```bash
cd internal && go build -o secguardian .
./secguardian help
```

**Windows (PowerShell):**
```powershell
cd internal; go build -o secguardian.exe .
.\secguardian.exe help
```

或使用构建脚本：

```bash
# macOS/Linux
bash scripts/build.sh cc

# Windows
powershell -File scripts/build.ps1
```

### 运行

```bash
# 列出 45 个检测器
secguardian detectors

# 按分类筛选
secguardian scan --path ./src --filters memory.*
secguardian scan --path ./src --filters "memory.*,web.sql-injection"

# 查看审计技能
secguardian audit --skill list
secguardian audit --skill cryptography --path ./src

# 代码审查
secguardian review --path ./src --lang python
```

## 运行环境

### 宿主平台

| 平台 | 安装 | CI/CD |
|------|------|-------|
| **Claude Code** | `npm install -g @anthropic-ai/claude-code` | — |
| **OpenCode** | [opencode.ai](https://opencode.ai) | — |
| **Gemini CLI** | Google Gemini CLI | — |
| **GitHub Actions** | `uses: secguardian/secguardian-action@v1` | ✓ SARIF → Code Scanning |

### 构建/部署依赖

| 软件 | 最低版本 | 用途 |
|------|---------|------|
| **Git** | 2.30+ | 增量扫描 |
| **Bash** | 4.0+ | 构建脚本 |
| **jq** | 1.6+ | JSON 处理 |

> SecGuardian 是 **AI-native** 工具 — 不依赖编译器或 SAST 引擎。

---

## 一键部署

```bash
# 构建 + 三平台部署
bash scripts/dev-deploy.sh

# 或分平台部署
bash scripts/deploy.sh cc     # Claude Code
bash scripts/deploy.sh nga    # OpenCode
bash scripts/deploy.sh cac    # Gemini CLI
```

---

## 三个产品

| 产品 | 命令 | 定位 | Skills | 输出 |
|------|------|------|--------|------|
| **★ SecAudit** | `/secaudit` | AI 深度安全审计（旗舰） | 17 | SARIF + manifest.json |
| **SecGuard** | `/secguard` | AI 引导的代码漏洞发现 | 4 (4 语言) + 26 detectors | SARIF + manifest.json |
| **SecReview** | `/secreview` | 安全编码规范审查 | 4 (4 语言) | SARIF + manifest.json |

---

## CI/CD 集成

```yaml
# .github/workflows/security.yml
- uses: secguardian/secguardian-action@v1
  with:
    mode: secaudit
    skill: taint-analysis
    path: src/

# SARIF 结果自动上传到 GitHub Security → Code Scanning
```

也支持 GitLab SAST (`artifacts:reports:sast`) 和 Azure DevOps。

---

## 扫描输出

```
.codeagent/<extension>/scans/<scan-id>/
├── manifest.json        # 扫描摘要 + 检出索引
├── results.sarif        # SARIF 2.1.0 (CI/CD 集成)
└── findings/            # 每个检出一个 JSON 详情
```

---

## 验证

```bash
# C/C++ 示例（8 漏洞）
/secguard examples/cpp-vuln-demo/src cpp

# Python 示例（9 漏洞）
/secguard examples/python-vuln-demo/src python

# Java 示例（8 漏洞）
/secguard examples/java-vuln-demo/src java

# Go 示例（11 漏洞）
/secguard examples/go-vuln-demo/src go

# 深度审计示例
/secaudit taint-analysis examples/python-vuln-demo/src/
/secaudit cryptography examples/python-vuln-demo/src/crypto_utils.py
```

---

## 许可

Proprietary. All rights reserved.
