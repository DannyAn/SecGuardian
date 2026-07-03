# FEATURE-006: Finding Identity Redesign — Progress

## 状态

| 阶段 | 状态 |
|------|------|
| 🧠 Brainstorm | ✅ 已完成 |
| 📋 Spec | ✅ v0.1 Draft |
| 📝 ADR | ✅ 3 条 ADR |
| 📐 Plan | ✅ v0.1 |
| 🔨 Task | ✅ 全部 8 个 Task 已完成 |
| 📊 Progress | ✅ 完成追踪 |
| 🔄 Change | ⬜ N/A |

## 完成清单

- [x] Brainstorm 日志写入 (2026-06-28)
- [x] Spec 定义 (REQ-001 ~ REQ-010)
- [x] ADR-001: SHA-256 作为机器标识
- [x] ADR-002: 机器标识 vs 人类标识分离
- [x] ADR-003: 安全评分由 Renderer 独占计算
- [x] Plan 拆解 (8 个 Task)
- [x] **TASK-001**: 修复安全评分 bug — renderer 移除 `security_score` override + findings.json 模板移除
- [x] **TASK-002**: Renderer 适配新 Finding 格式 — manifest/report/SARIF 改用序号 + SHA
- [x] **TASK-003**: 更新 protocol docs — scan-output.md 更新文件命名和 finding 结构
- [x] **TASK-004**: 更新 command 定义 — secguard/secaudit/secreview 更新 ID 格式
- [x] **TASK-005**: 更新 skills — 5 个语言 SKILL.md 更新 finding 写入指令
- [x] **TASK-006**: 更新 validate 脚本 — validate-findings.py + verify-lang-pipeline.sh
- [x] **TASK-007**: 验证 — self-check 108/108, verify-lang-pipeline test data 更新
- [x] **TASK-008**: 部署 — dev-deploy.sh 完成（OpenCode/Claude/Gemini 三平台）

## 验证结果

使用现有扫描输出验证：

| 指标 | 旧值 | 新值 |
|------|------|------|
| manifest.json | `"id": "placeholder"` | `"seq": 1, "sha": "6d2eec..."` |
| summary.json | `security_score: 0` | `security_score: 7` |
| report.md 表格 | `placeholder` | `#1` ~ `#26` |
| 报告标题行 | `Finding ID | Severity` | `# | Severity` |
| SARIF findingId | `placeholder` | `6d2eec9a3cab` |
| SARIF seq | ❌ 无 | `seq: 1` |

## 下一步

- 在 OpenCode 中重新扫描 Java 项目: `/secguard ./src java`
- 观察 individual finding 文件命名: `f42ce940c35c_SignatureUtils-35.json`
- 分数从 0 变为 7，修一个 Critical 后变为 28
