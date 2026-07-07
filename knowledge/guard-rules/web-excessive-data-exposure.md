---
detector: web-excessive-data-exposure
severity: high
cwe: CWE-200
cvss: 7.8
language: [java, python, go, js]
tags: [web, api, data-exposure, response]
precision: medium
confidence: dynamic
target_functions: [__dict__, account, assword, ccount, code_context, ecret, etMapping, find, findAll, findById, get, getEmail, getUser, getUsername, getUsers, get_user, json, jsonify, judgment_rationale, lean, model_to_dict, oken, orElseThrow, profile, query, res, ser, sonResponse, user]
match_patterns: [return\s+userRepository\.find, return\s+\w+Repository\.find(All|ById), class\s+(User|Account|Profile).*\{[^}]*\bpassword\b(?!.*@JsonIgnore), class\s+(User|Account|Profile).*\{[^}]*\btoken\b(?!.*@JsonIgnore), model_to_dict|__dict__|\.__dict__\s*, fields\s*=\s*['"]__all__['"], json\.NewEncoder.*Encode\(user|account|profile\), res\.json\(user\)|res\.json\(result\)|res\.send\(user\)]
exclude_patterns: []
---

## 威胁定义 (Threat Definition)

API 响应返回超出前端需要的敏感字段（密码哈希、内部 ID、权限列表等），依赖前端过滤而非后端裁剪。

## 检测逻辑 (Detection Logic)

### Step 1: Java — ORM 实体直接序列化

```java
// BAD: JPA Entity 直接返回
@GetMapping("/users/{id}")
public User getUser(@PathVariable Long id) {
    return userRepository.findById(id).orElseThrow();
    // 返回完整 User 实体: password, salt, internalNotes!
}

// BAD: 列表直接返回实体
@GetMapping("/users")
public List<User> getUsers() {
    return userRepository.findAll();  // 所有用户的 password 被返回!
}

// BAD: 序列化配置不当
// Entity 类中 password 字段无 @JsonIgnore
public class User {
    private String username;
    private String password;  // 会被序列化!
    @JsonIgnore  // 应有此注解
    private String internalNotes;
}
```

**Java 安全模式:**
```java
// GOOD: 专用 DTO
@GetMapping("/users/{id}")
public UserDTO getUser(@PathVariable Long id) {
    User user = userRepository.findById(id).orElseThrow();
    return new UserDTO(user.getUsername(), user.getEmail());  // 仅返回必要字段
}
```

### Step 2: Python — Model 直接序列化

```python
# BAD: Django Model 直接返回
def get_user(request, user_id):
    user = User.objects.get(id=user_id)
    return JsonResponse(model_to_dict(user))  # password field included!

# BAD: SQLAlchemy model 直接 JSON
def get_user(id):
    user = db.session.query(User).get(id)
    return jsonify(user.__dict__)  # password_hash 暴露!

# BAD: DRF Serializer 未设 fields
class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = '__all__'  # 所有字段暴露!
```

**Python 安全模式:**
```python
# GOOD: DRF 显式字段白名单
class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['username', 'email', 'date_joined']  # 显式列表
```

### Step 3: Go — Struct 直接 JSON

```go
// BAD: GORM model 直接 JSON 返回
func GetUser(w http.ResponseWriter, r *http.Request) {
    var user User
    db.First(&user, r.URL.Query().Get("id"))
    json.NewEncoder(w).Encode(user)  // PasswordHash 被返回!
}

type User struct {
    Username     string `json:"username"`
    PasswordHash string `json:"password_hash"`  // 会被序列化!
    InternalNote string `json:"internal_note"`  // 内部信息
}
```

**Go 安全模式:**
```go
// GOOD: Response struct 或 json:"-" tag
type User struct {
    Username     string `json:"username"`
    PasswordHash string `json:"-"`  // 不序列化
    InternalNote string `json:"-"`
}

// 或专用 Response struct
type UserResponse struct {
    Username string `json:"username"`
    Email    string `json:"email"`
}
```

### Step 4: JavaScript — Mongoose/ORM 直接返回

```javascript
// BAD: Mongoose document 直接返回
app.get('/users/:id', async (req, res) => {
    const user = await User.findById(req.params.id);
    res.json(user);  // passwordHash 被返回!
});

// BAD: Sequelize 查询所有字段
app.get('/users', async (req, res) => {
    const users = await User.findAll();  // 所有列返回!
    res.json(users);
});

// BAD: Mongoose lean 全量
const user = await User.findById(id).lean();
res.json(user);  // password 字段在响应中
```

**JavaScript 安全模式:**
```javascript
// GOOD: 字段选择
const user = await User.findById(id).select('-passwordHash -internalNotes');
res.json(user);

// GOOD: 显式投影
const user = await User.findById(id, 'username email createdAt');
res.json(user);
```

## 修复指引 (Remediation Guide)

1. **首选**：创建专用 Response DTO/Serializer，显式列出返回字段
2. **次选**：实体字段使用排除注解（`@JsonIgnore` / `json:"-"` / `exclude`）
3. **禁止**：直接将数据库实体返回给客户端
4. Mongoose `.select('-password -token')` / Sequelize `attributes` 显式投影

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| Jackson `@JsonIgnore`/`@JsonProperty(access=READ_ONLY)` | 已排除 | 确认敏感字段上有 @JsonIgnore 或 READ_ONLY 注解 |
| GORM `json:"-"` tag | 已排除序列化 | 确认敏感字段上有 `json:"-"` tag |
| DRF `fields = ['username', 'email']` 显式列表 | 白名单 | 确认 Serializer Meta.fields 为显式字段列表（非 __all__） |
| Mongoose `.select('-password')` / `.select('username email')` | 显式选择 | 确认 .select() 调用排除或限定敏感字段 |
| 管理后台/内部 API（有权限校验） | 内部使用 | 确认端点有管理角色检查（@PreAuthorize/hasRole） |
| OAuth token 响应（标准协议） | 协议要求 | 确认为标准 OAuth/OIDC 协议端点 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# Java: Entity 直接返回
return\s+userRepository\.find
return\s+\w+Repository\.find(All|ById)
→ @(GetMapping|PostMapping) 控制器方法返回 User/Account Entity
                                                       # → MUST: code_context (控制器方法+返回类型)

# Java: 缺少 @JsonIgnore
class\s+(User|Account|Profile).*\{[^}]*\bpassword\b(?!.*@JsonIgnore)
class\s+(User|Account|Profile).*\{[^}]*\btoken\b(?!.*@JsonIgnore)

# Python: model_to_dict / __dict__ 序列化
model_to_dict|__dict__|\.__dict__\s*
→ JsonResponse|jsonify|Response

# Python: DRF fields = '__all__'
fields\s*=\s*['"]__all__['"]

# Go: Encode 含敏感字段的 struct
json\.NewEncoder.*Encode\(user|account|profile\)
→ struct 含 Password|Secret|Token|Hash 字段且无 json:"-"

# JS: res.json() 直接返回 Mongoose/ORM 对象
res\.json\(user\)|res\.json\(result\)|res\.send\(user\)
→ User\.find(ById)? → 无 .select 投影
                                                       # → MUST: judgment_rationale (响应字段分析)

# === EXCLUDE (不报告) ===
→ @JsonIgnore|@JsonProperty.*READ_ONLY                # Jackson 排除注解
→ json:"-"|yaml:"-"                                     # Go struct 排除 tag
→ \.select\(['"]-|\.select\([^)]*-                      # Mongoose negative select
→ fields\s*=\s*\[                                      # DRF 显式字段白名单
→ @PreAuthorize|hasRole|hasAuthority                   # 管理后台权限保护
→ UserDTO|UserResponse|UserVO|UserView                 # 专用 DTO 返回类型
```
