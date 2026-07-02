# Evidence Model — 证据收集与评估

> 定义安全审计中"证据"的含义、结构和质量标准。

## 什么是证据

Evidence 是 AI Agent 在审计过程中收集到的、支撑安全判断的具体信息。它是 findings（发现）的原材料。

```
源码 → 索引 → 分析 → Evidence → 判断 → Finding
```

## 证据类型

| 类型 | 来源 | 示例 |
|------|------|------|
| **语法证据** | index.json 符号表 | `malloc()` call at line 88, struct type `RequestCtx` |
| **调用证据** | index.json 调用图 | `handle_request()` calls `execute_query()` at line 120 |
| **数据流证据** | index.json + 源码追踪 | `user_input` → `sanitize()` → `execute()` |
| **模式证据** | knowledge rules + 源码 | SQL 拼接模式 `f"SELECT ... {var}"` 匹配 |
| **上下文证据** | 项目结构分析 | 框架版本、依赖版本、部署方式 |
| **关联证据** | 跨文件追踪 | 变量定义 in `a.h:42`，使用 in `b.c:88` |

## 证据结构

每个证据条目包含：

```json
{
  "source": "index.json·taint-analysis",
  "type": "data_flow",
  "confidence": 0.95,
  "context": {
    "file": "src/handler.py",
    "line": 47,
    "snippet": "cursor.execute(f\"SELECT * FROM users WHERE id = {user_id}\")"
  },
  "rationale": "用户输入直接拼接 SQL — 违反 OWASP Top 10 A03:2021"
}
```

| 字段 | 说明 |
|------|------|
| `source` | 证据来源（索引器/规则/上下文分析） |
| `type` | 证据类型 |
| `confidence` | 置信度 [0, 1.0] |
| `context` | 代码上下文 |
| `rationale` | 判断依据 |

## 证据质量标准

| 标准 | 最低要求 | 推荐 |
|------|---------|------|
| 置信度 | >= 0.70 进入 finding | >= 0.85 自动判定 |
| 上下文 | 至少包含文件名 + 行号 | 包含完整代码片段 |
| 数据流 | 至少 3 步（Source → Propagation → Sink） | 完整链路 |
| 引用 | 至少引用 1 条规则 | 引用规则 + CWE + OWASP |

## 证据 → Finding 的转换

```
Evidence（原始素材）
    │
    ├── 置信度 < 0.70 → 丢弃或降级为 note
    │
    ├── 置信度 0.70–0.85 → 进入四段式验证
    │   ├── 验证通过 → Finding
    │   └── 验证失败 → 丢弃（标记 false positive）
    │
    └── 置信度 >= 0.85 → 自动生成 Finding
```

## Quality Gate

质量门禁确保每个 finding 有充分的证据支持：

1. 每个 finding 必须包含至少 2 类证据
2. 每个 evidence 必须有 `rationale` 字段
3. 证据必须可追溯到源码位置（文件 + 行号）
4. 不满足 quality gate 的 finding 标记为 ⚠️ 不完整

## 与 Knowledge 的关系

证据收集依赖 `knowledge/` 中的规则定义：

- 规则定义"检查什么"（what to check）
- 证据收集回答"有什么发现"（what was found）
- 规则不包含证据，证据不包含规则
