# FEATURE-006: Finding Identity Redesign + 安全评分修复

> **隶属 Epic**: EPIC-001 Core Scanning Engine
> **版本**: v0.1 (Draft)
>
> **修改时间**: 2026-06-28
> **目标版本**: v0.6.0

---

## 1. Problem Statement

### 1.1 Finding ID 现状

当前 Finding ID 格式为 `<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>`（如 `C-SQL-I-QuestionMapper-L70`），
再复用为 individual finding 文件名。该设计存在三个系统性问题：

- **Bug**: AI Agent 写入 individual finding 文件时 `id` 字段填的是 `placeholder`，renderer 消费后全显 placeholder
- **认知负载**: 缩写规则（`SQL-I`、`HARDC`、`WEAK`）不直观，`H-WEAK--SysUserApplicationService-L127` 出现双连字符
- **行号不稳定**: 代码插入一行后 ID 即失效，但 ID 同时被用作跨扫描 identity

### 1.2 安全评分现状

评分公式为 `100 × exp(-0.2C - 0.1H - 0.04M - 0.01L)`（指数衰减），
但 AI Agent 在 `findings.json` 中写死 `security_score: 0`，
导致 renderer 的 `security_score` 被覆盖为 0，工程师无法看到修复后的进步。

---

## 2. Requirements

### REQ-001: Deterministic Finding Identity

每条 Finding 必须有一个确定的、不碰撞的机器标识，用于文件命名和跨扫描追踪。

- 输入: `{detector}:{file}:{line}:{cwe}`
- 算法: SHA-256
- 输出: 64 hex chars，文件名用前 12 位

### REQ-002: Human-Oriented File naming

文件名后缀必须提供工程师可快速定位的上下文。

- 格式: `${sha12}_${file_slug}-${line}.json`
- `file_slug` = `basename` 去掉扩展名，不做任何缩写
- 例: `f42ce940c35c_SignatureUtils-35.json`

### REQ-003: Display Identity = Sequential Number

所有人类可读输出（report.md、executive-summary.md、dashboard.html）使用序号 `#1` ~ `#N` 而非机器 ID。

- 排序规则: severity desc → file → line asc
- 排序稳定: 同一 scan 内顺序固定
- 跨扫描不保序（新扫描重新编号）

### REQ-004: No ID Column in Tables

报告表格移除 ID 列，列改为: `# | Severity | CWE | Detector | File:Line | Title`

### REQ-005: SARIF Alignment

- `partialFingerprints.primary` = SHA-256(detector:file:line:cwe)
- `properties.findingId` = SHA prefix (12 hex chars)
- `properties.seq` = sequential number

### REQ-006: findings.json findings_index 更新

`findings_index` 中每个 entry 移除 `id` 字段，改为:
```json
{
  "seq": 5,
  "sha": "f42ce940c35c",
  "severity": "High",
  "cwe": "CWE-798",
  "detector": "crypto.hardcoded-secrets",
  "file": "main/src/main/java/.../SignatureUtils.java",
  "line": 35,
  "title": "Hardcoded API signing secret"
}
```

### REQ-007: 安全评分公式

`score = max(0, round(100 × exp(-0.2×C - 0.1×H - 0.04×M - 0.01×L)))`

等级: A(≥80) B(≥55) C(≥35) D(≥15) F(<15)

### REQ-008: findings.json 不包含 security_score

AI Agent 不负责评分。`findings.json` 移除顶层 `security_score` 字段。

### REQ-009: Renderer 始终计算评分

Renderer 的 `generate_summary` 和 `generate_status` 始终通过 `calc_score(findings)` 计算评分，不读取 findings.json 中的 `security_score`。

### REQ-010: 目录树不变

`findings/<namespace>/<detector>/` 的目录层级结构保持不变，仅重命名 individual finding 文件。

---

## 3. Design

### 3.1 Finding 文件命名

```
findings/<namespace>/<detector-name>/<sha12>_<file_slug>-<line>.json

示例:
findings/crypto/hardcoded-secrets/f42ce940c35c_SignatureUtils-35.json
findings/crypto/password-storage/6d2eec9a3cab_PassHandler-37.json
findings/web/sql-injection/9d7c21fe4642_QuestionMapper-70.json
```

### 3.2 Finding 文件内部结构

```json
{
  "schema_version": "2.0",
  "finding": {
    "severity": "High",
    "cwe": "CWE-798",
    "detector": "crypto.hardcoded-secrets",
    "file": "main/src/main/java/.../SignatureUtils.java",
    "line": 35,
    "partialFingerprints": [
      {"algorithm": "SHA-256", "value": "f42ce940c35c..."}
    ],
    "location": { ... },
    "evidence": { ... },
    "impact": { ... },
    "fix": { ... }
  }
}
```

### 3.3 报告表格

```
| # | Severity | CWE | Detector | File:Line | Title |
|---|---|---|---|---|---|
| #1 | Critical | CWE-89 | web.sql-injection | QuestionMapper.xml:70 | MyBatis `${}` substitution |
| #2 | Critical | CWE-89 | web.sql-injection | QuestionMapper.xml:95 | MyBatis `${}` substitution |
| #3 | High | CWE-798 | crypto.hardcoded-secrets | SignatureUtils.java:35 | Hardcoded signing secret |
```

### 3.4 安全评分

```
8C + 6H + 12M → 7/100 F     （当前扫描）
修掉 7 个 C → 28/100 D        （可见进步）
全修完 C   → 34/100 D
干净项目   → 100/100 A
```

---

## 4. Risks & Constraints

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|---------|
| SHA 文件名碰撞（同 directory） | 极低 | 文件覆盖 | 12 hex = 48 bit，同 dir < 100 files，碰撞 < 2^-44 |
| 行号变化导致 SHA 变 | 必然但期望 | delta 对比丢失 | 这是预期行为——代码变了，旧 finding 不在新扫描中 |
| 已部署扫描的 backward compat | 临时 | manifest.json 格式变化 | v5.0 → v6.0 协议版本升级，renderer 兼容双格式 |
| AI Agent 不生成 SHA | 中 | 又出现 placeholder | 在 validate-findings.py 中强制检查 partialFingerprints |

---

## 5. Out of Scope

- 控制流图/数据流图（已有独立追踪）
- findings.json 格式大改（只改 id→seq+sha，其余不变）
- dashboard.html 样式修改（只改数据列，不改 UI）
- 历史扫描数据迁移（保留旧扫描不迁移）
