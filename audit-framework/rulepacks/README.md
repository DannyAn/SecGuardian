# Rule Packs

Rule Pack 是 SecGuardian 审计框架的核心知识资产。每个 Rule Pack 对应一个安全标准或企业基线。

## 内置 Rule Pack

| Name | 标准来源 | 规则数 | 状态 |
|------|---------|--------|------|
| `secguardian` | SecGuardian 内置 17 个审计域 | 17 | ✅ 生产就绪 |

## 未来 Rule Pack

| Name | 标准来源 | 状态 |
|------|---------|------|
| `company-redline-v3` | 企业安全红线 | ⬜ 待开发 |
| `owasp-asvs` | OWASP Application Security Verification Standard | ⬜ 待开发 |
| `pci-dss` | PCI Data Security Standard | ⬜ 待开发 |
| `nist-ssdf` | NIST Secure Software Development Framework | ⬜ 待开发 |
| `cis` | CIS Benchmarks | ⬜ 待开发 |

## 目录规范

每个 Rule Pack 是一个独立的目录：

```
rulepacks/<name>/
├── pack.json       ← 清单 + 标准映射（必填）
└── rules/          ← 审计规则定义 Markdown 文件
    ├── <rule-1>.md
    ├── <rule-2>.md
    └── ...
```

## 安装第三方 Rule Pack

```bash
# 未来 CLI
secaudit rulepack install company-redline-v3
secaudit rulepack list
secaudit rulepack update --all
```
