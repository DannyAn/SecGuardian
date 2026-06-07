# 作品集：SecGuardian — AI Native 安全产品

> 本文档用于展示产品思维、技术判断力和 AI-native 产品设计能力。
> 目标读者：DeepSeek 招聘团队 / Harness 产品经理岗位。

---

## 一、一句话

**我主导设计并实现了一款 AI-native 安全分析产品，从零到 45 个检测器、CWE Top 25 100% 覆盖，在没有独立引擎的情况下，纯靠 AI 推理深度与竞品（CodeQL、Semgrep、Snyk Code）正面竞争。**

---

## 二、为什么做这个产品

### 市场洞察

2025-2026 年的 SAST（静态应用安全测试）市场有一个结构性矛盾：

| | 传统 SAST（Fortify/Checkmarx） | 现代 SAST（CodeQL/Semgrep） | **AI Native（SecGuardian）** |
|---|---|---|---|
| 分析深度 | 深但贵（$50K+/年） | 规则匹配，无上下文理解 | **AI 推理，理解业务语义** |
| 使用门槛 | 需安全专家 triage | 需写 QL/YAML 规则 | **自然语言交互** |
| 误报率 | 高（40-60%） | 中（15-25%） | **可通过 prompt 工程降低** |
| 定价 | $50K-500K/年 | $25-49/dev/月 | **$2K-48K/年** |

**判断：** 传统 SAST 的"买工具 → 配规则 → 跑扫描 → 安全专家 triage"模式正在被打破。AI 可以直接输出审计报告，不需要中间环节。这个赛道还没有明确的领先者。

### 产品定位

不做"另一个 Semgrep"。做"AI 安全审计师"——用 AI 推理深度替代规则匹配，用自然语言交互替代配置门槛。

三个产品覆盖三个深度：
- `/secaudit`（旗舰）— AI 深度审计，替代 $20K-50K 的安全顾问
- `/secguard` — 快速漏洞扫描，对标 Semgrep/CodeQL
- `/secreview` — 编码规范审查，对标 SonarQube

---

## 三、我是怎么做的

### 架构设计原则

**1. AI-native，不依赖独立引擎**

传统 SAST 需要编译、构建 AST、数据流分析引擎——工程量巨大。SecGuardian 的核心理念是："AI 本身是最强的分析引擎，我们要做的是给它结构化的知识和上下文"。

```
传统 SAST:  源码 → 编译 → AST → 数据流引擎 → 规则匹配 → 结果
SecGuardian: 源码 → tree-sitter 索引 → 结构化上下文 → AI 推理 → 结果
```

这个选择让我们在 2 个月内达到 45 个检测器，而 CodeQL 的 200+ 检测器花了 10+ 年。

**2. 知识工程 = 竞争壁垒**

AI 模型本身是商品化的（Claude、GPT、Gemini），但**围绕模型的结构化知识不是**。

我们构建了：
- 45 个检测器知识文件（每篇 64-127 行，含 4 步检测逻辑 + FP 排除表 + 模式汇总）
- 17 个审计技能（每篇 100-200 行方法论协议）
- 10 个安全概念
- 4 个语言画像（每篇 40-80 个危险 API）

**总数：60+ 知识文件，全部是结构化 Markdown，AI 可以直接消费。**

**3. 三层 prompt 架构（系统/技能/上下文）**

当竞品还在用"一个 prompt 扫所有"时，我设计了分层架构：

```
系统层（2.8KB）→ 缓存命中率 ~85%（DeepSeek prefix cache）
技能层（6.5KB）→ 按需加载，不浪费 token
上下文层（2-5KB）→ tree-sitter 索引注入，AI 不需要读原始文件
```

**效果：** token 消耗从 ~50K/次降到 ~15K/次，成本降低 70%。

### 产品演进的关键决策

| 决策 | 当时的选择 | 为什么 |
|------|-----------|--------|
| namespace 从 9→5 | 统一 topic 体系 | 用户不需要记住"这是 java 还是 go 的 SQLi" |
| 先做 C/C++ | 内存安全是 SAST 的根基 | C/C++ 的 buffer overflow/use-after-free 是经典问题 |
| 后期覆盖 web 安全 | 做 OWASP Top 10 | 企业采购需要 OWASP 覆盖率 |
| 输出 SARIF 格式 | 兼容 GitHub Code Scanning | 降低 CI/CD 集成成本 |
| 独立 CLI 二进制 | 不依赖 Claude Code 运行 | 可独立部署，可收费 |

