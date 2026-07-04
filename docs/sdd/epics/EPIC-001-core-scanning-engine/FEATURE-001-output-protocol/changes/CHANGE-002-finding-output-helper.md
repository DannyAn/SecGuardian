# CHANGE-002: AI 逐文件输出 → record-finding.py 辅助工具

> **Feature**: FEATURE-001-output-protocol
> **日期**: 2026-07-04
> **类型**: 工具补充
> **原则**: AI 擅长语义分析，不擅长模板和格式校验 — ADR 已有记录

## Reason

AI Agent 执行 `/secguard` 时，Step 4 要求对每个检测器读取 `.md` 文件、逐文件写出 finding JSON。
实际执行中 AI 绕过此流程，创建 `/tmp/gen_findings.py` 脚本批量生成 findings：

```python
# AI 写的 /tmp/gen_findings.py（490 行）
def write_finding(detector, severity, cwe, file, line, ...):
    # 硬编码了 25 个 finding，无源码分析
    ...
```

**根因**：逐文件写出 25+ 个 finding 对 AI 来说极耗 token（每个文件要生成 JSON、
计算 SHA、创建目录、确保格式正确），AI 自然选择"写一个脚本批量生成"这条捷径。

**设计鸿沟**：FEATURE-001 的 ADR 明确了 "AI 做分析、Python 做格式" 的分工，
但缺少一个在 AI 分析与 Renderer 处理之间的桥梁工具——AI 没有简易途径
将分析结果转成 findings/ 目录树。

## Impact

| 维度 | 变更前 | 变更后 |
|------|--------|--------|
| AI 行为 | 创建 /tmp 脚本 → 质量不可控 | 调用 `record-finding.py` → 结构受控 |
| 输出格式 | 可能不符合 schema | 工具保证 schema 合规 |
| findings.json | 需 AI 自行生成 | 由 `build-findings-index.py` 自动聚合 |
| Token 消耗 | 每文件 2-4KB JSON + 手动 I/O | 仅传参数，I/O 由 Python 处理 |

### 新增/修改组件

- `scripts/record-finding.py`（新增）— AI 调用，记录单个 finding
- `scripts/build-findings-index.py`（可复用 renderer）— 聚合 findings/ 生成 findings.json

### 保持不变

- `scripts/render-report.py` — 读取 findings/ 生成最终报告（不变）
- `scripts/validate-findings.py` — 校验 finding schema（不变）
- Step 4 输出流程 — AI 仍需逐个分析检测器、调用工具记录

## Solution

### 方案 A（选定）：record-finding.py 工具

```bash
# AI 分析每个检测器后调用
python3 scripts/record-finding.py \
    --scan-dir .codeagent/secguardian/secguard/scans/<scan-id> \
    --detector web.sql-injection \
    --severity Critical --cwe CWE-89 \
    --file src/UserController.java --line 52 \
    --fix-before "<bad_code>" --fix-after "<good_code>"
```

输出：`findings/<ns>/<detector>/<sha12>_<file>-<line>.json`

### 方案 B（否决）：扩展 Renderer 接受 JSON 数组

Renderer 增加 `--findings-json` 接受批量 findings。否决理由：
- Renderer 职责是 "读取 → 渲染"，不应参与 finding 创建
- AI 传递大量 finding 数据仍爆 token
- 违反单一职责

## Migration

1. 创建 `scripts/record-finding.py`（参数化，轻量，无外部依赖）
2. 更新 Step 4a 指令：从 "Write 工具逐个输出" 改为 "调用 record-finding.py"
3. 更新 `scripts/validate-findings.py` 的 e2e 测试（新增 record-finding 路径）
4. 更新 `scripts/render-report.py`（如 findings.json 路径有变）

已在 `branch feature/change-002-record-finding` 实现并验证。
