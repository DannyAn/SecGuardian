# SecGuardian 商业化路线图

> 从当前状态到可收费产品的差距分析与实施计划

---

## 一、当前状态 vs 可收费状态

### 当前产品形态

```
用户在 Claude Code 内执行 /secaudit taint-analysis
  → AI 加载 SKILL.md + knowledge 文件
  → AI 直接在对话中输出审计结果
  → 结果手写到 .codeagent/ 目录
  → 用户手动查看
```

### 要收费需要达到的产品形态

```
用户在终端执行 secguardian audit --skill taint-analysis ./src --output report.md
  → CLI 自动加载 skill + knowledge
  → 运行审计流程
  → 生成 findings JSON + SARIF
  → 生成客户可交付的审计报告 (Markdown/PDF)
  → 输出安全评分和趋势
  → 可选: 上传到 GitHub Code Scanning
```

**核心差距**: 产品目前是 Claude Code 插件，不是独立产品。客户不能"购买并使用"它。

---

## 二、差距清单与优先级

### 🔴 P0 — 必须做才能收费

| # | 差距 | 当前状态 | 目标状态 | 工作量 |
|---|------|---------|---------|--------|
| 1 | **独立 CLI** | 只能在 Claude Code 内使用 | 独立 CLI 工具，不依赖任何 IDE | 2-3 天 |
| 2 | **审计报告生成** | AI 对话输出 | 格式化的 Markdown 审计报告 | 1 天 |
| 3 | **质量基准** | 无准确率数据 | 在 examples/ 上统计 TP/FP/漏报 | 1 天 |
| 4 | **定价模型清晰化** | 未定 | 明确 3 档定价 + 免费 tier | 0.5 天 |

### 🟡 P1 — 收费后第一优先级

| # | 差距 | 说明 |
|---|------|------|
| 5 | **Onboarding 体验** | 5 分钟从安装到第一个审计结果 |
| 6 | **案例库** | 5-10 个真实审计 case 作为销售材料 |
| 7 | **CI/CD 深度集成** | GitHub Actions 模板 + GitLab CI 模板 |
| 8 | **多 skill 串联** | 一次运行 taint-analysis + auth + crypto 三项 |

### 🟢 P2 — 规模化后

| # | 差距 | 说明 |
|---|------|------|
| 9 | **自定义 skill** | 企业客户编写自己的审计 skill |
| 10 | **Dashboard** | Web 界面查看审计历史和趋势 |
| 11 | **SaaS 交付** | API + Web，非 CLI 运行 |
| 12 | **合规报告** | SOC2/ISO27001 合规审计模板 |

---

## 三、实施计划

### Phase 1: 独立产品骨架（本次实现）

```
目标: 任何人可以在终端执行并得到审计报告

交付物:
1. scripts/secguardian.sh        # CLI 入口
2. scripts/audit-runner.sh       # 审计执行引擎
3. knowledge/report-template.md  # 审计报告模板
4. scripts/benchmark.sh          # 质量基准测试
5. docs/case-study-template.md   # 案例模板
```

### Phase 2: 质量验证（下一步）

```
目标: 有数据支撑的准确率声明

交付物:
1. 每个 skill 在 examples/ 上的 TP/FP 统计表
2. 每个 language 在 examples/ 上的覆盖率报告
3. 误报原因分析 + 改进建议
```

### Phase 3: 销售就绪（下下一步）

```
目标: 可以演示给客户并获得付费意愿

交付物:
1. 5 个开源项目的安全审计报告 (案例)
2. 演示视频/GIF
3. Pricing page 文案
4. 试用流程 (Signup → Install → First Audit < 5min)
```

---

## 四、定价模型详情

| 层级 | 价格 | 包含 | 目标客户 |
|------|------|------|---------|
| **Free Tier** | $0 | 1 次/月，单 skill，公开报告 | 个人开发者 |
| **Pro** | $2K/年 | 无限次，3 skill，私有报告，SARIF | 创业公司 |
| **Team** | $12K/年 | 无限次，全部 17 skill，CI/CD，多人 | 中型企业 |
| **Enterprise** | $48K/年 | 自定义 skill，SLA，合规报告，私有部署 | 大型企业 |

### 定价逻辑

- **锚定安全顾问费用**: 一次手工审计 $20K-50K，你收 $2K 是 10x ROI
- **不与 SAST 比价**: Semgrep $40/dev/月是完全不同的产品类别
- **按次收费 vs 年费**: Free tier 用按次限制作为转化漏斗，Pro+用年费锁定客户

### Unit Economics 验证

| 指标 | Pro | Team | Enterprise |
|------|-----|------|------------|
| 年收入/客户 | $2K | $12K | $48K |
| 获客成本 (CAC) | $500-1K | $3-5K | $10-20K |
| 服务成本/年 | ~$200 (LLM API) | ~$500 (LLM API) | ~$1K + support |
| 毛利 | 80%+ | 85%+ | 80%+ |
| 回本周期 | 3-6 月 | 3-5 月 | 3-5 月 |

**关键假设**: LLM API 调用费用控制。如果每次审计消耗 $5-10 API tokens，Pro 用户年审计 50 次，成本 $250-500。

---

## 五、Phase 1 详细实施（本次实现）

### 1. 独立 CLI 入口 (`scripts/secguardian.sh`)

```
用法:
  secguardian audit --skill taint-analysis --path ./src --output report.md
  secguardian scan --path ./src --filters memory.* --sarif
  secguardian review --path ./src --lang python

功能:
  - 自动加载对应 skill 的 SKILL.md
  - 自动加载 knowledge/ 下的概念、语言画像、协议
  - 组装为完整的 system prompt
  - 输出审计执行指南给用户 (因为 AI 需要在 Claude 中执行)
  - 生成 scan-id 和输出目录
```

### 2. 审计报告模板 (`knowledge/report-template.md`)

- 执行摘要
- 安全评分 (0-100)
- 按严重度分组的发现列表
- 每个发现的详情 (代码位置/数据流/影响/修复)
- 安全趋势 (如有历史数据)
- 附录 (扫描范围、方法说明)

### 3. 质量基准 (`scripts/benchmark.sh`)

- 对每个 language 的 examples/ 运行 secguard
- 统计检出数 vs 预期数 (注释标注的 VULNERABILITY)
- 计算 TP/FP/FN
- 输出 per-skill per-language 的准确率表

---

## 六、时间线与里程碑

| 时间 | 里程碑 | 可验证指标 |
|------|--------|----------|
| **今天** | Phase 1 完成 | CLI 入口 + 报告模板 + 基准脚本 |
| **Week 2** | Phase 2 完成 | 准确率报告 (TP/FP 数据) |
| **Week 3** | 案例库 5 个 | 5 个真实审计报告 |
| **Month 1** | 第一个付费客户 | $2K Pro 订阅 |
| **Month 3** | 10 个付费客户 | $16K ARR |
| **Month 6** | 50 个付费客户 | $100K ARR |
