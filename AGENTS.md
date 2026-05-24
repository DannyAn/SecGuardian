# SecGuardian - 安全守卫

本项目包含 SecGuardian 安全扫描功能，通过三个 slash command 命令触发：

## 命令

### /secaudit — AI 深度安全审计（旗舰产品）
执行 17 项专业安全审计分析。用法:
- `/secaudit` — 列出所有 skills
- `/secaudit taint-analysis ./src` — 污点分析
- `/secaudit cryptography ./src` — 密码学审计

可用的 audit skills (17 个):
- 分析类(5): attack-surface-analysis, data-flow-analysis, state-machine-analysis, taint-analysis, trust-boundary-analysis
- 领域类(12): auth-and-session, authorization, cryptography, input-validation, data-protection, secrets-management, secure-transport, http-security-headers, output-encoding, logging-and-monitoring, dependency-security, infra-hardening

### /secguard — 安全加固项排查
对源码执行安全漏洞扫描。支持命名空间过滤。用法:
- `/secguard ./src` — 全量扫描
- `/secguard ./src memory.*` — 仅内存检测器
- `/secguard ./src git diff HEAD~1` — 增量扫描

### /secreview — 安全编码规范审查
检视危险函数使用和反模式。用法:
- `/secreview ./src` — 自动检测语言
- `/secreview ./src python` — 指定语言

## 输出格式

所有命令遵循 Scan Output Protocol 1.1（见 knowledge/protocols/scan-output.md）：
`.codeagent/<extension>/scans/<scan-id>/manifest.json + findings/`。使用 `--sarif` 参数同时生成 SARIF 格式结果。

## 技能与知识

skills/ 目录下包含 25 个 SKILL.md，knowledge/ 目录下包含 10 个概念文件、4 个语言画像、30 个检测器、2 个输出协议。用户执行 /secguard 等命令时，需要先读取对应 skill 的 SKILL.md。
