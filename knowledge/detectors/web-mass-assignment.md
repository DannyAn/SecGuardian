---
detector: web-mass-assignment
severity: critical
cwe: CWE-915
language: [java, python, go, js]
tags: [web, api, binding, mass-assignment]
precision: high
confidence: dynamic
---

# 批量分配 (Mass Assignment)

## 威胁定义 (Threat Definition)

检测 API 端点是否自动将客户端请求的字段绑定到内部数据模型，允许攻击者修改不应访问的属性（如 `role=admin`、`isAdmin=true`）。

## 检测逻辑 (Detection Logic)

### Step 1: Java Spring — 自动绑定

```java
// BAD: @ModelAttribute 无白名单
@PostMapping("/users")
public User updateUser(@ModelAttribute User user) {  // 自动绑定所有字段!
    return userRepository.save(user);
}
// 攻击者发送: {"username":"user","role":"ADMIN"} → role 被修改!

// BAD: @RequestBody 绑定到实体
@PostMapping("/users")
public User createUser(@RequestBody User user) {  // User 实体可能含 isAdmin 字段
    return userRepository.save(user);
}

// BAD: BeanUtils.copyProperties 批量复制
BeanUtils.copyProperties(source, targetUser);  // source 来自 request!
```

**Java 安全模式:**
```java
// GOOD: 专用 DTO
@PostMapping("/users")
public UserDTO createUser(@RequestBody @Valid CreateUserRequest request) {
    User user = new User();
    user.setUsername(request.getUsername());  // 仅复制允许的字段
    return userRepository.save(user);
}

// GOOD: @InitBinder 白名单
@InitBinder
public void initBinder(WebDataBinder binder) {
    binder.setAllowedFields("username", "email");  // 白名单
}
```

### Step 2: Python 框架 — 自动绑定

```python
# BAD: Django 直接解包
def update_user(request):
    user = User.objects.get(id=request.POST['id'])
    for key, value in request.POST.items():  # 遍历所有字段!
        setattr(user, key, value)
    user.save()

# BAD: Flask 直接 form 绑定
@app.route('/users/<int:id>', methods=['POST'])
def update_user(id):
    user = User.query.get(id)
    user.__dict__.update(request.form)  # 直接更新所有字段!
    db.session.commit()

# BAD: FastAPI Pydantic model 包含敏感字段
class UserUpdate(BaseModel):
    username: str
    role: str = "user"  # role 字段可被覆盖!
    is_admin: bool = False
```

**Python 安全模式:**
```python
# GOOD: FastAPI 专用 Schema
class UserUpdateRequest(BaseModel):
    username: str  # 仅暴露可修改字段
    email: str

@app.post("/users/{id}")
def update_user(id: int, req: UserUpdateRequest):
    user = db.get(User, id)
    user.username = req.username
    user.email = req.email  # role/is_admin 不可通过 API 修改
```

### Step 3: Go 框架 — 自动绑定

```go
// BAD: Gin BindJSON 绑定到含 Role 的 struct
type User struct {
    Username string `json:"username"`
    Role     string `json:"role"`     // 可被用户覆盖!
    IsAdmin  bool   `json:"is_admin"` // 极度危险!
}

func UpdateUser(c *gin.Context) {
    var user User
    c.BindJSON(&user)  // 所有 JSON 字段自动绑定
    db.Save(&user)
}

// BAD: Echo Bind
type UpdateRequest struct {
    ID   uint   `param:"id"`
    User *User  `json:"user"`  // 嵌套绑定，IsAdmin 可被设置
}
c.Bind(&req)
```

**Go 安全模式:**
```go
// GOOD: 专用 Request struct
type UpdateUserRequest struct {
    Username string `json:"username" binding:"required"`
    Email    string `json:"email" binding:"required,email"`
}
var req UpdateUserRequest
c.BindJSON(&req)
// 数据库更新时仅更新允许的字段
db.Model(&user).Updates(map[string]interface{}{
    "username": req.Username,
    "email":    req.Email,
})
```

### Step 4: JavaScript/Node.js — 自动绑定

```javascript
// BAD: Express/Mongoose 批量创建
app.post('/users', async (req, res) => {
    const user = new User(req.body);  // 所有字段!
    await user.save();
});

// BAD: Sequelize 批量更新
await User.update(req.body, { where: { id: req.params.id } });

// BAD: Mongoose findOneAndUpdate 直接使用 body
await User.findOneAndUpdate({ _id: req.params.id }, req.body);
```

**JavaScript 安全模式:**
```javascript
// GOOD: 白名单字段提取
app.post('/users', async (req, res) => {
    const { username, email } = req.body;
    const user = new User({ username, email });  // 仅白名单字段
    await user.save();
});
```

## 修复指引 (Remediation Guide)

1. **首选**：创建专门的 Request DTO，只包含允许用户修改的字段
2. **次选**：使用字段白名单显式声明允许绑定的字段（`@InitBinder.setAllowedFields` / DRF `fields` 列表）
3. **禁止**：直接将 `request.body`/`request.form` 绑定到数据库实体
4. Mongoose Schema 使用 `immutable: true` 标记敏感字段

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 使用专用 DTO/Request Schema 隔离 | 已分层保护 | 确认存在专用 Request DTO/Schema 且字段不含权限属性 |
| `@InitBinder.setAllowedFields` 显式白名单 | 白名单控制 | 确认 setAllowedFields 列表仅含安全字段 |
| Pydantic `model_validate` 使用 Request schema | 字段受限 | 确认 Pydantic model 字段定义不含 role/is_admin 等敏感字段 |
| GORM `Updates(map)` 显式列名字段白名单 | 白名单 | 确认 map 中仅包含用户可修改的字段名 |
| 管理后台 API（有 RBAC 保护） | 权限受控 | 确认端点有管理角色检查且审计日志完整 |
| Mongoose Schema `immutable: true` 标记敏感字段 | 字段级保护 | 确认敏感字段 Schema 定义含 immutable: true |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# Java: 实体直接绑定
(@ModelAttribute|@RequestBody)\s+\w+(User|Account|Profile)\s  # 实体类名
BeanUtils\.copyProperties.*request|body|input
                                                       # → MUST: code_context (Controller方法+绑定实体)

# Python: 批量 setattr
setattr\(.*for.*request\.(POST|form|body)
__dict__\.update\(request\.(form|body|POST)
\.save\(\) → for k, v in request → setattr 模式

# Go: BindJSON 到含权限字段的 struct
c\.(BindJSON|Bind|ShouldBindJSON)\(&(user|account|profile)\)
→ struct 含 Role|IsAdmin|Permissions|Group

# JS/Node: 直接 body 绑定
new\s+(User|Account)\(req\.body\)
(User|Account)\.(findOneAndUpdate|update)\([^,]*,\s*req\.body
(User|Account)\.update\(req\.body
                                                       # → MUST: judgment_rationale (绑定字段vs允许字段分析)

# === EXCLUDE (不报告) ===
→ @InitBinder|setAllowedFields                         # Spring 白名单控制
→ @Valid.*Request|CreateRequest|UpdateRequest          # 专用 Request DTO
→ UserUpdateRequest|UserCreateRequest|UpdateUserRequest # Pydantic 请求 Schema
→ \.Updates\(map\[string\]interface\{                  # GORM map 白名单
→ immutable:\s*true                                     # Mongoose immutable 保护
→ @PreAuthorize|hasRole|isAdmin|is_staff               # 管理后台权限保护
→ const\s*\{.*\}\s*=\s*req\.body                       # JS 解构白名单
```
