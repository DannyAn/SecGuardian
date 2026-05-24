# SecGuardian 工作清单 — 每次开展工作的依据

> 最后一次更新: 2026-05-24 | 当前阶段: Phase 2（质量验证 + 案例积累）

---

## 总体目标

**在 Month 1 获得第一个付费客户 ($2K Pro 订阅)，Month 6 达到 $100K ARR。**

---

## 当前阶段：Phase 2 — 质量验证与案例积累

### 目标
有数据支撑的准确率声明 + 至少 5 个真实审计案例作为销售材料。

### 前置状态
- [x] Phase 0: 26 个 detector 知识文件全部创建
- [x] Phase 0: 构建脚本重构（统一 deploy.sh）
- [x] Phase 0: SARIF 输出协议 + GitHub Action
- [x] Phase 1: 独立 CLI 入口 (`scripts/secguardian.sh`)
- [x] Phase 1: 审计报告模板 (`knowledge/report-template.md`)
- [x] Phase 1: 质量基准框架 (`scripts/benchmark.sh`)
- [x] Phase 1: 案例模板 (`docs/case-study-template.md`)
- [x] Phase 1: 竞品分析 (`docs/competitive-analysis.md`)
- [x] Phase 1: 商业化路线图 (`docs/roadmap-to-commercial.md`)

---

## 工作清单（按优先级排序）

### P0 — 本次必须完成

#### 1. 对 examples/ 运行完整 AI 审计，收集真实 TP/FP 数据

**为什么重要**: 没有准确率数据，客户不会付费。这是销售的第一块基石。

**步骤**:
1. 对每个 language 的 examples/ 运行 secguard scan：
   ```
   bash scripts/secguardian.sh scan --path examples/cpp-vuln-demo/src
   bash scripts/secguardian.sh scan --path examples/go-vuln-demo/src
   bash scripts/secguardian.sh scan --path examples/java-vuln-demo/src
   bash scripts/secguardian.sh scan --path examples/python-vuln-demo/src
   ```
2. 加载生成的 `.system_prompt.md` 到 AI 对话中执行审计
3. 对照源码 `VULNERABILITY [CWE-xxx]` 标注，统计每个 finding 的 TP/FP
4. 更新 `benchmark.sh` 中的 TP/FP/FN 数据
5. 输出准确率报告到 `docs/accuracy-report.md`

**验证标准**: 至少完成 2 个语言的审计，得到 Precision/Recall 数据。

---

#### 2. 对 5 个真实开源项目运行 secaudit 审计

**为什么重要**: examples/ 是构造的。客户要看真实项目上的发现。

**候选项目**（选 5 个，覆盖不同语言和规模）:

| 优先级 | 项目 | 语言 | 规模 | 为什么选它 |
|--------|------|------|------|----------|
| ★★ | Flask (某核心模块) | Python | 中 | Web 框架，污点分析极佳案例 |
| ★★ | Gin (某 core 模块) | Go | 中 | Go Web 框架，SSRF/注入案例 |
| ★ | FastAPI 依赖注入模块 | Python | 小 | 输入验证 + 认证绕过 |
| ★ | Rails 某 controller | Ruby | 小 | 展示跨语言能力（虽然不在官方 support 列表） |
| ★★ | OWASP WebGoat (某 lesson) | Java | 小 | 已知漏洞，验证检出率 |
| ★ | Redis 某命令处理模块 | C | 中 | C 内存安全检测展示 |
| ★★ | Django REST Framework auth | Python | 中 | 认证/授权审计展示 |

**步骤**:
1. Clone 目标仓库到本地
2. 选择审计 skill（优先: taint-analysis, auth-and-session, cryptography）
3. 运行 `bash scripts/secguardian.sh audit --skill <name> --path <repo_path>`
4. 加载 prompt 到 AI 执行审计
5. 将结果填充到 `docs/case-study-template.md` 模板
6. 每个案例标注：发现了什么 / 发现是否有价值 / 如果是客户会不会付费

**验证标准**: 至少 2 个案例完成审计报告草稿。

---

#### 3. 补齐 CWE Top 25 中缺失的高优先级检测覆盖

**为什么重要**: 竞品分析显示 CWE Top 25 覆盖率仅 44%，缺乏 Web 安全检测是最致命的商业弱点。

**具体任务**:

