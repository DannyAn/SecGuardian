---
name: secguard-java-path-traversal
description: "检测 Java 路径穿越漏洞 — 文件路径未 canonicalize 直接使用用户输入"
language: java
topic: [web, file_io, injection]
skill_id: java.path-traversal.sanitize
signal_source: call_sites[cat="file_io"]
severity: high
cwe: CWE-22
trigger_functions: [Paths.get, new File, getCanonicalPath, getAbsolutePath, isFile, exists, createTempFile, ZipInputStream]
---

# path_traversal 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE |
|----------|---------------|-------------------|----------|-----|
| `java.path-traversal.sanitize` | `call_sites[cat="file_io"]` | `Paths.get`, `new File`, `getCanonicalPath`, `ZipInputStream` | High | CWE-22 |

## Scenario 1: 用户输入直接构造文件路径

### 威胁定义
攻击者通过 `../` 路径穿越读取系统任意文件（`/etc/passwd`）或访问受限目录。Spring 文件下载接口、ZipInputStream 解压（Zip Slip）、ResourceLoader 等均为常见攻击面。

### 检测逻辑
```java
// BAD: Paths.get 直接使用用户输入
Path path = Paths.get(request.getParameter("filename"));
byte[] data = Files.readAllBytes(path);

// BAD: new File 未验证
File file = new File("/app/files/" + request.getParameter("name"));
FileInputStream fis = new FileInputStream(file);

// BAD: Zip Slip — entry 名未验证
ZipInputStream zis = new ZipInputStream(inputStream);
ZipEntry entry = zis.getNextEntry();
Path outputPath = Paths.get("dest", entry.getName());  // entry name = "../../etc/cronjob"

// GOOD: canonical path 前缀验证
File file = new File("/app/files", userInput);
String canonical = file.getCanonicalPath();
if (!canonical.startsWith("/app/files/")) {
    throw new SecurityException("Path traversal detected");
}
```

### 检测模式
**MATCH**: `Paths.get(.*getParameter` / `Paths.get(.*user`；`new File(.*getParameter` / `new File(.*user`；`ZipInputStream.getNextEntry()` 无 `entry.getName()` 白名单验证

**EXCLUDE**: `getCanonicalPath()` 前缀验证；`Path.normalize()` + 白名单目录前缀检查；Zip entry 名通过 `isAllowed(entry.getName())` 白名单验证

### 修复指引
1. 使用 `File.getCanonicalPath()` 解析后白名单前缀验证
2. Zip Slip: 验证每个 `ZipEntry.getName()` 是否包含 `..`
3. 白名单允许的目录路径，禁止用户控制文件系统路径

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | 文件路径构造及读取的完整代码 |
| judgment_rationale | MUST | 路径是否经过 canonicalize 和前缀验证 |
| data_flow_path | SHOULD | 用户输入到文件 API 的完整路径 |
| sanitizer_analysis | SHOULD | 白名单 / canonicalize 验证存在性 |

## 输出格式
`[High][CWE-22] {file}:{line} — 路径穿越（{api}）`
