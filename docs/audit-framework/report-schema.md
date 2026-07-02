# Report Schema — 报告模式与 CI 门禁

> 定义 SecAudit 的输出结构、文件和 CI 门禁规范。

## 输出文件结构

执行 `secaudit` 后，输出到 `.codeagent/secaudit-secguardian/scans/<scan-id>/`：

```
.codeagent/secaudit-secguardian/scans/<scan-id>/
├── index.json              ★ 语义索引输出
├── findings/               ★ 按 detector 分组的 finding 文件
│   ├── <sha-prefix-1>.json
│   ├── <sha-prefix-2>.json
│   └── ...
├── findings.json           ★ 轻量索引（无四段式，只有元数据+路径引用）
├── report.md               ★ 人读审计报告（Markdown）
├── results.sarif           ★ 机读: SARIF 2.1.0（CI/CD 集成）
├── summary.json            ★ 仪表盘统计
├── manifest.json           ★ 审计元数据 + 发现索引
├── status.json             ★ CI 门禁状态
└── delta.json              ★ 增量对比（vs 上次扫描）
```

> 详细协议定义见 `knowledge/protocols/scan-output.md`

## 报告格式

### report.md（人读）

完整的审计报告包含：

```
# secaudit 审计报告 — <scan-id>

## 1. 执行摘要
   - 扫描范围、语言、audit skills
   - 检出总数，按严重度分类
   - 安全评分

## 2. 严重度分布
   - Critical / High / Medium / Low 计数
   - 分布图（文本或 Ascii 图表）

## 3. 关键发现
   - 每个 finding 完整四段式：
     📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix

## 4. 修复路线图
   - Immediate（Critical/High）
   - Short-term（Medium）
   - Long-term（Low/Info）

## 5. 详细发现列表
   - 所有 findings 的分组列表
   - 按严重度降序排列
```

### results.sarif（机读）

遵循 SARIF 2.1.0 规范：

- 每个 finding 映射到 SARIF `result`
- 包含 `fingerprints` 用于去重
- 包含 `fixes`（对应 finding.fix 字段）

### summary.json（统计）

```json
{
  "total_findings": 42,
  "by_severity": {"critical": 5, "high": 12, "medium": 15, "low": 10},
  "security_score": 28,
  "command_type": "secaudit"
}
```

## CI 门禁

| 条件 | status.json | exit code |
|------|-------------|-----------|
| 无发现 | `PASSED` | 0 |
| 仅有 Low/Medium | `PASSED`（标注建议） | 0 |
| 存在 High | `PASSED`（标记警告） | 0 |
| 存在 Critical | `FAILED` | 1 |

### 安全评分公式

```
Score = 100 - (Critical×25 + High×10 + Medium×3 + Low×1)
```

| 分数区间 | 等级 |
|---------|------|
| 90–100 | A（优秀） |
| 70–89 | B（良好） |
| 50–69 | C（一般） |
| 30–49 | D（差） |
| 0–29 | F（不可接受） |

## 增量对比（Delta）

`delta.json` 对比本次与上次扫描：

```json
{
  "new_findings": 3,
  "fixed_findings": 5,
  "still_open": 34,
  "regressions": 1
}
```

依赖 `latest/` 符号链接指向最近一次扫描目录。

## 与 knowledge/protocols/ 的关系

`knowledge/protocols/scan-output.md` 定义协议的完整规范。
本文件仅定义 **docs/audit-framework 层面的输出约束**：
- 文件命名和目录结构
- CI 门禁规则
- 安全评分公式
- 输出质量要求
