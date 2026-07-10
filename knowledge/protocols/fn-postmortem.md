---
category: protocol
version: "1.0"
---

# FN-PM: False Negative Post-Mortem 协议

> DTS 缺陷驱动检测能力增强的结构化分析流程。
> 每一个线上漏检的缺陷都是一次信号扩展或规则增强的机会。

## 协议原则

1. **缺陷即需求** — DTS 缺陷单是最真实的检测能力需求来源
2. **三层诊断** — 每个漏检根因必落在 Signal / Rule / Pipeline 三层之一
3. **必须产出 Action** — FN-PM 不以"分析完毕"结束，必须以具体增强措施结束
4. **回归锚定** — 修复后必须将缺陷代码片段纳为永久回归案例

---

## 执行流程

### 输入

```
DTS缺陷ID + 缺陷代码文件/行号 + 缺陷类型描述
```

### Step A: 信号层诊断

> 索引器能不能"看见"这个缺陷？

**操作：**

1. 对缺陷代码文件运行索引器，生成 `index.json`
2. 反查缺陷位置是否产生了信号：
   - `call_sites` 中是否有对应 callee？
   - `pointer_validations` 中是否有对应变量？
   - `struct_inits` 中是否有对应结构体？
   - `variable_writes` 中是否有对应变量？

**分类：**

| 情况 | 分类 | Action |
|------|------|--------|
| 缺陷位置无任何信号 | **Signal Gap — 信号缺失** | 见 A1-A3 |
| 信号存在但 category 不匹配 | **Signal Gap — 分类不足** | 扩展信号 category 枚举 |
| 信号存在且 category 正确 | 进入 Step B | |

**A1: callee 不在 callSitePatterns**

如果缺陷涉及标准库/系统调用，但函数名不在 `parser_re.go:callSitePatterns` 或 `parser_ts.go:knownLibFuncs` 中：

```
Action: 将函数名 + category 加到对应 pattern 表
改动范围: internal/parser/parser_re.go + parser_ts.go
验证: go test ./internal/parser/...
```

**A2: 需要新信号类型**

如果缺陷涉及的代码模式现有 6 种信号类型都不覆盖：

```
当前 6 种信号类型:
  S1: CallSite        — 函数调用点
  S2: StringLiteral   — 字符串常量
  S3: Declaration     — 变量/类型声明
  S4: ValueConstant   — 数值常量
  S5: Import          — include/import
  S6: ConfigPattern   — 配置赋值

需要评估是否新增 S7+ 信号类型。评估标准:
  - 此模式在代码中出现频率是否足够高？
  - 此模式是否能用 TreeSitter AST 节点可靠识别？
  - 此模式是否传统 AST 分析器 (clang) 无法或不便处理？

Action: 新增信号结构体 → types.go
       新增 TreeSitter collector → parser_ts.go
       新增 regex fallback → parser_re.go
       修改 indexer 输出 → indexer.go
验证: go test ./internal/... + 索引器产出包含新信号
```

**A3: 需要控制流/数据流级别的信号**

如果缺陷需要跨语句的分析（如"free 之后的代码路径中是否有 use"）：

```
此类缺陷是 SecGuardian 相比传统 SAST 的核心优势领域。
TreeSitter 提供完整的 AST，LLM 提供跨语句推理。

当前控制流信号: control_flow (仅 if_guard)

评估是否需要扩展:
  - 变量作用域内的 def-use 链
  - 函数调用图上的参数流追踪
  - 基本块级别的控制流

Action: 在 control_flow 信号中新增 kind 枚举值
       或新增 dedicated 信号类型
验证: index.json 产出包含新信号 + LLM 能据此推理
```

### Step B: 规则层诊断

> 信号有了，规则能不能把信号映射为 finding？

**操作：**

1. 查看 `skills/secguard/<lang>/rules/` 下是否存在覆盖此类缺陷的规则
2. 如果规则存在，检查 `signal_source` 是否覆盖了 Step A 确认的信号类型
3. 如果规则存在且 signal_source 覆盖，检查是否因 `false-positive.md` 过度抑制

**分类：**

| 情况 | 分类 | Action |
|------|------|--------|
| 无对应规则 | **Rule Gap — 规则缺失** | B1 |
| 规则存在但 signal_source 不覆盖 | **Rule Gap — 覆盖不足** | B2 |
| 规则触发但被 false-positive 抑制 | **Rule Gap — 过度抑制** | B3 |

**B1: 创建新规则**

