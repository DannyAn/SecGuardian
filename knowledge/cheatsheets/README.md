# SecGuardian Knowledge — Cheatsheets

> 跨 skill 共享的安全速查表。遵循 OWASP Cheat Sheet Series 结构规范：单主题、可执行、可验证。

## 定位

Cheatsheets 与 Detectors 的分工：

| 维度 | Detectors (`knowledge/detectors/`) | Cheatsheets (`knowledge/cheatsheets/`) |
|------|-----------------------------------|----------------------------------------|
| 粒度 | 单威胁（如 `crypto-aes-ecb-mode`） | 跨威胁聚合（如所有加密算法状态对比） |
| 格式 | 检测步骤（Step 1 → Step N） | 速查表（决策矩阵、对照表） |
| 使用者 | AI Agent 执行检测时加载 | 人类参考 + AI Agent 做全景判断时加载 |
| 内容 | WHAT + HOW + FIX（自包含） | 横向对比 + 决策辅助 |
| 数量 | 60（每威胁一个） | 4（按安全领域聚合） |

## 目录

| 文件 | 覆盖领域 | OWASP 映射 |
|------|---------|-----------|
| [`crypto-algorithms.md`](crypto-algorithms.md) | 对称/非对称/哈希/KDF 算法安全性对比 | A02:2021 Cryptographic Failures |
| [`injection-patterns.md`](injection-patterns.md) | SQL/命令/XSS/路径穿越/模板注入 跨语言速查 | A03:2021 Injection |
| [`secrets-detection.md`](secrets-detection.md) | 密钥检测正则、存储安全矩阵、生命周期检查 | A07:2021 Identification Failures |
| [`tls-config.md`](tls-config.md) | TLS 版本/加密套件/证书/HSTS/内部通信安全 | A02:2021 + A05:2021 |

## 调用链

```
User: /secguard ./src cpp
  → commands/secguard.md (派发)
    → skills/secguard-cpp/SKILL.md (工作流)
      → knowledge/detectors/crypto-aes-ecb-mode.md (检测执行)
      → knowledge/cheatsheets/crypto-algorithms.md (全景参考) ← 按需加载
      → knowledge/languages/cpp.md (语言画像)

User: /secaudit cryptography
  → commands/secaudit.md (派发)
    → skills/secaudit-cryptography/SKILL.md (审计工作流)
      → knowledge/cheatsheets/crypto-algorithms.md (算法速查) ← 核心参考
      → knowledge/detectors/crypto-*.md (威胁定义参考)
```

## 设计原则

1. **单一主题** — 每个 cheatsheet 只覆盖一个安全领域，不跨领域混合
2. **可执行** — 提供的表格/模式可直接用于检测（正则、配置模板）
3. **可验证** — 内容可被 detectors 的检测逻辑交叉验证
4. **跨语言** — 所有表格覆盖 secguardian 支持的 5 种语言
