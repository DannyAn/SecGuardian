---
category: protocol
version: "1.0"
---

# SecGuardian 验证协议 — 三轮误报消减

Detector 产出 Finding 后，三轮独立验证管道对每个 Finding 进行证据认证。每轮有 Detector 做不到的增量价值。

## 协议原则

1. **Detector 是检察官，验证管道是法庭** — Finding 必须经过独立验证才能呈现给用户
2. **每轮有不可替代的增量价值** — 不重复 Detector 已完成的分析
3. **证据门禁** — 每轮 Agent 的推理范围严格限制为指定数据
4. **Judge 禁止访问源码** — P3 裁决只基于 Court Record

## P2 强制执行（secguard 特定）

> ⚠️ **对于 secguard 命令，P2（Counter Evidence Hunt）是强制阻塞门。**
> counter_evidence.json 不存在或 P2 未通过 → **禁止**记录任何 finding。

1. P2 必须在记录任何 finding 之前完成。不得在以下情况下记录/提交 finding：
   - `workers/<rule_id>/<batch_id>/counter_evidence.json` 不存在
   - P2 对某个假设的裁决不是 `counter_evidence_not_found`
2. 每个通过 P1 的假设必须经过 P2 检查
3. P2 必须检查以下 C/C++ 反证：
   - **RAII 构造/析构函数对**：构造函数分配，配对的 destroy/release 函数管理释放
   - **智能指针**：`unique_ptr`、`shared_ptr`、`make_unique`、`make_shared` 管理所有权
   - **sizeof 边界检查**：复制前验证 `sizeof(dst)` 或 `len < sizeof(buf)`
   - **安全函数变体**：`strcpy_s`、`snprintf` (+返回值检查)、`strlcpy` 替代不安全函数
   - **编译器保护**：FORTIFY_SOURCE、`-fstack-protector`、ASan/UBSan
   - **free 后置 NULL**：`free(ptr); ptr = NULL;` 防止悬空指针
4. P2 裁决（`counter_evidence_found` 或 `counter_evidence_not_found`）必须与 finding 一起记录

**门控执行流程：**
```
Step 5 (Evidence) → Step 6 (P2 Counter Evidence) → 阻塞门检查:
  ├── counter_evidence.json 存在 + 每个假设有 P2 裁决 → 进入 Step 7 (Judge)
  └── counter_evidence.json 缺失或裁决不完整 → 终止，禁止记录 finding
```

---

## 管道概览

```
Detector → Finding[] (74 条, 保持现有格式)
                ↓
P1: Semantic Verification → 检查项目安全框架是否已天然消除风险
                ↓
P2: Counter-Evidence Hunt → 主动搜索证明漏洞不成立的证据
                ↓
P3: Adjudication Court   → 三方 Agent 合议最终裁决
                ↓
Certified Finding[] + Dismissed[]
```

---

## P1: Semantic Verification

### 职责

Detector 只分析单文件单函数——它不知道项目有个 `SafeCopy` 包装类已经保证了 bounds check。P1 构建项目的安全语义画像，找出 Detector 视野之外的保护层。

### 输入

- `index.json` (types + functions 列表)
- 每个 Finding 的 `location` + `evidence` 字段

### Prompt 模板