```
Action:
  1. 新建 skills/secguard/<lang>/rules/<rule_name>/ 目录
  2. 创建 rule.md（含 Q1-Q2-Q3 事实锚定反射，按 FEATURE-006 标准）
  3. 创建 references/false-positive.md
  4. 创建 references/regression-cases/ 目录
  5. 更新 SKILL.md 索引表（如适用）
验证: self-check.sh 检测到新规则 + §14 Q-schema 通过
```

**B2: 扩展 signal_source**

```
Action:
  1. 修改 rule.md 的 signal_source 字段
  2. 扩展规则覆盖范围以包含新信号类型
验证: self-check.sh 通过 + 对缺陷代码重新扫描确认检出
```

**B3: 收紧抑制条件**

```
Action:
  1. 修改 references/false-positive.md
  2. 在抑制决策树中增加例外条件（"除非..."）
  3. 确保缺陷模式不被误抑制
验证: 对缺陷代码重新扫描，确认检出
```

### Step C: 管道层诊断

> 规则存在且信号覆盖，Pipeline 是否正确执行了？

**操作：**

1. 检查扫描输出目录 `workers/<rule>/` 是否存在
2. 验证管道工件：
   - `hypotheses.json` — 是否生成了正确的假设方向？
   - `evidence.json` — 证据链是否覆盖了缺陷位置？
   - `counter_evidence.json` — P2 是否错误地抑制了？
   - `judge_verdict.json` — Q1-Q2-Q3 判定矩阵是否错误？
   - `blindspot.json` — 盲区报告是否标记了此模式？

**分类：**

| 情况 | 分类 | Action |
|------|------|--------|
| Pipeline 工件缺失 | **Pipeline Gap** | 检查 FEATURE-006 是否部署到位 |
| P2 错误抑制 | **Pipeline Gap — 过度保守** | 加强 false-positive.md |
| Q1-Q2-Q3 错误判定 | **Pipeline Gap — 判定偏差** | 调优规则 Q-schema |

### Step D: 增强与锚定

> 修复完成后，把缺陷变成永久的回归测试。

**操作：**

1. 执行 Step A-C 确定的 Action
2. 在对应规则的 `references/regression-cases/` 下创建回归案例文件
3. 验证对缺陷代码片段重新扫描，确认检出
4. 更新 `self-check.sh` 如果新增了文件/目录

**回归案例文件模板：**

```markdown
# DTS-<ID>: <标题>

- **缺陷类型**: <指针未校验 | 结构体未初始化 | ...>
- **代码文件**: <路径>
- **缺陷行号**: <行号>
- **期望检出规则**: <detector ID，如 exec.input_validation>
- **期望 severity**: <Critical | High | Medium>
- **期望 CWE**: <CWE ID>
- **根因层**: <Signal Gap | Rule Gap | Pipeline Gap>
- **增强措施**: <简要描述做了什么改动>
- **增强日期**: <YYYY-MM-DD>
- **状态**: <已修复 | 验证中>

## 缺陷代码片段

\`\`\`c
// DTS 缺陷的核心代码片段（脱敏后）
\`\`\`

## 增强前漏检原因

<三层诊断结论>

## 增强后验证

- [ ] 索引器产出预期信号
- [ ] 规则触发并正确判定
- [ ] P2 Counter Evidence 未错误抑制
- [ ] Q1-Q2-Q3 判定正确
```

---

## 信号扩展决策树

当确认 Signal Gap 时，按以下决策树选择 Action：

```
缺陷模式涉及的是……
  │
  ├── 标准库/系统调用函数名不在表中
  │   └── A1: 加到 callSitePatterns 或 knownLibFuncs
  │
  ├── 新的代码模式类型（如指针校验、结构体初始化状态）
  │   └── A2: 新增信号类型 → types.go + parser_ts.go + parser_re.go
  │
  ├── 需要跨语句分析的复杂模式
  │   ├── 同一函数内 → 扩展 control_flow 信号
  │   └── 跨函数 → 增强 call_graph 信号 + LLM 推理
  │
  └── TreeSitter 语法无法可靠识别的模式
      └── 记录为 LLM-only 盲区（靠规则层的 context 分析覆盖）
          必须在 blindspot.json 中标记
```

---

## 产出物清单

每个 FN-PM 执行完成后必须产出：

1. **诊断报告**: 三层分析结论 + 根因分类
2. **增强变更**: Go 代码 / rule.md / false-positive.md 的具体改动
3. **回归案例**: `references/regression-cases/DTS-<ID>.md`
4. **验证确认**: 对缺陷代码片段重新扫描的结果
