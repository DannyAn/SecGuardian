# Dogfood: SecGuardian 自扫描 — 2026-06-04

## 背景

用 `/secguard internal` 扫描自己的 Go 索引器代码。7 文件, 1040 行, 51 检测器。

## 扫描结果

**评分**: 79/100 (B) — 0 Critical, 1 High, 3 Medium

| ID | 严重度 | 文件:行 | 问题 | 修复 |
|----|--------|---------|------|------|
| H-CMD-diff_parser-L32 | 🟠 High | diff_parser.go:32 | `ref` 未校验传入 `git diff` 参数 | `strings.Contains(ref, "--")` 拦截 |
| M-EOP-main-L47 | 🟡 Medium | main.go:47 | `collectFiles` 错误被 `_` 吞掉 | 改为 `err` 捕获 + HEALTH:FAIL |
| M-EDL-main-L81 | 🟡 Medium | main.go:81 | 解析失败暴露完整文件路径 | `filepath.Base(f)` 仅打印文件名 |
| M-EDL-main-L54 | 🟡 Medium | main.go:54 | health check `%v` 暴露 parser 错误 | 保持 (CLI 工具, 风险可接受) |

## 修复后评分估算

94/100 (A) — 修复 3 项后只剩 1 个 Low 风险项。

## 教训

1. **参数校验盲区**: `exec.Command` 不防 shell injection，但防不住 git 参数注入。任何来自命令行的 ref 值都应拦截 `--`。
2. **错误吞掉是习惯病**: `_` 忽略错误在工具代码中很常见，health check 恰好撞枪口。
3. **路径泄露**: `filepath.Base` 是随手可用的一行修复，之前没注意到。
4. **狗粮价值**: 扫描自己的代码发现了 CLI 工具特有的输入信任边界问题——这类问题在扫描用户项目时很少关注。
