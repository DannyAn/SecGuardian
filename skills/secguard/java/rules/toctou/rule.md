---
name: secguard-java-toctou
description: "检测 Java TOCTOU 竞态条件 — 文件检查与使用非原子操作"
language: java
topic: [file_io, concurrency]
skill_id: java.toctou.race
signal_source: call_sites[cat="file_io"]
severity: medium
cwe: CWE-367
trigger_functions: [exists, isFile, isDirectory, delete, renameTo, createTempFile, canRead, canWrite]
---

# toctou 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE |
|----------|---------------|-------------------|----------|-----|
| `java.toctou.race` | `call_sites[cat="file_io"]` | `exists`, `isFile`, `delete`, `renameTo`, `createTempFile` | Medium | CWE-367 |

## Scenario 1: 文件存在检查与后续操作非原子

### 威胁定义
攻击者在文件检查（`file.exists()`）和实际使用之间替换文件（符号链接攻击），绕过安全检查。经典场景：先检查文件是否可读再打开、先检查临时目录再写入。

### 检测逻辑
```java
// BAD: TOCTOU — 先检查再使用
File file = new File("/tmp/userdata");
if (file.exists()) {                         // 检查
    FileInputStream fis = new FileInputStream(file);  // 使用 — 中间已被替换!
}

// BAD: 先检查可写再写入
File f = new File(userDir + "/report.txt");
if (f.exists() || f.createNewFile()) { ... }  // 非原子

// GOOD: 原子文件操作
Path path = Paths.get("/tmp/userdata");
Files.readAllBytes(path);  // 单次原子操作

// GOOD: NIO Files.createTempFile 原子创建
Path tempFile = Files.createTempFile("prefix", ".suffix");
```

### 检测模式
**MATCH**: `file.exists()` / `file.isFile()` / `file.canRead()` 在同一方法内后跟文件读/写操作（相隔 <= 5 行）；`File.createTempFile` / `File.renameTo` 非 NIO 替代

**EXCLUDE**: 使用 `Files.readAllBytes` / `Files.write` 等 NIO 原子操作；`Files.createTempFile` NIO 版本（原子创建）

### 修复指引
1. 使用 Java NIO `Files.*` API（`Files.readAllBytes`、`Files.write`）替代 File I/O
2. `Files.createTempFile` 替代 `File.createTempFile`
3. 避免先检查再使用模式，直接操作并处理异常

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | 文件检查与后续操作的连续代码 |
| judgment_rationale | MUST | 检查与使用之间是否存在竞态窗口 |
| data_flow_path | SHOULD | 文件路径的来源和用途路径 |

## 输出格式
`[Medium][CWE-367] {file}:{line} — TOCTOU 竞态条件`