```
你是 Semantic Verifier Agent。

任务：判断以下 Finding 声称的风险是否已被项目自身的安全框架天然消除。

## 数据约束（证据门禁）
你只能使用以下数据：
1. 下方提供的 Project Security Profile（从 index.json types + functions 构建）
2. Finding 的 location 和 evidence 字段
禁止推测、禁止使用外部知识、禁止访问 Profile 未提及的代码。

## Project Security Profile
从 index.json 的 types 和 functions 自动扫描构建。识别以下模式：
- 安全包装类: Safe*, *Guard, *Wrapper, Validated*, Sanitized*
- 安全工厂方法: CreateSafe*, NewValidated*, MakeSecure*
- 校验/转义方法: Validate*, Sanitize*, Escape*, Encode*

对每个候选，说明其语义保证类型：
- bounds_check: 保证内存边界安全
- prepared_statement: 保证参数化查询
- input_validated: 保证输入校验
- ownership_managed: 保证生命周期管理 (RAII/smart pointer)
- encryption_wrapper: 保证使用标准加密

## Finding
{从 findings.json 中提取的单个 Finding 摘要: id, severity, cwe, detector, file, line, title, evidence.code_context, evidence.data_flow_path}

## 裁决
分析此 Finding 的 sink 调用/数据流是否被 Project Security Profile 中的某个组件保护。
- exempted: 安全框架已消除此风险
- no_exemption: 项目安全框架未覆盖此风险
- uncertain: 安全包装存在但不完全覆盖 → 保留但标记

## 输出格式
{
  "finding_id": "...",
  "r1_verdict": "exempted|no_exemption|uncertain",
  "r1_semantic_exemption": {
    "protector": "SafeCopy" | null,
    "guarantee": "bounds_checked" | null,
    "reason": "具体说明"
  }
}
```

### 裁决标准

| Verdict | 触发条件 |
|---------|---------|
| `exempted` | sink 调用是 Security Profile 中标记为安全的方法；或数据流经过了 Profile 中的 validator/sanitizer |
| `no_exemption` | Profile 中无相关保护；或相关保护不适用于此 sink |
| `uncertain` | 安全包装存在但仅部分覆盖（如 SafeCopy 在多处使用但此调用点未使用） |

---

## P2: Counter-Evidence Hunt

### 职责

Detector 是"找漏洞"的——它在找证据证明代码有问题。P2 反过来——主动搜索代码中证明漏洞不成立的证据。

### 输入

- `index.json` (lock_graph + alloc_free)
- P1 中 `no_exemption` 和 `uncertain` 的 Finding
- Finding 的 `data_flow_path` + 源码片段

### Prompt 模板

```
你是 Defense Agent。

任务：针对以下 Finding，主动搜索代码中证明漏洞不成立的证据。

## 数据约束（证据门禁）
你只能使用以下数据：
1. Finding 的 data_flow_path 和 location 指定的文件和行范围
2. index.json 中 lock_graph 和 alloc_free 的相关条目
3. 下方按 Finding 类型定制的搜索清单
禁止推测、禁止访问超出 Finding 指定范围的文件。

## Finding
{从 P1 筛选后的 Finding: id, severity, cwe, detector, file, line, data_flow_path, evidence.code_context}

## 搜索清单
按 Finding 的 cwe/detector 类型选择对应清单：

### 内存安全 (CWE-190/120/125/415/416/787/476)
搜索目标:
  - RAII 包装: 构造函数中分配、析构函数中释放
  - 智能指针: unique_ptr, shared_ptr, make_unique, make_shared
  - Bounds check: 在 sink 调用前是否有 if (len < sizeof(buf)) / if (index < MAX)
  - Size validation: 输入长度在上层函数已校验
  - Safe alternatives: strncpy, snprintf, strlcpy 替代不安全函数

### 注入 (CWE-89/77/79/94)
搜索目标:
  - Prepared Statement: 使用 ? 占位符的参数化查询
  - Escaping: html.EscapeString, mysql_real_escape_string, encodeURIComponent
  - Whitelist validation: 输入经过白名单/正则校验后才到 sink
  - ORM: 通过 GORM/Hibernate/SQLAlchemy ORM 访问数据库
  - Template engine: 使用 html/template (Go), Jinja2 autoescape (Python)

### 并发 (CWE-362/367/667)
搜索目标:
  - Mutex guard: lock_guard, scoped_lock, synchronized, with lock
  - Atomic: std::atomic, sync/atomic 操作
  - Happens-before: 明确的同步原语保证顺序 (channel, future, promise)

### 加密 (CWE-327/328/798/347)
搜索目标:
  - 高层加密库: libsodium, cryptography.fernet, nacl
  - KMS: AWS KMS, GCP KMS, Vault transit
  - 环境变量: 密钥是否从环境变量/Secret Manager 读取

## 裁决
- counter_evidence_found: 找到明确反证
- counter_evidence_not_found: 未找到反证

## 输出格式
{
  "finding_id": "...",
  "r2_verdict": "counter_evidence_found|counter_evidence_not_found",
  "r2_counter_evidence": {
    "mechanism": "RAII|smart_pointer|prepared_statement|mutex_guard|bounds_check|encryption_wrapper|...",
    "location": {"file": "...", "line": 0},
    "explanation": "具体说明为什么该机制消除了漏洞"
  } | null
}
```

