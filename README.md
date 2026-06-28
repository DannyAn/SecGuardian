# SecGuardian - 安全守卫

**AI 深度安全审计 + 代码漏洞发现 + 安全规范审查。年省 $50K+ 安全顾问费用。**

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)](https://github.com/secguardian/secguardian)
[![Version](https://img.shields.io/badge/version-0.9.1-blue)](https://github.com/secguardian/secguardian/blob/develop/CHANGELOG.md)
[![Go](https://img.shields.io/badge/Go-1.22%2B-00ADD8)](https://go.dev)
[![Detectors](https://img.shields.io/badge/detectors-67-brightgreen)](https://github.com/secguardian/secguardian/blob/develop/knowledge/language-index.md)
[![CWE Top 25](https://img.shields.io/badge/CWE_Top_25-100%25-brightgreen)](https://github.com/secguardian/secguardian/blob/develop/knowledge/language-index.md)

SecGuardian 是为 **Claude Code**、**OpenCode**、**Gemini CLI**、**GitHub Actions** 提供的企业级白盒安全 AI 解决方案。支持 **Windows / macOS / Linux** 全平台 CLI。

---

## ★ 旗舰产品：SecAudit — AI 深度安全审计

> **一口审计所有。** 一条命令 `/secaudit ./src java` 完成 17 项安全领域的全面审计。
> 从威胁建模到合规验证，从数据流分析到依赖扫描，一次运行产出完整审计报告。

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

### 一键部署

```bash
# 构建 + 三平台部署
bash scripts/dev-deploy.sh

# 或分平台部署
bash scripts/deploy.sh cc     # Claude Code
bash scripts/deploy.sh nga    # OpenCode
bash scripts/deploy.sh cac    # Gemini CLI
```

### 索引器（独立使用）

```bash
cd internal && go build -o secguardian-index .
./secguardian-index --version
./secguardian-index --health
./secguardian-index --path ./src --output index.json
```

---

## 运行环境

| 平台 | 安装 | CI/CD |
|------|------|-------|
| **Claude Code** | `npm install -g @anthropic-ai/claude-code` | — |
| **OpenCode** | [opencode.ai](https://opencode.ai) | — |
| **Gemini CLI** | Google Gemini CLI | — |
| **GitHub Actions** | `uses: secguardian/secguardian-action@v1` | ✓ SARIF → Code Scanning |

---

## 三个产品

| 产品 | 命令 | 定位 | Skills | 输出 |
|------|------|------|--------|------|
| **★ SecAudit** | `/secaudit` | AI 深度安全审计（旗舰） | 17 | report.md + results.sarif + summary.json |
| **SecGuard** | `/secguard` | AI 引导的代码漏洞发现 | 5 (5 语言) + 60 detectors | report.md + results.sarif + summary.json |
| **SecReview** | `/secreview` | 安全编码规范审查 | 5 (5 语言) | report.md + results.sarif + summary.json |

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
├── report.md            # Markdown 审计报告（人读）
├── results.sarif        # SARIF 2.1.0（机读，CI/CD 集成）
├── summary.json         # 轻量仪表盘统计
└── manifest.json        # 扫描摘要 + 检出索引
```

---

## 检测器覆盖

60 个检测器覆盖 6 个安全命名空间，支持 C/C++/Java/Python/Go/JavaScript 6 种语言：

| 命名空间 | 数量 | 覆盖主题 |
|---------|------|---------|
| memory | 13 | 内存安全（UAF、BOF、double-free 等） |
| concurrency | 4 | 并发安全（race、deadlock 等） |
| system | 7 | 系统安全（命令注入、路径遍历 等） |
| crypto | 9 | 加密安全（弱算法、硬编码密钥 等） |
| web | 21 | Web + 应用安全（XSS、SQLi、SSRF 等） |
| error | 6 | 错误处理安全（栈追踪泄露、日志敏感数据 等） |

> 详见 [检测器索引](knowledge/language-index.md)。CWE Top 25 100% 覆盖、OWASP Top 10 100% 覆盖。

---

## 验证

```bash
# 对示例代码运行检测
/secguard examples/cpp-vuln-demo/src cpp
/secguard examples/python-vuln-demo/src python
/secguard examples/java-vuln-demo/src java
/secguard examples/go-vuln-demo/src go
/secguard examples/js-vuln-demo/src javascript

# 深度审计示例
/secaudit taint-analysis examples/python-vuln-demo/src/
/secaudit cryptography examples/python-vuln-demo/src/crypto_utils.py
```

---

## License

Dual-licensed. Code: Apache 2.0, Knowledge: CC BY-NC 4.0. See [LICENSE](LICENSE) for details.
