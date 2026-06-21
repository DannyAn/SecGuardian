# CHANGE-001: v3.0 四段式 → v5.0 目录树架构

> **Feature**: FEATURE-001-output-protocol
> **日期**: 2026-06-07
> **类型**: 架构变更
> **原则**: Change 管理演进 — 记录需求为什么变、影响什么、怎么迁移

## Reason

v3.0 四段式上线 2 天后，扫描 `examples/python-vuln-demo`（3 文件 295 行）时发现：

- 单体 `findings.json` 约 50KB，耗时 ~9 分钟
- 1000 文件项目预估 25MB JSON——AI Agent 无法读取
- 企业级项目（10000+ 文件）完全不可行

**核心矛盾**: AI 输出能力（单次 Write ~100KB 可行）与后续消费能力（读取 25MB JSON 爆 token）严重不匹配。

用户同时提出设计哲学要求："级别低不代表不是问题，所有检出的问题都要用户认可去修正"，反对按 severity 拆分。

## Impact

| 维度 | v3.0 (变更前) | v5.0 (变更后) |
|------|-------------|-------------|
| 输出格式 | 单体 findings.json (50KB+) | 目录树 (每个 finding ~2KB) |
| AI 读取 | 必须读整个文件 | 按需读单个 finding |
| 分工方式 | 无 | 按 detector 目录分工 |
| findings.json | 单体（索引+数据） | 同名升级（纯索引，<50KB） |
| 渲染器 | `--findings` (单文件) | `--findings-dir` (目录树) + `--findings` 兼容 |

### 新增需求
- REQ-004: 按 detector 组织的目录树输出
- REQ-005: findings.json 同名升级为轻量索引
- REQ-006: 渲染器双模式兼容
- REQ-007: AI Agent 逐文件输出流程

### 保持不变
- REQ-001 (四段式), REQ-002 (SARIF 双轨), REQ-003 (质量门禁) 完全不变

## Migration

向后兼容：
- 渲染器 `--findings` 参数仍支持 v4.0 单体格式
- `--findings-dir` 为 v5.0 新模式，渐进升级
- 旧扫描结果（v4.0 findings.json）无需迁移

AI Agent 迁移路径：
1. commands/ 更新 Step 4 → 逐文件输出
2. 验证 `findings.json` 条目数 = `findings/` 目录文件数
3. 渲染器切换为 `--findings-dir` 模式
