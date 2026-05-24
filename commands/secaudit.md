# /secaudit - 安全专项审计

针对安全专项问题进行深度审计分析。自动识别用户意图，路由到对应的分析或领域审计 skill。

## 使用方式

```
## ★ 旗舰产品

SecAudit 是 SecGuardian 的旗舰产品——AI 深度安全审计。它替代传统安全顾问执行 17 项专业安全分析，每项分析需要资深工程师 4-8 小时。AI 在数秒内完成同等深度的审计，帮助企业年省 $50K+ 安全审计费用。

## 使用方式

```
/secaudit                                    # 列出所有 17 个 skills
/secaudit taint-analysis                     # 污点分析 — 追踪不可信数据到危险操作
/secaudit auth-and-session                   # 认证与会话管理审计
/secaudit cryptography                       # 密码学完整审计
/secaudit input-validation                   # 输入验证深度审计
/secaudit attack-surface-analysis            # 攻击面枚举
/secaudit analysis                           # 列出 5 个分析方法类 skills
/secaudit domain                             # 列出 12 个安全领域类 skills
/secaudit <skill-name> [path]                # 指定审计代码路径
/secaudit <skill-name> [path] --sarif        # 输出 SARIF 格式（CI/CD 集成）
```

## 输出

审计结果写入 `.codeagent/secaudit-secguardian/scans/<scan-id>/`：

```
.codeagent/secaudit-secguardian/scans/2026-05-23T14-30-00-b3c4/
├── manifest.json            # 审计摘要 + 发现索引
└── findings/
    ├── C-001.json            # Critical 发现
    ├── H-001.json            # High 发现
    └── ...
```

### 输出协议

遵循 [Scan Output Protocol 1.0](../../knowledge/protocols/scan-output.md)。

**执行完毕后必须输出审计摘要：**

```
## secaudit 审计完成 — taint-analysis

Scan ID: 2026-05-23T14-30-00-b3c4
Skill: secaudit-taint-analysis

### 结果
- 分析路径: 15 (Source → Propagation → Sink)
- 完整链路: 15 analyzed
- 检出: 4 (Critical: 2, High: 2)

### 发现
| ID | Severity | Path | File |
|----|----------|------|------|
| C-001 | Critical | HTTP param → SQL exec | src/handler.py:42 |
| C-002 | Critical | File upload → os.system | src/upload.py:108 |
| H-001 | High | Cookie → response.write | src/middleware.js:56 |

输出目录: .codeagent/secaudit-secguardian/scans/2026-05-23T14-30-00-b3c4/
```

## 可用 Skills

### analysis - 安全分析方法 (5 个)
| Skill | 描述 |
|-------|------|
| attack-surface-analysis | 分析攻击面，识别暴露入口点和接口 |
| data-flow-analysis | 追踪数据从 Source 到 Sink 的完整数据流 |
| state-machine-analysis | 分析状态转换，检测非法跃迁路径 |
| taint-analysis | 标记污点数据源，追踪传播链 |
| trust-boundary-analysis | 识别信任边界，检查跨边界控制 |

### domain - 安全领域审计 (12 个)
| Skill | 描述 |
|-------|------|
| auth-and-session | 认证机制和会话生命周期审计 |
| authorization | 权限模型审计，检测越权 |
| cryptography | 加密实现审计，检测弱算法 |
| data-protection | 敏感数据存储/传输/处理保护 |
| dependency-security | 依赖的已知漏洞和供应链审计 |
| http-security-headers | HTTP 安全头配置审计 |
| infra-hardening | 容器/K8s/云资源加固审计 |
| input-validation | 输入验证和注入漏洞审计 |
| logging-and-monitoring | 日志完整性和安全监控审计 |
| output-encoding | 输出编码和 XSS 防护审计 |
| secrets-management | 密钥/凭证管理方式审计 |
| secure-transport | TLS 配置和传输层安全审计 |

## 派发规则

1. 精确匹配 → `skills/secaudit-{skill-name}/SKILL.md`
2. analysis/domain → 列出对应分类的 skills
3. 按协议 1.0 写入输出目录
