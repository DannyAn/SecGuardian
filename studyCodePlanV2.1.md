目标：

修正 V2 Refactor 中：
“内部 runtime abstraction 泄漏到用户接口层”
的问题。

核心原则：

External API Stability
Internal Runtime Evolution

--------------------------------------------------
RULE 1 — 用户 Skill Namespace 永久稳定
--------------------------------------------------

以下 namespace：

- memory.*
- resource.*
- security.*
- concurrency.*
- contract.*
- semantics.*

属于：

Public Stable Interface。

禁止：

- 重命名
- 合并
- 替换
- 暴露 internal engine taxonomy

CLI 必须保持：

/secguard ./src memory.*,resource.*

兼容。

--------------------------------------------------
RULE 2 — Internal Engine 不得暴露
--------------------------------------------------

internal engines：

- ownership_engine
- bounds_engine
- semantic_engine
- state_engine

仅允许存在于：

internal/runtime/

禁止：

- 出现在 CLI
- 出现在 findings
- 出现在 persistence
- 出现在 telemetry
- 出现在 public docs

--------------------------------------------------
RULE 3 — Skill 与 Engine 解耦
--------------------------------------------------

skill：

属于 UX abstraction。

engine：

属于 execution abstraction。

关系：

一个 engine
可执行多个 skills。

示例：

ownership_engine:
  - memory.use_after_free
  - memory.double_free
  - resource.double_release

但最终 findings：

必须保持原始 skill id。

--------------------------------------------------
RULE 4 — Findings Skill Identity 不变
--------------------------------------------------

Persistence:

必须继续输出：

memory.use_after_free
memory.double_free

禁止输出：

ownership.lifetime.invalid_release

禁止 internal taxonomy 泄漏。

--------------------------------------------------
RULE 5 — Scheduler 内部映射
--------------------------------------------------

新增：

internal/runtime/skill-engine-map.json

例如：

{
  "memory.use_after_free": "ownership_engine",
  "memory.double_free": "ownership_engine",
  "memory.buffer_overflow": "bounds_engine"
}

Dispatcher：

负责内部调度映射。

用户不可见。

--------------------------------------------------
RULE 6 — Public Documentation Stability
--------------------------------------------------

README:

必须继续以：

- memory
- resource
- security
- concurrency

组织。

禁止：

以 internal engine taxonomy 重写文档。

--------------------------------------------------
RULE 7 — Backward Compatibility
--------------------------------------------------

以下必须保持：

- CLI
- findings path
- persistence schema
- skill ids
- telemetry skill ids
- CI integration

禁止 breaking changes。

--------------------------------------------------
RULE 8 — Internal Runtime Freedom
--------------------------------------------------

允许：

internal runtime
自由重构：

- context reuse
- engine fusion
- graph reuse
- deterministic validators
- scheduler optimization

前提：

用户接口完全不变。