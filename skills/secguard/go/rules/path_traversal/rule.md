---
name: secguard-go-path-traversal
description: "Detect path traversal via os.Open, filepath.Join with user input — ../ sequences break directory boundaries"
language: go
topic: [system, filesystem]
skill_id: go.system.path-traversal
signal_filter: go.system.path-traversal*
signal_source: call_sites[callee="Open|Create|OpenFile|ReadFile|WriteFile|ServeFile|ReadAll"]
severity: high
cwe: [CWE-22]
trigger_functions: [os.Open, os.Create, os.OpenFile, ioutil.ReadFile, ioutil.WriteFile, filepath.Join, filepath.Clean, os.ReadFile, os.WriteFile, archive/zip.NewReader]
---

# path_traversal 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `go.system.path-traversal` |
| signal_filter | `go.system.path-traversal*` |
| signal_source | `call_sites[category="*"]`（全量加载） |
| trigger_functions | `os.Open`, `os.Create`, `os.OpenFile`, `os.ReadFile`, `os.WriteFile`, `ioutil.ReadFile`, `filepath.Join`, `archive/zip.NewReader` |
| 默认严重度 | High |
| CWE | CWE-22 (Path Traversal) |
| Guard-rule | `system-path-traversal` |

## Scenario 1: 路径拼接未验证

### 威胁定义

Go 中使用 `filepath.Join(base, userPath)` 拼接路径时，用户输入中的 `../` 可突破基础目录。`filepath.Join` 仅做规范化，不做安全校验。Zip Slip 攻击通过恶意构造的 ZIP 条目名穿越目录。

**核心原则：路径操作中用户输入不得直接影响文件操作的目标路径。**

### 检测逻辑

```go
// 脆弱 — 直接拼接用户路径无校验
f, err := os.Open(filepath.Join("/var/data", userPath))

// 脆弱 — 用户输入中的 ..
f, err := os.Open(userInput)  // userInput = "../../etc/passwd"

// 脆弱 — Zip Slip
r, _ := zip.OpenReader("archive.zip")
for _, f := range r.File {
    target := filepath.Join("/dest", f.Name)
    // f.Name = "../../evil.sh"
    os.WriteFile(target, ...)
}

// 安全 — Clean + 前缀校验
cleanPath := filepath.Clean(filepath.Join(baseDir, userPath))
if !strings.HasPrefix(cleanPath, filepath.Clean(baseDir)) {
    return errors.New("path traversal detected")
}

// 安全 — 文件名校验
if strings.Contains(userInput, "..") {
    return errors.New("invalid path")
}

// 安全 — Zip Slip 预防
for _, f := range r.File {
    target := filepath.Join(destDir, f.Name)
    if !strings.HasPrefix(target, filepath.Clean(destDir)+string(os.PathSeparator)) {
        continue
    }
}
```

### 检测模式

```
# MATCH（触发检测）
→ os.Open/filepath.Join 参数来自 HTTP request / os.Args / user input
→ filepath.Join(base, userPath) 无 filepath.Clean + HasPrefix 校验
→ archive/zip 解压路径来自 zip 条目的 Name 字段
→ os.ReadFile/ioutil.ReadFile 参数直接来自用户

# EXCLUDE（不报告）
→ filepath.Clean + strings.HasPrefix 前缀校验
→ 白名单文件名映射（UUID/哈希映射）
→ 使用 filepath.Base 仅取文件名
→ 硬编码常量路径
```

### 修复指引

1. `filepath.Clean` + `strings.HasPrefix` 双重校验确保路径在基础目录内
2. Zip Slip: 对每个 entry 的 Name 做 `filepath.Clean` + 前缀校验
3. 使用 `filepath.Base` 只取文件名部分（去除任何目录组件）

---

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | 文件操作 API 调用点及路径构造上下文 |
| judgment_rationale | MUST | 用户输入是否经过 Clean + 前缀校验 |
| data_flow_path | SHOULD | 用户输入 → 路径拼接 → 文件操作的完整路径 |

## 输出格式

遵循 `$SECGUARDIAN_HOME/knowledge/protocols/scan-output.md` 定义的输出契约。
