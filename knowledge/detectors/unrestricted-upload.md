---
detector: unrestricted-upload
severity: critical
cwe: CWE-434
language: [java, python, go]
tags: [web, upload, filesystem]
---

# 无限制文件上传 (Unrestricted File Upload)

## 威胁定义

文件上传接口未限制文件类型（允许 `.jsp`/`.php`/`.exe`）、大小（可耗尽存储）或名称（路径穿越）。攻击者上传 Web Shell 后获得 RCE。OWASP Top 10 A03: Injection 相关。

**核心原则：上传文件必须验证 MIME 类型 + 扩展名白名单 + 内容魔术字节，存储路径由服务端生成（非用户提供），大小严格限制。**

## 检测逻辑

### Step 1: 搜索文件上传入口

```java
// Java: MultipartFile
@PostMapping("/upload")
public String handleUpload(@RequestParam("file") MultipartFile file) {
    // 检查点: 是否对 file 做了任何验证？
}

// Java Servlet
Part filePart = request.getPart("file");
```

```python
# Python: Flask request.files
file = request.files.get("file")
file.save("/uploads/" + file.filename)
```

```go
// Go: r.FormFile
file, header, err := r.FormFile("file")
```

### Step 2: 检查文件类型验证

```java
// BAD: 无类型验证
file.transferTo(new File("/uploads/" + file.getOriginalFilename()));

// GOOD: 白名单验证
String ct = file.getContentType();
if (!Arrays.asList("image/png", "image/jpeg", "image/gif").contains(ct)) {
    return "Invalid file type";
}
```

### Step 3: 检查路径遍历保护

```java
// BAD: 直接使用用户提供的文件名
String path = "/uploads/" + file.getOriginalFilename();
// ../../etc/cron.d/backdoor.sh 可写任意位置

// GOOD: 使用 UUID 重命名
String safeName = UUID.randomUUID().toString() + ".bin";
```

### Step 4: 检查大小限制和数量限制

```python
# BAD: 无大小限制
file.save(os.path.join(UPLOAD_DIR, filename))

# GOOD: 检查大小
if len(file.read()) > MAX_FILE_SIZE:
    return "File too large"
file.seek(0)  # 重置指针
```

## 修复指引

1. **MIME 类型**：验证 `Content-Type` + 文件内容魔术字节（前几个字节）
2. **扩展名白名单**：仅允许安全的扩展名（`.jpg`/`.png`/`.pdf`），禁止 `.jsp`/`.php`/`.exe`
3. **存储路径**：由服务端生成 UUID 文件名，存储路径在 Web 根目录外
4. **大小限制**：设置合理的上传大小上限（如 10MB）

## 误报排除

| 场景 | 原因 |
|------|------|
| 仅允许管理员上传 | 受信任用户 |
| 文件存储在对象存储（S3）且 key 不可预测 | 路径控制 |
| 上传后立即重命名为 UUID | 文件名安全 |
| 上传前对内容进行 MIME 检测 + 白名单 | 类型安全 |

## 检测模式汇总

```
# 文件上传 + 无验证
MultipartFile|request\.files|FormFile
→ save|transferTo|write
→ 无 if.*contentType|if.*ext|if.*size

# 用户文件名直接使用
getOriginalFilename|file\.filename|header\.Filename
→ save|write|open (同一变量)
→ 无 UUID|sanitize|basename 处理

# 体积过大
file\.save|file\.write
→ 无 file\.getSize|len\(file\) 检查
```

## CWE 映射

- CWE-434: Unrestricted Upload of File with Dangerous Type
- CWE-23: Relative Path Traversal
- CWE-400: Uncontrolled Resource Consumption
