# FEATURE-003: DeepSeek Full-Scan Review — Remediation

> **隶属 Epic**: EPIC-005 Architecture Refactoring
> **版本**: v0.1 (Final)
> **修改时间**: 2026-07-05

---

## 1. Problem Statement

DeepSeek V4 Flash 全仓检视（docs/architecture/review-arch-deepseek.md + review-check20260705.md）
共检出 7 项 Critical、8 项 High、2 项 Medium 的**实现级缺陷**，以及 6 项**架构级设计缺陷**。

前一轮已修复：C-1（版本号）、C-2（detectors_dir）、C-3（重复key）、C-4（self-check输出）、
C-6（opencode-plugin）、H-1（重复mkdir）、H-7（gitee URL）。

**本轮剩余待修复**：

### 分类

| 层级 | 可立即修复（本Feature） | 需独立Feature（架构级） |
|------|----------------------|----------------------|
| 实现级 | C-5 (O(n²)去重)、H-2 (构建错误检测)、H-3 (secfix清防)、H-8 (import上提) | C-7 (双解析器架构) |
| 架构级 | A-2 (JS正则保护)、A-4 (缓存hash校验) | A-1 (索引器价值)、A-3 (AI验证)、A-5 (部署重构) |

---

## 2. Requirements

### REQ-001: C-5 — MatchAllocFree O(n²) 缓解

**问题**: `internal/indexer/indexer.go:129-173` 中 `MatchAllocFree` 对每行malloc遍历全文件找free。

**修复方向**: 先做基于函数作用域的 hash 分组，将匹配范围缩小到同函数内，将 O(n²) 降为 O(n × 本函数行数)。
不做完整变量追踪——那是 CFG/DFG 层级的能力。

### REQ-002: A-2 — JS Regex 解析器增加大小防护

**问题**: `parser_re.go` 的 JS/TS 路径没有 Tree-sitter 的 512KB/2000行防护，跨平台二进制面对10MB压缩bundle.js可能OOM。

**修复方向**: 在 `parseJSFile`（或 regex 解析入口）增加同样的文件大小和行长限制。

### REQ-003: A-4 — 索引缓存增加内容hash校验

**问题**: `scripts/secguardian-index:36-55` 的缓存逻辑只比对路径，不比对文件内容，源码修改后缓存命中返回旧结果。

**修复方向**: 在缓存路径中增加源文件内容的 MD5 hash 检查。源码变 → hash 变 → 跳过缓存。

### REQ-004: H-2 — Go 并行编译错误追踪

**问题**: `scripts/package.sh:82-97` 中并行编译的失败被 `|| echo "[WARN]"` 吞掉。

**修复方向**: 添加 wait 退出码数组记录，构建失败汇总报告。

### REQ-005: H-3 — secfix.py 防御性 locals() 清理

**问题**: `scripts/secfix.py:170-172` 使用 `locals()` 检测变量存在性，防御性反模式。

**修复方向**: 确保变量在返回前已初始化，移除 locals() 检查。

### REQ-006: H-8 — render-report.py 函数内 import 上提

**问题**: `scripts/render-report.py` 多处函数内 `from collections import defaultdict/Counter`。

**修复方向**: 全部上提到文件顶部。

---

## 3. Non-Requirements

| 不做 | 原因 |
|------|------|
| C-7 双解析器架构统一 | 独立 EPIC，涉及 Go build tag 策略变更 |
| A-1 索引器价值悖论 | 需架构层面讨论，独立 FEATURE |
| A-3 AI 确定性验证 | Security Engine 研究方向，FEATURE-001 已覆盖 |
| A-5 三平台部署重构 | deploy.sh 重构成独立 FEATURE |

---

## 4. Success Criteria

| # | 标准 | 验证 |
|---|------|------|
| 1 | C-5: MatchAllocFree 非全文件遍历 | grep non_range |
| 2 | A-2: parser_re.go 有 size/line 限制 | grep 512*1024 |
| 3 | A-4: secguardian-index 有 hash 校验 | grep md5sum |
| 4 | H-2: package.sh 有 wait 返回码检查 | grep 'wait.*exit' |
| 5 | H-3: secfix.py 无 locals() | grep -c locals = 0 |
| 6 | H-8: render-report.py 函数内无 import | grep -c 'def.*import' = 0 |
| 7 | self-check 通过 | exit 0 |