### 裁决标准

| Verdict | 触发条件 |
|---------|---------|
| `counter_evidence_found` | 找到明确的安全机制（有具体代码位置+机制说明） |
| `counter_evidence_not_found` | 搜索清单中所有条目均未发现 |

---

## P3: Adjudication Court

### 职责

最终裁决。三方 Agent 合议——Detector 是检察官，P2 Defense Agent 是辩护律师，P3 Judge 是法官。

### 法庭结构

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ Prosecutor  │     │   Defender   │     │    Judge    │
│ 基于 Court   │     │ 基于 Court   │     │ 禁止访问源码 │
│ Record 论证  │     │ Record 论证  │     │ 只能基于     │
│ 漏洞成立     │     │ 漏洞不成立   │     │ Court Record │
└──────┬──────┘     └──────┬───────┘     └──────┬──────┘
       └───────────────────┴────────────────────┘
                      Court Record
           (Finding 摘要 + P1 + P2 verdict)
```

### Court Record 构建

对每个进入 P3 的 Finding，构建 Court Record：

```json
{
  "finding_id": "H-SQLI-webapp-L47",
  "finding_summary": {
    "severity": "High",
    "cwe": "CWE-89",
    "detector": "web.sql-injection",
    "file": "src/webapp.py",
    "line": 47,
    "function": "get_user",
    "title": "SQL injection via f-string query construction",
    "data_flow_path": ["request.args.get('username') → f-string → cursor.execute(query)"],
    "detector_confidence": "high",
    "detector_precision": "very-high"
  },
  "r1_semantic": {
    "verdict": "no_exemption",
    "reason": "Project has no ORM, no PreparedStatement wrapper, no query builder"
  },
  "r2_counter": {
    "verdict": "counter_evidence_not_found",
    "search_summary": "No parameterized query, no input escaping, no whitelist validation found"
  }
}
```

### Step 1: Prosecutor + Defender 并行发言

**Prosecutor Prompt:**

```
你是检察官。

基于以下 Court Record，论证为什么这个漏洞是真实存在的。

## 数据约束（证据门禁）
你只能使用 Court Record 中的信息。不得推测、不得引入 Court Record 未包含的证据。

## Court Record
{court_record_json}

## 任务
陈述漏洞成立的理由。引用 Court Record 中的具体条目。如果 Court Record 中所有证据都指向漏洞成立，你应当有力论证。如果 Court Record 中存在薄弱点（如 r1 或 r2 的 verdict 对你不利），你必须诚实面对，不得隐瞒。

## 输出格式
{
  "finding_id": "...",
  "prosecutor_statement": "论证内容（引用 Court Record 中的具体条目）",
  "key_evidence": ["Court Record 中支持漏洞成立的关键条目"]
}
```

**Defender Prompt:**

```
你是辩护律师。

基于以下 Court Record，论证为什么这个漏洞不成立或存疑。

## 数据约束（证据门禁）
你只能使用 Court Record 中的信息。不得推测、不得引入 Court Record 未包含的证据。

## Court Record
{court_record_json}

## 任务
陈述漏洞不成立或存疑的理由。即使 Court Record 整体指向漏洞成立，你也要诚实地找出其中的薄弱环节、缺失的证据、或不确定因素。如果你的论证力很弱（几乎所有证据都不利于你），你应该如实承认，而非强行辩护。

## 输出格式
{
  "finding_id": "...",
  "defender_statement": "论证内容（引用 Court Record 中的具体条目）",
  "weak_points": ["Court Record 中的薄弱环节"]
}
```

### Step 2: Judge 裁决

**Judge Prompt:**

```
你是法官。

