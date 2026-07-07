# FEATURE-001: CallSite Struct Definition

> **对应 Task**: 1.1
> **文件**: `internal/parser/types.go`
> **验证**: `go build ./...`

## 规格

在 `types.go` 中新增以下类型：

```go
// CallSite represents a library function call detected in source code.
// Unlike FunctionInfo which tracks function definitions, CallSite tracks
// each invocation of a known library function (strcpy, malloc, system, etc.).
// This is the primary signal source for Worker scheduling in EPIC-3.
type CallSite struct {
	CallerFunction string   `json:"caller"`
	CalleeName     string   `json:"callee"`
	File           string   `json:"file"`
	Line           uint     `json:"line"`
	Arguments      []string `json:"arguments"`
	IsSafeVariant  bool     `json:"safe_variant"`
	Category       string   `json:"category"`
}
```

在 `ParseResult` 中新增字段：

```go
type ParseResult struct {
	File      string         `json:"file"`
	Language  string         `json:"language"`
	Functions []FunctionInfo `json:"functions"`
	Variables []VariableInfo `json:"variables"`
	Types     []TypeInfo     `json:"types"`
	CallSites []CallSite     `json:"call_sites"`
}
```

## 字段说明

| 字段 | 说明 | 示例值 |
|------|------|--------|
| `CallerFunction` | 包含该调用的函数名 | `"idm_portal_auth"` |
| `CalleeName` | 被调用的函数名 | `"strcpy_s"` |
| `File` | 源文件路径 | `"src/auth.c"` |
| `Line` | 调用点行号（1-based） | `142` |
| `Arguments` | 参数摘要列表 | `["dst", "sizeof(dst)", "src"]` |
| `IsSafeVariant` | 是否是 `_s` 安全变体 | `true` (for strcpy_s) |
| `Category` | 功能类别 | `"memory"`, `"string"`, `"io"`, `"exec"`, `"sync"`, `"crypto"` |

## 约束

- `CallerFunction` 可为空（当调用出现在文件层级而非函数体内时）
- `Line` 必须精确到调用点行号，而非函数起始行
- `Arguments` 是原始参数文本，长度限制 128 字符/参数，超过的截断
- `Category` 值域限定：memory, string, io, exec, sync, crypto
- CallSite 的零值（空切片）对 JSON 序列化为 `[]` 而非 `null`