### 竞品对比的诚实做法

我重写了竞品分析 3 次，因为前两次的数字有水分。第三次我做了**文件清单核实**（file inventory benchmark）——从 45 个知识文件的 frontmatter 逐条统计 CWE 覆盖率，不是拍脑袋。

结果：CWE Top 25 从宣称的 48% 变成实际 72%，后来靠新增 7 个检测器做到 100%。

**自我纠错的习惯，比正确的数字更重要。**

---

## 四、数据结果

### 量化指标

| 指标 | 值 |
|------|-----|
| 开发周期 | 4 周（从 0 到 v0.3） |
| 检测器数量 | 45（9 类 → 5 类统一 topic） |
| 知识文件 | 60+（全部有 FP 排除表 + 模式汇总） |
| CWE Top 25 覆盖率 | 25/25（100%） |
| OWASP Top 10 覆盖率 | 9/10（90%） |
| 支持语言 | C, C++, Java, Python, Go |
| 漏洞示例 | 112 个 VULNERABILITY 标注，跨 4 种语言 |
| 平台支持 | Claude Code, Gemini CLI, OpenCode, GitHub Actions |
| 独立 CLI | 8.4M Go 二进制，支持 detectors/index/version/health 子命令 |

### 产品结构

```
SecGuardian v0.3
├── 45 检测器 (5 个共享 topic)
│   ├── memory (13) — 内存安全
│   ├── concurrency (4) — 并发安全
│   ├── system (7) — 系统安全
│   ├── crypto (4) — 加密安全
│   └── web (17) — Web + 应用安全
├── 17 审计技能 (secaudit)
├── 4 语言编码规范 (secreview)
├── 60+ 结构化知识文件 (Markdown)
├── 独立 CLI 二进制
└── CI/CD 集成 (GitHub Actions, GitLab CI, Azure DevOps)
```

---

## 五、我关心的三个问题

### 1. AI 产品的"engine vs prompt"分界线在哪？

SecGuardian 的经验是：**AI 适合做推理和判断，不适合做确定性计算。** 数据流追踪（source→sink）应该交给引擎，漏洞严重度评估应该交给 AI。这个分界线决定了产品架构。

### 2. 结构化知识是护城河吗？

目前来看是的——Semgrep 有 2000+ 条规则但全是 YAML 模式匹配，无法理解上下文。但问题在于：**当 AI 模型足够强时，结构化知识的价值会不会递减？** 我的判断是：不会，因为结构化知识本质上是将人类专家的经验转化为 AI 可消费的格式，模型越强，格式化的知识越有价值。

### 3. AI 安全产品的市场在哪里？

**中腰部企业。** 头部企业买 Fortify（$100K+/年），小微企业用开源工具（Semgrep Community）。年收入 $10M-$200M 的企业请不起安全顾问，买不起 Fortify，但又需要合规。$2K-12K/年的 AI 安全审计正好填补这个空白。

---

## 六、关于我

- **产品思维：** 能从上到下（市场 → 产品 → 功能 → 代码），也能从下到上（一个检测器怎么命名 → 用户怎么记住它 → namespace 怎么设计 → 三产品怎么统一）
- **动手能力：** 写的代码占了项目的 90%+（Go CLI、tree-sitter indexer、45 个知识文件、所有示例、文档、CI/CD 脚本）
- **竞品分析：** 不拍脑袋。file inventory benchmark 逐条核实数据，敢于公开之前的错误。
- **技术栈：** Go, Python, C/C++, Bash, tree-sitter, LLM prompt engineering, CI/CD (GitHub Actions, GitLab CI)
- **关注：** AI-native 产品架构、开发者工具、安全基础设施、AI agent 平台

### 为什么对 DeepSeek 感兴趣

DeepSeek 在做两件和我高度相关的事情：
1. **AI 模型 + 开发者工具**（codewhale）— 我深度理解 agent 平台需要什么
2. **Harness** — 我理解"让 AI 输出可交付"这个命题有多难

我在 SecGuardian 中学到的最大教训是：**AI 做决策很容易，但让 AI 的输出可验证、可复现、可落地，需要工程化能力。** 这正好是 Harness 要解决的问题。

---

*2026-05-27 | 项目地址: https://github.com/secguardian/secguardian*