基于以下材料做出最终裁决：
1. Court Record（P1 + P2 验证结论）
2. Prosecutor Statement（检察官论证）
3. Defender Statement（辩护律师论证）

## 数据约束（最高级别）
你禁止访问源代码。你禁止访问原始 Finding 的完整 JSON。你只能基于以下材料裁决。
任何超出这些材料的推理都是无效的。

## Court Record
{court_record_json}

## Prosecutor Statement
{prosecutor_statement}

## Defender Statement
{defender_statement}

## 裁决标准
- confirmed: Court Record 中 P1+P2 均未发现问题 + Prosecutor 论证有力 + Defender 无法提供有效反驳
  → Finding 确认为真阳性，保留
- suspected: Court Record 中存在薄弱环节（P1 uncertain 或 Defender 提出了合理的质疑）
  → 保留但标记为待人工确认
- dismissed: P1 exempted 或 P2 counter_evidence_found，或 Defender 提供了决定性反驳
  → Finding 抑制

## 输出格式
{
  "finding_id": "...",
  "r3_verdict": "confirmed|suspected|dismissed",
  "r3_severity": "critical|high|medium|low|info",
  "r3_confidence_certified": "high|medium|low",
  "r3_rationale": "裁决理由（引用 Court Record/Prosecutor/Defender 中的具体内容）"
}
```

### Judge 裁决的 confidence 映射

| 裁决路径 | confidence_certified |
|---------|---------------------|
| P1 no_exemption + P2 counter_evidence_not_found + Prosecutor 有力 + Defender 弱 | `high` |
| P1 no_exemption + P2 counter_evidence_not_found + Defender 提出合理质疑 | `medium` |
| P1 uncertain + 任何 P2 结果 | `low` |
| P1 exempted 或 P2 counter_evidence_found | 不输出 (dismissed) |

---

## 输出文件

验证管道执行完毕后输出：

### dismissed.json

```json
{
  "scan_id": "sc-20260605-173324-2434534",
  "dismissed": [
    {
      "finding_id": "H-BOF-parser_c-L36",
      "dismissed_at_round": "P1",
      "dismiss_reason": "Project SafeCopy wrapper guarantees bounds check at parser.c:30",
      "original_severity": "High",
      "original_detector": "memory.buffer-overflow"
    }
  ],
  "summary": {
    "total_findings": 74,
    "dismissed_by_p1": 22,
    "dismissed_by_p2": 17,
    "dismissed_by_p3": 10,
    "certified": 25
  }
}
```

### verification-audit.json

```json
{
  "scan_id": "sc-20260605-173324-2434534",
  "pipeline_version": "1.0",
  "rounds": {
    "p1_semantic": {
      "input_count": 74,
      "exempted": 18,
      "no_exemption": 52,
      "uncertain": 4
    },
    "p2_counter_evidence": {
      "input_count": 56,
      "counter_evidence_found": 17,
      "counter_evidence_not_found": 39
    },
    "p3_court": {
      "input_count": 39,
      "confirmed": 18,
      "suspected": 10,
      "dismissed": 11
    }
  },
  "certified_count": 28,
  "dismissed_count": 46,
  "verification_chain": [
    {
      "finding_id": "H-SQLI-webapp-L47",
      "r1_semantic": "no_exemption",
      "r2_counter": "counter_evidence_not_found",
      "r3_verdict": "confirmed",
      "r3_confidence": "high"
    }
  ]
}
```

---

## 执行约束

1. **P1 的 Security Profile 全局构建一次**，所有 Finding 复用。不按 Finding 数线性放大 token。
2. **P2 每 Finding 只读指定文件和同模块文件**（从 index.json `files` 中按目录前缀匹配）。
3. **P3 Court 零源码访问** — Prosecutor、Defender、Judge 都只看 Court Record。
4. **`--no-verify` flag** — 快速扫描模式跳过全部三轮验证。