| CWE | 漏洞 | 当前状态 | 目标 |
|-----|------|---------|------|
| CWE-89 | SQL 注入 | concept 有，无 detector | 创建 per-language 检测引导 |
| CWE-79 | XSS | concept 有，无 detector | 创建 per-language 检测引导 |
| CWE-502 | 反序列化 | concept 有，无 detector | 创建 Java/Python detector |
| CWE-918 | SSRF | concept 有，无 detector | 创建 per-language 检测引导 |
| CWE-352 | CSRF | 无 | 添加 concept + 检测引导 |
| CWE-287 | 认证缺陷 | 无专项 detector | 已由 secaudit auth-and-session 覆盖 |

**注意**: 这些不是创建 formal detector（那是 AI 做不好的精确匹配），而是为 secguard 的 Java/Python/Go skill 添加 AI 引导的检测上下文。因为 AI 擅长的是理解"这个 HTTP handler 拼接了 SQL 字符串"而不是匹配正则。

**步骤**:
1. 更新 `knowledge/concepts/sql-injection.md`，添加跨语言检测策略
2. 更新 `skills/secguard-python/SKILL.md`，加强 Web 安全检测指令
3. 更新 `skills/secguard-java/SKILL.md`，同上
4. 更新 `skills/secguard-go/SKILL.md`，同上

**验证标准**: 每个 `secguard-<lang>` skill 至少有 5 个明确的 Web 安全检测场景。

---

### P1 — 本阶段内完成

#### 4. Onboarding 体验 — 5 分钟从安装到第一个结果

**步骤**:
1. 编写 `docs/quick-start.md` — 新用户 5 步上手指南
2. 创建 `examples/demo-project/` — 一个包含 3 个有意漏洞的小型示例项目
3. 确保 `bash scripts/secguardian.sh audit --skill taint-analysis examples/demo-project` 可以在 30 秒内完成上下文组装

---

#### 5. 编写 Sales Deck 关键页面

**步骤**:
1. 更新 `README.md` 的 "为什么选择 SecGuardian" 部分
2. 编写一个 3 段话的 Elevator Pitch（面向 CTO/CISO）
3. 编写 Pricing 文案（基于 roadmap 中的定价模型）

---

#### 6. 建立 CI/CD 验证流程

**步骤**:
1. 创建 `.github/workflows/ci-security.yml` — 在 PR 上自动运行 secguardian
2. 测试 `action.yml` 是否能正常触发
3. 验证 SARIF 输出的 GitHub Code Scanning 集成

---

### P2 — 可以延后

#### 7. 多 skill 串联审计

一次运行执行 3+ skill（如 taint-analysis + auth + crypto），生成综合审计报告。

#### 8. Web Dashboard

简单的 Web UI 查看审计历史和趋势。

---

## 每次工作流程

### 开始工作时

1. 打开此文档，确认当前 Phase
2. 从清单中选取一个 P0 项（按编号顺序）
3. 更新该项的完成进度

### 结束工作时

1. 更新本文件中已完成项的状态
2. 如果有新发现或计划变更，更新此文档
3. Commit 消息格式: `[Phase X] 完成: <任务描述>`

---

## 关键指标看板

| 指标 | 当前值 | Phase 2 目标 | Phase 3 目标 |
|------|--------|-------------|-------------|
| **标注漏洞总数 (examples)** | 49 | — | — |
| **CWE Top 25 覆盖率** | 44% | 60% | 80% |
| **Detector 数** | 26 (全 C/C++) | 26 + 6 Web 引导 | 26 + 12 Web 引导 |
| **真实审计案例** | 0 | 2 | 5 |
| **准确率 (Precision)** | 未测量 | ≥ 60% | ≥ 75% |
| **准确率 (Recall)** | 未测量 | ≥ 70% | ≥ 85% |
| **从安装到首个结果** | 3 分钟 | 1 分钟 | 30 秒 |
| **付费客户** | 0 | 0 | 1+ |

---

## 风险与阻断项

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| AI 审计准确率不可接受 (< 50% Precision) | 客户不付费 | 聚焦低 FP 的 crypto/command-injection skill |
| 开源项目审计无有价值发现 | 案例库无说服力 | 优先选择已知漏洞的项目 (WebGoat) |
| 竞品 (Copilot) 功能快速迭代 | 价值主张被稀释 | 加速差异化：聚焦业务逻辑审计 |
| LLM API 成本超预期 | 毛利下降 | 控制 skill 上下文字数，cache 已知结果 |

---

## 下次工作建议

从 **P0-1** 开始：对 `examples/cpp-vuln-demo` 运行完整的 AI 审计，收集第一份 TP/FP 准确率数据。这是所有后续工作的数据基础。
