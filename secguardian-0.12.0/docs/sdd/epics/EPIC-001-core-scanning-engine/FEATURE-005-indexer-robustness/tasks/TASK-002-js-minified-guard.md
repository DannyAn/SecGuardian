# TASK-002: JS minified bundle 解析防御

> **Feature**: FEATURE-005 (Indexer Robustness)
> **REQ**: REQ-002
> **ADR**: ADR-002, ADR-005

## Goal

`parser_javascript.go` 在解析 JS 文件前增加双阈值守卫，避免对 >512KB 或单行字符 >2000 的 minified bundle 进行正则解析。

## Done

- [ ] `internal/parser/parser_javascript.go`: `parseJSFile()` 入口处增加文件大小检查 (`>512KB → 跳过`)
- [ ] `internal/parser/parser_javascript.go`: 读取内容后增加行长检查（`任一行 >2000 字符 → 跳过`）
- [ ] 跳过时返回正常的 `ParseResult`（空函数列表，无错误），不输出 warning 到 stdout
- [ ] Go build 通过
- [ ] 对大型 JS bundle 确认解析被跳过（`Symbols: 0 functions`）

## Files Changed

### internal/parser/parser_javascript.go

在 `parseJSFile()` 函数开头增加守卫：

```go
func parseJSFile(filePath string) (*ParseResult, error) {
    // Guard: skip files >512KB (likely minified bundles)
    fi, err := os.Stat(filePath)
    if err != nil {
        return nil, err
    }
    if fi.Size() > 512*1024 {
        return &ParseResult{
            File:     filePath,
            Language: "javascript",
        }, nil
    }

    content, err := os.ReadFile(filePath)
    if err != nil {
        return nil, err
    }

    // Guard: skip minified single-line files (>2000 chars on any line)
    text := string(content)
    lines := strings.Split(text, "\n")
    for _, line := range lines {
        if len(line) > 2000 {
            return &ParseResult{
                File:     filePath,
                Language: "javascript",
            }, nil
        }
    }

    // ... rest of parsing logic unchanged ...
    result := &ParseResult{
        File:     filePath,
        Language: "javascript",
    }
```

## Verification

```bash
cd /Users/kongan/workbench/github/secguardian

# Build
go build ./...

# 1. 正常 JS 文件仍可解析
echo "console.log('hello');" > /tmp/test_normal.js
go run . --path /tmp --lang javascript --output /tmp/task002-test.json 2>&1
python3 -c "
import json
d = json.load(open('/tmp/task002-test.json'))
print(f'Normal JS: {d[\"function_count\"]} functions (should be 0-1)')
"

# 2. 单行 >2000 字符的"minified-like"文件被跳过
python3 -c "
open('/tmp/test_minified.js', 'w').write('x=' + 'a' * 3000 + ';')
"
go run . --path /tmp --lang javascript --output /tmp/task002-minified.json 2>&1
# 确认不报错，且 0 functions
python3 -c "
import json
d = json.load(open('/tmp/task002-minified.json'))
print(f'Minified JS: {d[\"function_count\"]} functions (should be 0)')
assert d['function_count'] == 0, f'Expected 0 functions for minified, got {d[\"function_count\"]}'
print('✅ Minified bundle correctly skipped')
"
```
