---
detector: unrestricted-upload
severity: critical
cwe: CWE-434
language: [java, python, go]
tags: [web, upload, filesystem]
precision: high
confidence: dynamic
---

# 无限制文件上传 (Unrestricted File Upload)

## 威胁定义 (Threat Definition)

文件上传接口未限制文件类型（允许 `.jsp`/`.php`/`.exe`）、大小（可耗尽存储）或名称（路径穿越）。攻击者上传 Web Shell 后获得 RCE。OWASP Top 10 A03: Injection 相关。

**核心原则：上传文件必须验证 MIME 类型 + 扩展名白名单 + 内容魔术字节，存储路径由服务端生成（非用户提供），大小严格限制。**

## 检测逻辑 (Detection Logic)

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

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：文件上传端点的完整代码，包含 MultipartFile/request.files/FormFile 入口、文件保存路径构造逻辑、以及是否有 Content-Type/扩展名/大小的验证代码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析上传文件的完整处理链路——文件类型是否经过白名单验证（非黑名单）、存储路径是否由服务端生成（UUID/哈希）而非用户文件名、文件大小是否有硬上限、上传后文件是否在 Web 根目录外
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：上传文件从 HTTP multipart/form-data → Controller/Handler → 文件存储/对象存储的完整数据流，标注每一层是否有类型/大小/路径验证
      → findings.evidence.data_flow_path
- [ ] **call_stack**：Controller/Handler → 文件验证层 → 存储层的完整调用链，确认是否存在跳过验证的代码路径
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：用户提供的文件名（file.getOriginalFilename/file.filename）、服务端生成的存储路径、Content-Type 值、文件大小（字节数）、魔术字节校验结果
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否存在全局上传过滤器/拦截器、是否配置了 Web 服务器的脚本执行禁止（如 Nginx 对 upload 目录禁用 PHP 解析）
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **MIME 类型**：验证 `Content-Type` + 文件内容魔术字节（前几个字节）
2. **扩展名白名单**：仅允许安全的扩展名（`.jpg`/`.png`/`.pdf`），禁止 `.jsp`/`.php`/`.exe`
3. **存储路径**：由服务端生成 UUID 文件名，存储路径在 Web 根目录外
4. **大小限制**：设置合理的上传大小上限（如 10MB）

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 仅允许管理员上传 | 受信任用户 | 确认端点有管理员角色检查（@PreAuthorize/hasRole），且管理员账户受 MFA 保护 |
| 文件存储在对象存储（S3）且 key 不可预测 | 路径控制 | 确认上传使用预签名 URL，服务端生成随机 object key，非用户直接指定路径 |
| 上传后立即重命名为 UUID | 文件名安全 | 确认 rename/save 使用 UUID.randomUUID()/uuid.uuid4()，从未使用原始文件名 |
| 上传前对内容进行 MIME 检测 + 白名单 | 类型安全 | 确认检测了 Content-Type + 魔术字节（前 N 字节），且仅允许白名单中的类型 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 文件上传 + 无验证
MultipartFile|request\.files|FormFile
                                                       # → MUST: code_context (上传端点+保存逻辑)
→ save|transferTo|write
→ 无 if.*contentType|if.*ext|if.*size
                                                       # → MUST: judgment_rationale (类型/大小/路径验证分析)

# 用户文件名直接使用
getOriginalFilename|file\.filename|header\.Filename
→ save|write|open (同一变量)
→ 无 UUID|sanitize|basename 处理

# 体积过大
file\.save|file\.write
→ 无 file\.getSize|len\(file\) 检查

# === EXCLUDE (不报告) ===
→ Arrays\.asList.*contains.*contentType        # MIME 白名单验证存在
→ UUID\.randomUUID|uuid\.uuid4                 # UUID 重命名
→ if.*> MAX_FILE_SIZE|if.*> MAX_UPLOAD         # 大小限制检查
→ Files\.probeContentType|magic.*bytes          # 魔术字节检测
→ @PreAuthorize|@RolesAllowed                  # 管理员端点
→ \.startsWith\("\.\."\)|\.contains\("\.\."\)   # 路径穿越检查
```

## CWE 映射 (CWE Mapping)

- CWE-434: Unrestricted Upload of File with Dangerous Type
- CWE-23: Relative Path Traversal
- CWE-400: Uncontrolled Resource Consumption
