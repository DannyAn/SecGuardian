# TASK-003: auto 模式路径排除扩展

> **Feature**: FEATURE-005 (Indexer Robustness)
> **REQ**: REQ-003
> **ADR**: ADR-004

## Goal

`internal/main.go` 的 `skipDir` 列表增加 `target/`、`build/`、`static/`、`public/`，使索引器在 auto 模式下跳过常见的构建产物目录。

## Done

- [ ] `internal/main.go`: `collectFiles()` 中 `skipDir` 检查增加 `target`、`build`、`static`、`public`、`resources`
- [ ] Go build 通过
- [ ] 确认 `--lang java` 时仍只索引 .java 文件（扩展名过滤优先）

## Files Changed

### internal/main.go

在 line 164 的 `skipDir` 检查列表中增加条目：

```go
// 当前 (line 164):
if base == ".git" || base == ".claude" || base == ".codeagent" ||
   base == ".gemini" || base == ".opencode" ||
   base == "node_modules" || base == "dist" {
    return filepath.SkipDir
}

// 修改后:
if base == ".git" || base == ".claude" || base == ".codeagent" ||
   base == ".gemini" || base == ".opencode" ||
   base == "node_modules" || base == "dist" ||
   base == "target" || base == "build" ||
   base == "static" || base == "public" {
    return filepath.SkipDir
}
```

## Verification

```bash
cd /Users/kongan/workbench/github/secguardian

# Build
go build ./...

# 确认 target/ 被排除
mkdir -p /tmp/test_scan/target/java
echo 'class Test {}' > /tmp/test_scan/target/java/Test.java
echo 'class Real {}' > /tmp/test_scan/Real.java

go run . --path /tmp/test_scan --output /tmp/task003-no-target.json 2>&1
python3 -c "
import json
d = json.load(open('/tmp/task003-no-target.json'))
assert 'Real.java' in str(d['files']), 'Real.java should be indexed'
for f in d['files']:
    assert 'target/' not in f, f'target/ should be excluded: {f}'
print(f'✅ Files indexed: {d[\"file_count\"]} (Real.java included, target/ excluded)')
"
```
