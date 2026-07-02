# Engine — 执行引擎规范

> Audit framework execution engine — 定义 AI Agent 如何加载知识和执行审计。

## 执行架构

```
skills/secaudit/SKILL.md
        │ 定义执行顺序
        ▼
knowledge/audit-rules/*.md
        │ 提供规则内容（唯一知识源）
        ▼
AI Agent 按工作流执行
        │
        ▼
Findings → Report
```

## 执行流程

### Step 1: 加载工作流

```
/secaudit ./src python
  -> 加载 skills/secaudit/SKILL.md
  -> 读取 17 阶段顺序执行的定义
```

工作流定义在 `skills/secaudit/SKILL.md` 中，包含：
- Phase 0: Setup — 技术栈识别（无规则文件）
- 各审计域检查（每个 phase 加载对应的 knowledge 规则文件）
- 后处理（去重、评分、分类、修复路线图）

### Step 2: 加载规则

每个 phase 从 `knowledge/audit-rules/` 加载对应的规则文件：

```
Phase 1  → knowledge/audit-rules/input-validation.md
Phase 2  → knowledge/audit-rules/auth-and-session.md
Phase 3  → knowledge/audit-rules/authorization.md
...
```

规则文件是唯一知识源。`docs/audit-framework/` 中不保存任何规则副本。

### Step 3: 处理 --focus

如果指定 `--focus <domain>`，跳过不匹配的 phase，仅加载对应域的规则文件。

### Step 4: 后处理

所有 phase 完成后：

1. 跨 phase 去重
2. CVSS 严重度排序
3. OWASP Top 10 / CWE Top 25 分类
4. 安全评分: 100 - (Critical×25 + High×10 + Medium×3 + Low×1)
5. 修复路线图: immediate / short-term / long-term

### Step 5: 生成报告

调用 Reporter 生成输出：
- `report.md`
- `results.sarif`
- `summary.json`
- `manifest.json`
- `status.json`
- `delta.json`

## 知识消费关系

| 组件 | 角色 | 路径 |
|------|------|------|
| 工作流 | HOW to run | `skills/secaudit/SKILL.md` |
| 规则 | WHAT to check | `knowledge/audit-rules/*.md` |
| 框架 | Framework design | `docs/audit-framework/` |

## 设计约束

| 约束 | 说明 |
|------|------|
| 框架不拥有规则 | `docs/audit-framework/` 中无规则文件 |
| 工作流不内嵌规则 | workflow 按名称引用规则，不包含规则内容 |
| 规则唯一源 | 所有规则仅 `knowledge/audit-rules/` 一份 |
| 消费单向 | 工作流 → 规则，不反向依赖 |
