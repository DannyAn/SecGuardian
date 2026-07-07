# SecGuardian 全仓检视报告

> **日期**: 2026-07-05
> **范围**: 实现级缺陷 + 架构级设计缺陷
> **方法**: 人工代码审计 + AI 辅助架构分析

---

## 目录

1. [实现级缺陷（Critical）](#1-实现级缺陷critical)
2. [实现级缺陷（High）](#2-实现级缺陷high)
3. [实现级缺陷（Medium）](#3-实现级缺陷medium)
4. [架构级设计缺陷](#4-架构级设计缺陷)

---

## 1. 实现级缺陷（Critical）

### C-1. 版本号系统彻底混乱 — 至少 4 个不同版本号共存

| 位置 | 版本 | 问题 |
|------|------|------|
| `manifest.json` | **0.12.0** | 权威版本 |
| `internal/main.go:26` | **0.12.0** | 一致 |
| `scripts/deploy.sh:194` | **0.5.4**（硬编码） | 落后 19 个次版本 |
| `scripts/deploy.sh:565` | **0.5.5**（硬编码） | 与上面不同 |
| `scripts/dev-verify.sh:116` | `EXPECTED_VER="0.5.5"` | 验证脚本验收错误版本 |
| `extensions/*/extension.json` | **0.12.0** | 一致 |

`deploy.sh:655` 注释写着 `version "0.5.4" below should match manifest.json version` 但实际从未同步过。发布时版本号对比会全部失败，部署验证直接误判。

---

### C-2. `render-report.py` 检测器索引路径硬编码错误，永远走回退

**文件**: `scripts/render-report.py:46-47`

```python
detectors_dir = os.path.join(script_dir, "..", "knowledge", "detectors")
```

目录 `knowledge/detectors/` **不存在**（实际为 `knowledge/guard-rules/`）。导致 `load_detector_index_from_files()` 每次返回 `None`，永远走 `:130` 行硬编码回退表。

后果：
- 新增检测器后 `render-report.py` 无法感知
- `DETECTOR_RULE_INDEX` 硬编码表和实际 67 个检测器不一致的风险

---

### C-3. `render-report.py` 硬编码回退表含重复 key

**文件**: `scripts/render-report.py:99` 与 `:159`

`web.jwt-misuse` 被定义了两次。Python 字典语法中后出现的覆盖前者，但两次的 `index` 值不同（8 vs 8 — 巧合相同）。如果未来分开维护，会产生隐形覆盖。

---

### C-4. `self-check.sh` 输出内容被破坏 — 嵌入错误文本

**文件**: `scripts/self-check.sh:161-165`

原意是打印 `Total: $SKILL_COUNT skills`，但由于 heredoc/引号嵌套错误，实际输出了 markdownlint 检查的 `else` 分支代码。导致 Sec 5（Skills structure）的检查结果不可读。

---

### C-5. 索引器 `MatchAllocFree` O(n²) + 无关联匹配 — 生产级别不可用

**文件**: `internal/indexer/indexer.go:129-173`

- 对每行每次 `malloc`，遍历**整个文件所有行**寻找 `free` — O(n²)
- **所有 free 调用都被算作匹配**，不做变量追踪（`free(buf)` vs `free(ptr)` 一视同仁）
- 同一个 `free` 可能被多个 `malloc` 重复匹配
- 在 10 万行 C 文件上索引会退化到秒级甚至分钟级

---

### C-6. `package.sh` 不包含 `opencode-plugin.js`，OpenCode 部署断链

`scripts/package.sh` 的 dist 打包**不复制 `opencode-plugin.js`**（`scripts/deploy.sh:571-572` 直接从源码目录拷贝）。意味着任何第三方通过 `package.sh` 构建的 dist/ 部署后，OpenCode 的插件注册（注册 `/secguard` 等命令、设置 skills/knowledge 路径）完全缺失。

验证：`grep -c 'opencode-plugin' scripts/package.sh` → 0

---

### C-7. 双解析器输出不一致 — 同一代码不同结果

`parser_re.go` 和 `parser_ts.go` 对同一代码产生不同的符号表：

- Regex 版无法识别嵌套类型（Go 的 `type X struct { ... }`）、方法接收者（`func (r *T) Method()`）
- Regex 版 Java 类型检测只匹配行首的 `class`/`interface` 声明，遗漏内部类
- Regex 版变量提取只匹配有限类型列表（Python 版甚至匹配任何 `=` 赋值，污染变量表）

---

## 2. 实现级缺陷（High）

### H-1. `package.sh` 重复创建目录

**文件**: `scripts/package.sh:126-131`

```bash
"$dist_dir/knowledge/audit-rules" \      # 第 1 次
"$dist_dir/knowledge/review-rules" \     # 第 1 次
"$dist_dir/knowledge/audit-rules" \      # 第 2 次（重复）
"$dist_dir/knowledge/review-rules" \     # 第 2 次（重复）
```

逻辑正确但容易误导后续维护者。

---

### H-2. Go 构建并行缺错误传播

**文件**: `scripts/package.sh:82-97`

5 个平台用 `&` 并行编译，但 `|| echo "[WARN]"` 吞掉了编译失败。如果 CGO 构建失败，后续部署的索引器二进制可能是旧的或空的。没有 `wait` 的返回值检查。

---

### H-3. `secfix.py` 未初始化局部变量引用

**文件**: `scripts/secfix.py:170-172`

```python
"file": file_path if "file_path" in locals() else "",
"line": line if "line" in locals() else 0,
"description": description if "description" in locals() else "",
```

这三个变量定义在 `process_finding()` 中，但如果 `before`/`after` 都为空且 `file_path` 为空，函数提前返回 `None`。`locals()` 防御是反模式。

---

### H-4. `load_detector_index_from_files()` 路径不匹配部署结构

**文件**: `scripts/render-report.py:38-79`

函数从 `knowledge/detectors/` 加载（不存在），应改为 `knowledge/guard-rules/`。

---

### H-5. 调用图使用字符串包含近似 — 误报率高

**文件**: `internal/indexer/indexer.go:97`

```go
strings.Contains(body, callee.Name+"(")
```

子串匹配会命中字符串字面量、变量名包含函数名。不构建作用域，不追踪函数指针。

---

### H-6. `detectLanguage()` 默认回退到 "c"

**文件**: `internal/main.go:223`

```go
return "c"
```

任何无法识别的文件扩展名（如 `.rs`, `.kt`, `.ts`）都会被当作 C 语言解析。

---

### H-7. 硬编码 gitee.com URL

**文件**: `scripts/deploy.sh:196,198,303,305`

大量引用 `https://gitee.com/jonyan/secguardian`，但项目对应的 GitHub 是 `DannyAn/SecGuardian`。

---

### H-8. `render-report.py` 大量 import 在函数体内

函数内重复 `from collections import defaultdict`/`Counter`（`:409,427,900,915`），违反 PEP 8，增加每函数调用开销。

---

## 3. 实现级缺陷（Medium）

### M-1. `render-report.py:generate_delta` 符号链接跟随缺乏安全性检查

**文件**: `scripts/render-report.py:853`

`os.path.realpath(latest_link)` 不做循环链接检测或路径校验。

---

### M-2. 无数据流分析 — 索引器能力与产品宣称严重不符

虽然 `manifest.json` 宣称覆盖 CWE Top 25（100%）、OWASP Top 10（100%），但索引器无 CFG、无 DFG、无 taint tracking。所有检测完全依赖 AI Agent 对 Markdown 规则的语义理解。实际检测覆盖率取决于 AI 模型能力，而非索引器。

---

## 4. 架构级设计缺陷

### A-1. 🔴 索引器价值悖论 — 重 I/O 轻推理

**文件**: `internal/indexer/indexer.go:76,134,183`

`BuildCallGraph`、`MatchAllocFree`、`BuildLockGraph` 全部用 `os.ReadFile(result.File)` **重新读源文件**，而非利用自己的内存 ParseResult。索引器做了 parse → 丢弃 AST → 重新读文件 → 文本扫描。

更根本的是：索引器的输出（符号坐标 + 文本近似调用图 + 同文件 alloc/free）对于 AI Agent 来说**不是必需信息**。AI 自己读源码得到的分析深度远超过索引器能提供的。

`package.sh:82-97` 中的 5 平台并行编译，每失败一个平台只有一句 `echo "[WARN]"` — 没有导致 CI 中断。索引器可以一直静默地构建失败，但部署和运行表面上毫无异常。

---

### A-2. 🔴 三解析器架构有隐蔽的分叉 — JS 防护只在 CGO 生效

| 文件 | 构建标签 | 编译时机 | JS 大小/压缩防护 |
|------|---------|---------|----------------|
| `parser_ts.go` | `cgo` | CGO=1 | ✅ 委托 `parseJSFile()`，有 512KB 和 2000 字符行防护 |
| `parser_re.go` | `!cgo` | CGO=0 | ❌ 无防护，直接 regex 全文匹配 |
| `parser_javascript.go` | 无标签 | 始终编译 | ✅ 有防护但 !CGO 下死代码 |

`parser_javascript.go` 没有 build tag，始终被编译进二进制。但在 `!cgo` 模式下，`ParseFile()` 来自 `parser_re.go`，从不调用 `parseJSFile()`。

后果：**跨平台二进制（linux-amd64, windows-amd64 等）解析 JS 时没有 minified-file 防护**。10MB 压缩 bundle.js 可能导致 OOM。

AGENTS.md 要求「两个 parser 逻辑等价」，但这里并不等价。

---

### A-3. 🔴 AI 是唯一事实源，但没有任何「规则遵循」的确定性验证

核心架构链：
```
detector rules (.md 自然语言) → AI 阅读理解 → AI 应用判断 → findings.json
```

确定性验证只有结构格式检查（`validate-findings.py` 检查字段存在性），**没有任何语义校验**：

- AI 可以跳过 67 个检测器中的任意一个而不报错
- AI 的 `judgment_rationale` 无法与 detector 规则原文交叉验证
- AI 可以产生一个包含全部必填字段但逻辑完全错误的 finding
- **没有 false positive / false negative 基线机制**

`render-report.py:38-79` 尝试从文件系统读取 detector frontmatter 来构建索引映射，但这只校验了 `detector` 字段名称是否合法，不校验 AI 是否正确应用了该规则。

---

### A-4. 🟠 共享索引缓存设计 — 路径比对，脆且不安全

**文件**: `scripts/secguardian-index:36-55`

缓存逻辑：如果 index.json 存在且存储路径 == 当前路径 → 跳过构建。

故障模式：
1. **无内容变更检测**：用户改了源码但路径不变 → 用旧索引扫描 → 漏报
2. **无并发保护**：`/secguard` 和 `/secaudit` 同时执行 → shell 层无锁 → 读半写文件
3. **无损坏检测**：缓存命中时直接 exit 0，不跑 `--health` 验证 index.json 完整性
4. **跨命令污染**：三个命令共享一个 index.json，任一命令产生部分写入 → 全部中毒
5. **Python 是硬依赖**：shell wrapper 强依赖 `python3`，Go 二进制本身不需要

---

### A-5. 🟠 三平台部署 80% 代码重复，缺乏单一抽象层

**文件**: `scripts/deploy.sh`

- `deploy_claude()`: 第 170-264 行，95 行
- `deploy_opencode()`: 第 524-629 行，106 行
- `deploy_gemini()`: 第 631-748 行，118 行

三个函数核心结构完全一致：清理旧目录 → mkdir 标准子目录 → 复制 commands/skills/knowledge/scripts → 部署索引器 → 写 .secguardian-env。只有末尾 10-20 行的平台注册逻辑不同。

如果将来新增一个知识类别（如 `knowledge/threat-intel/`），需要修改**三处**。

`do_zip()`（`:757-796`）从已部署的目录读取来打包，而非从 `dist/` 源目录构建。zip 内容取决于「之前 deploy 过的状态」，而非「package.sh 构建的内容」。

---

### A-6. 🟠 SDD 架构文档与实际代码存在根本性鸿沟

**文件**: `docs/sdd/epics/EPIC-005-architecture-refactoring/FEATURE-002-contract-landing/spec.md`

> 「当前 production 代码与架构定义之间不存在对应关系」
> 「命令 594 行 + 技能 141 行，包含引擎层逻辑，而合约要求它们只是薄分发器」
> 「当前系统没有独立的 Engine 层。LLM prompt 本身就是执行引擎。」

架构文档描述的是「应该有 Engine 层 + 薄命令 + 薄技能」的理想态，而实际代码是「命令巨文件 + 技能巨文件 + 无 Engine 层」的现实态。

EPIC-003 (`docs/sdd/epics/EPIC-003-code-health-and-hygiene/`) 存在目录但**没有任何 Feature Package** — 是空壳。

---

## 汇总

| 级别 | 数量 | 关键问题 |
|------|------|---------|
| 🔴 实现级 Critical | 7 | 版本号混乱、索引路径错误、输出被破坏、索引器 O(n²)、部署断链、双解析器不一致、重复 key |
| 🟠 实现级 High | 8 | 构建目录重复、错误被吞、变量引用风险、调用图误报高、默认回退 C 语言、URL 错误、函数内 import |
| 🟡 实现级 Medium | 2 | 符号链接安全、能力/宣称差距 |
| 🔴 架构级 Critical | 3 | 索引器价值悖论、JS 防护分叉、AI 无确定性验证 |
| 🟠 架构级 High | 3 | 共享索引缓存脆弱、三平台部署冗余、SDD 文档/代码鸿沟 |

**核心结论**: 项目的最大架构风险来自「索引器价值悖论」(A-1) 与「AI 无确定性验证」(A-3) 的叠加。索引器做了重 I/O 轻推理的工作，AI 的分析质量又无确定性保障，导致整个安全分析管线的实际输出质量完全不可预测。

---

*Generated by SecGuardian 全仓检视, 2026-07-05*
