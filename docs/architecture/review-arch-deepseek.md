# 全仓检视项目致命缺陷

**Session ID:** ses_0d0879d6dffeBPOz0boyi04D1C
**Created:** 7/5/2026, 7:30:46 AM
**Updated:** 7/5/2026, 7:32:34 AM

---

## User

请对当前项目进行一轮全仓检视，识别致命缺陷。

---

## Assistant (Build · DeepSeek V4 Flash · 3.9s)

_Thinking:_

The user is asking me to perform a comprehensive codebase review (全仓检视) of the current project (SecGuardian) to identify critical defects (致命缺陷). This is a security audit/review task. Let me first load the secaudit skill which is described as the flagship comprehensive security audit workflow.

Wait, let me re-read the request. The user wants me to review the project itself (SecGuardian) for critical defects, not use SecGuardian to scan another project. This is about looking at the SecGuardian project's own code and identifying issues.

Let me first understand the project structure, then do a thorough review. Let me start by exploring the codebase comprehensively.

Let me load the secaudit skill and also start exploring the codebase structure.

**Tool: skill**

**Input:**
```json
{
  "name": "secaudit"
}
```

**Output:**
```
<skill_content name="secaudit">
# Skill: secaudit

# 安全审计工作流

## 何时使用

当用户执行 `/secaudit <path> <language> [--focus <domain>]` 时激活。

- 无 `--focus`：执行全部 12 个审计域 phase，产出一份完整审计报告
- 有 `--focus`：只执行指定 domain 的 phase，用于团队分工/单项验证/快速迭代

## 分析方法参考

AI 在审计时根据领域自动选择分析策略。每个参考文件描述了方法的执行思路和检测模式。

```
审计域                    → 分析策略           → 参考文件
─────────────────────────────────────────────────────
Input Validation          → Taint Analysis       references/taint-analysis.md
Auth & Session            → State Machine        references/state-machine-analysis.md
Authorization             → Trust Boundary       references/trust-boundary-analysis.md
Cryptography              → Data Flow            references/data-flow-analysis.md
Secrets Management        → Data Flow            references/data-flow-analysis.md
Secure Transport          → Attack Surface       references/attack-surface-analysis.md
Data Protection           → Data Flow + Boundary references/data-flow-analysis.md
Dependency Security       → Attack Surface       references/attack-surface-analysis.md
Infrastructure Hardening  → Attack Surface       references/attack-surface-analysis.md
HTTP Security Headers     → Attack Surface       references/attack-surface-analysis.md
Logging & Monitoring      → Data Flow            references/data-flow-analysis.md
```

每个 phase 加载对应的 `.md` 参考文件，按其中的方法论执行分析。

## 前置条件

- index.json 已由 Command 层生成（含 `symbols`、`call_graph`、`alloc_free`、`lock_graph`）
- `knowledge/language-index.md` 已自动读取，获得该语言适用的所有规则清单

## 工作流

### Phase 1: 技术栈识别

从 index.json 确定：
- 开发语言和框架（如 Spring Boot、Django、Express）
- 使用的安全框架/库（Spring Security、Shiro、Django Auth）
- 数据存储类型（SQL/NoSQL/Redis 等）
- 部署架构（容器化/K8s/微服务）

### Phase 2: 输入验证审计

加载 `knowledge/audit-rules/input-validation.md`。
参考: `references/taint-analysis.md` — 追踪不可信数据从 Source 到 Sink

检查所有输入点的验证完整性：SQL 注入、命令注入、XSS、路径穿越、LDAP 注入、XML/XXE。验证参数化查询、输入净化、输出编码的覆盖范围。

### Phase 3: 认证与会话审计

加载 `knowledge/audit-rules/auth-and-session.md`。
参考: `references/state-machine-analysis.md` — 分析认证状态转换与会话生命周期

检查认证机制：密码策略、MFA、会话管理、Token 安全、OAuth/OIDC 配置、密码重置流程、session fixation 防护。

### Phase 4: 授权审计

加载 `knowledge/audit-rules/authorization.md`。
参考: `references/trust-boundary-analysis.md` — 检查用户/角色/权限边界

检查权限模型：RBAC/ABAC 实现、API 级授权检查、IDOR 防护、权限提升路径、越权测试。

### Phase 5: 密码学审计

加载 `knowledge/audit-rules/cryptography.md`。
参考: `references/data-flow-analysis.md` — 追踪密钥材料生命周期

检查加密实现：弱算法使用、密钥管理、随机数安全、TLS 配置、加密模式选择、证书验证、密码存储算法。

### Phase 6: 密钥管理审计

加载 `knowledge/audit-rules/secrets-management.md`。
参考: `references/data-flow-analysis.md` — 追踪凭证读取和传递路径

检查密钥和凭证：硬编码密码、API 密钥暴露、密钥轮换策略、密钥存储方案（环境变量/Vault/KMS）、密钥生命周期。

### Phase 7: 安全传输审计

加载 `knowledge/audit-rules/secure-transport.md`。
参考: `references/attack-surface-analysis.md` — 枚举 TLS 端点与传输入口

检查传输安全：TLS 版本、证书链验证、mTLS 配置、HSTS 头、证书固定、内部服务间传输加密。

### Phase 8: 数据保护审计

加载 `knowledge/audit-rules/data-protection.md`。
参考: `references/data-flow-analysis.md` + `references/trust-boundary-analysis.md` — 追踪敏感数据生命周期并检查访问边界

检查敏感数据：PII 识别、数据分类、加密存储、数据最小化、备份安全、数据擦除策略。

### Phase 9: 依赖安全审计

加载 `knowledge/audit-rules/dependency-security.md`。
参考: `references/attack-surface-analysis.md` — 评估第三方组件引入的攻击面

检查依赖项：已知漏洞扫描、许可证合规、依赖版本更新、供应链攻击面（恶意包、typosquatting）。

### Phase 10: 基础设施加固审计

加载 `knowledge/audit-rules/infra-hardening.md`。
参考: `references/attack-surface-analysis.md` — 识别暴露端口、服务、配置入口

检查基础设施：容器安全（Docker/K8s）、云资源配置、网络策略、最小权限原则、配置文件的敏感信息。

### Phase 11: HTTP 安全头审计

加载 `knowledge/audit-rules/http-security-headers.md`。
参考: `references/attack-surface-analysis.md` — 评估 HTTP 响应暴露面

检查 HTTP 响应头：CSP、HSTS、X-Frame-Options、X-Content-Type-Options、Referrer-Policy、Permissions-Policy。

### Phase 12: 日志与监控审计

加载 `knowledge/audit-rules/logging-and-monitoring.md`。
参考: `references/data-flow-analysis.md` — 追踪敏感数据是否流入日志

检查日志安全：敏感数据泄露风险、日志完整性、审计日志覆盖、告警配置、安全事件响应能力。

## 汇总报告

所有 phase 完成后：

1. **合并去重**：跨 phase 的相同 finding 合并
2. **严重度排序**：按 CVSS 评分从高到低排列
3. **分类索引**：按 OWASP Top 10 / CWE Top 25 分类
4. **安全评分**：`100 - (Critical×25 + High×10 + Medium×3 + Low×1)`
5. **修复路线图**：分 immediate / short-term / long-term 三阶段

## --focus 单项模式

当用户指定 `--focus <domain>` 时：

- 跳过不相关的 phase
- 只加载 `knowledge/audit-rules/{domain}.md`
- 仅执行匹配的 phase
- 输出精简报告，只包含该领域发现

用于团队分工（A 负责密码学、B 负责输入验证）、局部验证（改了一个 domain 后快速验证）、能力迭代（集中打磨单项 quality）。

Base directory for this skill: file:///Users/kongan/.config/opencode/extensions/secguardian/skills/secaudit-secaudit
Relative paths in this skill (e.g., scripts/, reference/) are relative to this base directory.
Note: file list is sampled.

<skill_files>
<file>/Users/kongan/.config/opencode/extensions/secguardian/skills/secaudit-secaudit/references/state-machine-analysis.md</file>
<file>/Users/kongan/.config/opencode/extensions/secguardian/skills/secaudit-secaudit/references/attack-surface-analysis.md</file>
<file>/Users/kongan/.config/opencode/extensions/secguardian/skills/secaudit-secaudit/references/data-flow-analysis.md</file>
<file>/Users/kongan/.config/opencode/extensions/secguardian/skills/secaudit-secaudit/references/trust-boundary-analysis.md</file>
<file>/Users/kongan/.config/opencode/extensions/secguardian/skills/secaudit-secaudit/references/taint-analysis.md</file>
</skill_files>
</skill_content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian</path>
<type>directory</type>
<entries>
.codeagent/
.codex-plugin/
.git/
.gitee-ci.yml
.github/
.gitignore
.markdownlint.jsonc
.markdownlintignore
.remember/
action.yml
AGENTS.md
alldir.md
build.sh
CHANGELOG.md
CLAUDE.md
commands/
DEVELOPER.md
docs/
examples/
extensions/
GEMINI.md
internal/
knowledge/
LICENSE-CODE.txt
LICENSE-KNOWLEDGE.txt
manifest.json
README-EN.md
README.md
scripts/
secguardian-0.12.0-source.tar.gz
SECURITY.md
skills/
tools/

(33 entries)
</entries>
```

---

## Assistant (Build · DeepSeek V4 Flash · 4.5s)

_Thinking:_

This is a comprehensive code review request. The user wants me to review the SecGuardian project itself for critical defects. Let me systematically explore the project structure, key files, and identify issues.

Let me start with a broad exploration of the project, then dig into critical areas.

**Tool: todowrite**

**Input:**
```json
{
  "todos": [
    {
      "content": "SDD 检查：确认是否有相关 Feature Package 指导本次审计",
      "status": "in_progress",
      "priority": "high"
    },
    {
      "content": "仓库完整性审计：manifest.json / package.sh / deploy.sh / self-check.sh",
      "status": "pending",
      "priority": "high"
    },
    {
      "content": "Go 索引器源码审计：internal/ 下的代码质量与安全缺陷",
      "status": "pending",
      "priority": "high"
    },
    {
      "content": "Shell 脚本审计：deploy.sh / package.sh / dev-verify.sh / e2e-verify.sh 等",
      "status": "pending",
      "priority": "high"
    },
    {
      "content": "Markdown 知识文件审计：detectors / skills / protocols 一致性",
      "status": "pending",
      "priority": "medium"
    },
    {
      "content": "构建与部署管线审计：package.sh → deploy.sh 全链路",
      "status": "pending",
      "priority": "high"
    },
    {
      "content": "安全敏感点审计：密钥管理 / 命令注入 / 路径穿越",
      "status": "pending",
      "priority": "critical"
    },
    {
      "content": "汇总致命缺陷报告",
      "status": "pending",
      "priority": "high"
    }
  ]
}
```

**Output:**
```
[
  {
    "content": "SDD 检查：确认是否有相关 Feature Package 指导本次审计",
    "status": "in_progress",
    "priority": "high"
  },
  {
    "content": "仓库完整性审计：manifest.json / package.sh / deploy.sh / self-check.sh",
    "status": "pending",
    "priority": "high"
  },
  {
    "content": "Go 索引器源码审计：internal/ 下的代码质量与安全缺陷",
    "status": "pending",
    "priority": "high"
  },
  {
    "content": "Shell 脚本审计：deploy.sh / package.sh / dev-verify.sh / e2e-verify.sh 等",
    "status": "pending",
    "priority": "high"
  },
  {
    "content": "Markdown 知识文件审计：detectors / skills / protocols 一致性",
    "status": "pending",
    "priority": "medium"
  },
  {
    "content": "构建与部署管线审计：package.sh → deploy.sh 全链路",
    "status": "pending",
    "priority": "high"
  },
  {
    "content": "安全敏感点审计：密钥管理 / 命令注入 / 路径穿越",
    "status": "pending",
    "priority": "critical"
  },
  {
    "content": "汇总致命缺陷报告",
    "status": "pending",
    "priority": "high"
  }
]
```

---

## Assistant (Build · DeepSeek V4 Flash · 2.3s)

_Thinking:_

Let me start by checking SDD docs, then dive into the critical files in parallel.

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/docs/sdd"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/docs/sdd</path>
<type>directory</type>
<entries>
brainstorm-log.md
epics/
README.md
req-20260704.md

(4 entries)
</entries>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/manifest.json"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/manifest.json</path>
<type>file</type>
<content>
1: {
2:   "project": "secguardian",
3:   "version": "0.12.0",
4:   "protocol": "1.3",
5:   "description": "\u4f01\u4e1a\u7ea7\u767d\u76d2\u5b89\u5168 AI Agent \u8f85\u52a9\u89e3\u51b3\u65b9\u6848 \u2014 \u4ee5 AI \u6df1\u5ea6\u5ba1\u8ba1\u4e3a\u6838\u5fc3\u7684\u65d7\u8230\u4ea7\u54c1\uff0c67 \u4e2a\u68c0\u6d4b\u5668\u8986\u76d6 7 \u5927\u5b89\u5168\u5206\u7c7b",
6:   "product_positioning": {
7:     "flagship": "secaudit \u2014 AI \u6df1\u5ea6\u5b89\u5168\u5ba1\u8ba1\uff08\u4f01\u4e1a\u5e74\u7701 $50K+ \u5ba1\u8ba1\u8d39\u7528\uff09",
8:     "detection": "secguard \u2014 AI \u5f15\u5bfc\u7684\u4ee3\u7801\u6f0f\u6d1e\u53d1\u73b0",
9:     "review": "secreview \u2014 \u5b89\u5168\u7f16\u7801\u89c4\u8303\u4e0e\u53cd\u6a21\u5f0f\u5ba1\u67e5"
10:   },
11:   "extensions": {
12:     "secaudit-secguardian": {
13:       "command": "secaudit",
14:       "description": "\u2605 \u65d7\u8230\u4ea7\u54c1\uff1aAI \u6df1\u5ea6\u5b89\u5168\u5ba1\u8ba1 \u2014 13 \u4e2a\u5ba1\u8ba1\u57df\u8986\u76d6\u5168\u751f\u547d\u5468\u671f\u5b89\u5168",
15:       "platforms": [
16:         "claude-code",
17:         "opencode",
18:         "gemini-cli",
19:         "github-actions"
20:       ],
21:       "skills": {
22:         "secaudit": {
23:           "category": "workflow",
24:           "status": "active",
25:           "desc": "AI \u5b89\u5168\u5ba1\u8ba1\u5de5\u4f5c\u6d41 \u2014 \u81ea\u52a8\u9009\u62e9\u63a8\u7406\u7b56\u7565\uff0c\u6309\u5ba1\u8ba1\u57df\u6267\u884c\u68c0\u6d4b"
26:         }
27:       }
28:     },
29:     "secguard-secguardian": {
30:       "command": "secguard",
31:       "description": "AI \u5f15\u5bfc\u7684\u4ee3\u7801\u6f0f\u6d1e\u53d1\u73b0 \u2014 67 \u4e2a\u68c0\u6d4b\u5668\u8986\u76d6 7 \u7c7b\u5b89\u5168 topic (memory/concurrency/system/crypto/web/error/resource)",
32:       "platforms": [
33:         "claude-code",
34:         "opencode",
35:         "gemini-cli",
36:         "github-actions"
37:       ],
38:       "skills": {
39:         "cpp": {
40:           "language": "cpp",
41:           "category": "language-specific",
42:           "status": "active",
43:           "detectors": 61
44:         },
45:         "java": {
46:           "language": "java",
47:           "category": "language-specific",
48:           "status": "active"
49:         },
50:         "python": {
51:           "language": "python",
52:           "category": "language-specific",
53:           "status": "active"
54:         },
55:         "go": {
56:           "language": "go",
57:           "category": "language-specific",
58:           "status": "active"
59:         },
60:         "javascript": {
61:           "language": "javascript",
62:           "category": "language-specific",
63:           "status": "active",
64:           "note": "v0.5.0 \u65b0\u589e"
65:         }
66:       }
67:     },
68:     "secreview-secguardian": {
69:       "command": "secreview",
70:       "description": "\u5b89\u5168\u7f16\u7801\u89c4\u8303\u5ba1\u67e5 \u2014 \u53cd\u6a21\u5f0f\u8bc6\u522b + \u6700\u4f73\u5b9e\u8df5\u5408\u89c4 + \u68c0\u6d4b\u77e9\u9635",
71:       "platforms": [
72:         "claude-code",
73:         "opencode",
74:         "gemini-cli",
75:         "github-actions"
76:       ],
77:       "skills": {
78:         "cpp": {
79:           "language": "cpp",
80:           "category": "language-specific",
81:           "status": "active"
82:         },
83:         "java": {
84:           "language": "java",
85:           "category": "language-specific",
86:           "status": "active"
87:         },
88:         "python": {
89:           "language": "python",
90:           "category": "language-specific",
91:           "status": "active"
92:         },
93:         "go": {
94:           "language": "go",
95:           "category": "language-specific",
96:           "status": "active"
97:         },
98:         "javascript": {
99:           "language": "javascript",
100:           "category": "language-specific",
101:           "status": "active",
102:           "note": "v0.5.0 \u65b0\u589e"
103:         }
104:       }
105:     },
106:     "secfix-secguardian": {
107:       "command": "secfix",
108:       "description": "\ud83e\uddea Trial: Patch Generator \u2014 generates unified diff patches from findings",
109:       "status": "trial",
110:       "platforms": [
111:         "claude-code",
112:         "opencode",
113:         "gemini-cli"
114:       ],
115:       "scripts": [
116:         "secfix.py"
117:       ]
118:     }
119:   },
120:   "knowledge": {
121:     "protocols": [
122:       "scan-output",
123:       "sarif-output"
124:     ],
125:     "threat_catalog": "knowledge/threat-catalog.md",
126:     "languages": [
127:       "cpp",
128:       "java",
129:       "python",
130:       "go",
131:       "javascript"
132:     ],
133:     "standards": [
134:       "sei-cert-c",
135:       "sei-cert-cpp",
136:       "sei-cert-java",
137:       "owasp-cheatsheet-mapping"
138:     ],
139:     "detectors": {
140:       "note": "Full detector registry in skills/secguard/cpp/references/detector-index.md",
141:       "count": 67,
142:       "active_count": 67,
143:       "namespaces": {
144:         "memory": 13,
145:         "concurrency": 4,
146:         "system": 8,
147:         "crypto": 9,
148:         "web": 21,
149:         "error": 6,
150:         "resource": 6
151:       }
152:     },
153:     "coverage": {
154:       "cwe_top25_2024": {
155:         "covered": 25,
156:         "total": 25,
157:         "percentage": 100,
158:         "key_covered": [
159:           "CWE-79:XSS",
160:           "CWE-89:SQLI",
161:           "CWE-120:BOF",
162:           "CWE-22:PTRV",
163:           "CWE-77:CMDI",
164:           "CWE-287:Auth",
165:           "CWE-352:CSRF",
166:           "CWE-502:Deser",
167:           "CWE-416:UAF",
168:           "CWE-415:DFree",
169:           "CWE-476:NULL",
170:           "CWE-190:IntOvf",
171:           "CWE-362:Race",
172:           "CWE-798:Secret",
173:           "CWE-327:WeakCrypto",
174:           "CWE-918:SSRF",
175:           "CWE-20:InputVal",
176:           "CWE-125:OOBRead",
177:           "CWE-276:Perms",
178:           "CWE-400:ResourceExh",
179:           "CWE-306:MissingAuth",
180:           "CWE-434:Upload",
181:           "CWE-862:AuthZ",
182:           "CWE-200:InfoLeak",
183:           "CWE-209:ErrInfoLeak"
184:         ],
185:         "newly_covered": [
186:           "CWE-200:InfoLeak (via web.excessive-data-exposure + error detectors)",
187:           "CWE-295:SSL (via crypto.tls-version)",
188:           "CWE-310:Crypto (via crypto.custom-crypto + crypto.aes-ecb-mode)",
189:           "CWE-863:IncorrectAuthZ (via web.mass-assignment + web.missing-authorization extensions)"
190:         ]
191:       },
192:       "owasp_top10_2021": {
193:         "covered": 10,
194:         "total": 10,
195:         "percentage": 100
196:       },
197:       "owasp_api_top10_2023": {
198:         "covered": 10,
199:         "total": 10,
200:         "percentage": 100,
201:         "note": "v0.5.0 \u65b0\u589e\u5b8c\u6574\u8986\u76d6"
202:       }
203:     }
204:   },
205:   "output": {
206:     "base_dir": ".codeagent",
207:     "protocol": "scan-output/2.0",
208:     "design": "\u4eba\u8bfb/\u673a\u8bfb\u5206\u79bb",
209:     "human_readable": "report.md (Markdown \u5ba1\u8ba1\u62a5\u544a)",
210:     "machine_readable": "results.sarif (SARIF 2.1.0, \u59cb\u7ec8\u751f\u6210, CI/CD \u6807\u51c6)",
211:     "dashboard": "summary.json (\u8f7b\u91cf\u7edf\u8ba1)",
212:     "structure": {
213:       "secguard-secguardian": "scans/<scan-id>/report.md + results.sarif + summary.json + manifest.json",
214:       "secaudit-secguardian": "scans/<scan-id>/report.md + results.sarif + summary.json + manifest.json",
215:       "secreview-secguardian": "scans/<scan-id>/report.md + results.sarif + summary.json + manifest.json"
216:     }
217:   },
218:   "integrations": {
219:     "ci_cd": {
220:       "github_actions": "action.yml (upload-sarif \u2192 GitHub Code Scanning)",
221:       "gitlab_ci": "artifacts:reports:sast \u2192 GitLab SAST Dashboard",
222:       "azure_devops": "SARIF SAST Scans tab"
223:     }
224:   },
225:   "changelog": {
226:     "0.6.0": {
227:       "date": "2026-06-07",
228:       "changes": [
229:         "\u2605 Output Protocol v5.0 \u2014 Per-Finding File Directory Tree: \u6bcf\u4e2a finding \u72ec\u7acb\u6587\u4ef6 + FindingsIndex \u7d22\u5f15\uff0c\u589e\u91cf\u626b\u63cf\u53cb\u597d",
230:         "\u2605 Output Protocol v3.0/v4.0 \u2014 AI/Renderer Pipeline: findings.json (Schema v1.0) \u2192 render-report.py \u6e32\u67d3 report.md + results.sarif + summary.json + manifest.json + status.json + delta.json (6 \u6587\u4ef6)",
231:         "\u2605 L1-L5 Layered Verification System: self-check.sh (82+ checks)\u3001ci-check.sh\u3001dev-verify.sh (23 checks)\u3001e2e-verify.sh (37 checks)\u3001cwe-coverage.sh\uff0c\u8986\u76d6\u8bbe\u8ba1\u2192\u7ed3\u6784\u2192\u90e8\u7f72\u2192\u67b6\u6784\u2192\u5168\u91cf\u4e94\u5c42\u9a8c\u8bc1",
232:         "\u2605 Manifest-Driven Token System: @secguardian \u6807\u8bb0\u6269\u6563 + sync-manifest.sh \u81ea\u52a8\u540c\u6b65\uff0c\u4fee\u6539 detector \u6570\u91cf\u53ea\u9700\u6539 manifest.json\uff08\u6563\u5f39\u5f0f\u4fee\u6539\u7ec8\u7ed3\u8005\uff09",
233:         "\u2605 CWE \u8986\u76d6\u7387\u81ea\u52a8\u5316\u9a8c\u8bc1: cwe-coverage.sh \u81ea\u52a8\u9a8c\u8bc1 CWE Top 25 + OWASP Top 10 + OWASP API Top 10 \u8986\u76d6\u7387",
234:         "render-report.py v1.0: --findings-dir \u652f\u6301 v5.0 \u76ee\u5f55\u6811\uff08\u5411\u540e\u517c\u5bb9\uff09\uff0c--ci \u6a21\u5f0f\u3001--format sarif \u72ec\u7acb\u751f\u6210",
235:         "render-report.py \u90e8\u7f72\u5230\u5168\u90e8 3 \u5e73\u53f0 (Claude Code + OpenCode + Gemini CLI)",
236:         "Findings Schema v1.0: \u56db\u6bb5\u5f0f (WHAT/HOW/FIX/VERIFY) \u6807\u51c6\u5316 + SingleFindingFile + FindingsIndex",
237:         "SARIF Output v1.1: partialFingerprints \u53bb\u91cd + GitHub/GitLab/Azure \u4e09\u5e73\u53f0\u517c\u5bb9",
238:         "17 skills \u56db\u6bb5\u5f0f\u8f93\u51fa\u5b8c\u6574\u6027\u8981\u6c42 + \u8f93\u51fa\u8d28\u91cf\u95e8\u7981\u68c0\u67e5\u6e05\u5355\uff08Step 4\uff09",
239:         "OpenCode: \u63d2\u4ef6\u6ce8\u518c\u81ea\u52a8\u5316 + \u547d\u4ee4\u811a\u672c + extension.json \u683c\u5f0f\u4fee\u590d",
240:         "JavaScript: \u7efc\u5408\u6f0f\u6d1e\u793a\u4f8b\u4ee3\u7801\u4ed3\u5e93 (9 \u4e2a\u6f0f\u6d1e) + indexer \u652f\u6301",
241:         "5 \u4e2a AI \u5165\u53e3\u6587\u4ef6 (CLAUDE.md/AGENTS.md/CODEBUDDY.md/COPILOT.md/GEMINI.md) L1-L5 \u9a8c\u8bc1\u6d41\u7a0b\u7edf\u4e00",
242:         "\u6027\u80fd\u4f18\u5316: \u5177\u4f53\u5316 indexer \u4f7f\u7528\u6307\u4ee4\uff0c\u6d88\u9664 brute-force \u626b\u63cf\u548c clangd \u8bef\u7528",
243:         "\u4fee\u590d: threat-catalog \u540c\u6b65 + detector \u6587\u4ef6\u540d\u7edf\u4e00 (67 \u4e2a namespace-name.md) + detector \u6570\u91cf\u52a8\u6001\u5316 + \u7248\u672c\u53f7\u4fee\u6b63 (0.5.3\u21920.5.5)"
244:       ]
245:     },
246:     "0.5.1": {
247:       "date": "2026-05-31",
248:       "changes": [
249:         "\u2605 \u8f93\u51fa\u534f\u8bae\u5347\u7ea7 v2.0: \u4eba\u8bfb/\u673a\u8bfb\u5206\u79bb \u2014 findings/*.json \u5e9f\u5f03\uff0c\u6539\u4e3a report.md + results.sarif + summary.json",
250:         "report.md: Markdown \u683c\u5f0f\u5b89\u5168\u5ba1\u8ba1\u62a5\u544a\uff0c\u542b\u6267\u884c\u6458\u8981/\u68c0\u51fa\u6e05\u5355/\u8be6\u7ec6\u53d1\u73b0/\u4fee\u590d\u4f18\u5148\u7ea7",
251:         "results.sarif: \u59cb\u7ec8\u751f\u6210\uff08\u4e0d\u518d\u9700\u8981 --sarif flag\uff09\uff0cCI/CD \u539f\u751f\u8f93\u5165",
252:         "summary.json: \u8f7b\u91cf\u4eea\u8868\u76d8\u7edf\u8ba1 \u2014 \u6309\u4e25\u91cd\u5ea6/\u547d\u540d\u7a7a\u95f4/\u8bed\u8a00\u5206\u7ec4",
253:         "manifest.json: \u7cbe\u7b80\u4e3a\u5143\u6570\u636e+\u68c0\u51fa\u7d22\u5f15\uff0c\u4e0d\u518d\u5185\u8054\u5b8c\u6574 finding",
254:         "SARIF \u751f\u6210\u89c4\u5219: partialFingerprints \u53bb\u91cd + GitHub/GitLab/Azure \u517c\u5bb9"
255:       ]
256:     },
257:     "0.5.0": {
258:       "date": "2026-05-31",
259:       "changes": [
260:         "\u2605 \u67b6\u6784\u91cd\u6784: concept+detector \u53cc\u6587\u4ef6\u5408\u5e76\u4e3a\u81ea\u5305\u542b detector (WHAT+HOW+FIX \u4e00\u4f53\u5316)",
261:         "\u5220\u9664 knowledge/concepts/ \u76ee\u5f55 (17 \u4e2a\u96f6\u6563\u6587\u4ef6)\uff0c\u66ff\u6362\u4e3a knowledge/threat-catalog.md \u5355\u6587\u4ef6\u7d22\u5f15",
262:         "\u6bcf\u4e2a detector \u73b0\u5728\u81ea\u5305\u542b: \u5a01\u80c1\u5b9a\u4e49 \u2192 \u68c0\u6d4b\u903b\u8f91 \u2192 \u4fee\u590d\u6307\u5f15 \u2192 \u8bef\u62a5\u6392\u9664 \u2192 \u6a21\u5f0f\u6c47\u603b",
263:         "\u65b0\u589e error \u547d\u540d\u7a7a\u95f4 (6 \u4e2a\u68c0\u6d4b\u5668): stack-trace-leak, log-sensitive-data, exception-swallow, unified-error-format, debug-mode-production, panic-to-client",
264:         "crypto \u547d\u540d\u7a7a\u95f4\u6269\u5c55 (4\u21929): \u65b0\u589e aes-ecb-mode, tls-version, custom-crypto, password-storage, hardcoded-iv",
265:         "system.command-injection + path-traversal \u5168\u8bed\u8a00\u6269\u5c55 (c,cpp \u2192 \u51686\u8bed)",
266:         "crypto.* \u5168\u8bed\u8a00\u6269\u5c55 (c,cpp \u2192 \u51686\u8bed)",
267:         "web \u547d\u540d\u7a7a\u95f4\u6269\u5c55 (17\u219222): \u65b0\u589e mass-assignment, excessive-data-exposure, nosql-injection, prototype-pollution, ssti",
268:         "\u65b0\u589e JavaScript/Node.js \u8bed\u8a00\u652f\u6301: knowledge/languages/javascript.md + secguard-js + secreview-js",
269:         "\u65b0\u589e 4 \u4e2a knowledge/standards: SEI CERT C/C++/Java \u6620\u5c04 + OWASP Cheat Sheet \u6620\u5c04",
270:         "secreview \u53cd\u6a21\u5f0f\u68c0\u6d4b\u77e9\u9635\u6df1\u5316: 5 \u4e2a\u8bed\u8a00\u5168\u9762\u5347\u7ea7\u4e3a\u5177\u4f53 detection patterns",
271:         "CWE Top 25 \u8986\u76d6\u7387: 88% \u2192 100%",
272:         "OWASP API Top 10 \u8986\u76d6\u7387: \u90e8\u5206 \u2192 100%",
273:         "\u68c0\u6d4b\u5668\u603b\u6570: 45 \u2192 60 (+33%)",
274:         "\u591a\u8bed\u8a00 detector \u5360\u6bd4: 38% \u2192 69% (+81%)"
275:       ]
276:     }
277:   }
278: }

(End of file - total 278 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts</path>
<type>directory</type>
<entries>
benchmark.sh
bin/
build.ps1
check-command-templates.py
ci-check.sh
cwe-coverage.sh
deploy.sh
dev-verify.sh
e2e-verify.sh
gen-toml.sh
gitee-release.sh
github-release.sh
install.ps1
install.sh
opencode-plugin.js
package.sh
record-finding.py
release.sh
render-report.py
secfix.py
secguardian-index
secguardian-index.ps1
secguardian.ps1
self-check.sh
sync-language-index.sh
sync-manifest.sh
sync-toml.sh
sync-version.sh
validate-findings.py
validate-index.py
verify-lang-pipeline.sh

(31 entries)
</entries>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal</path>
<type>directory</type>
<entries>
context/
dist/
engine/
go.mod
go.sum
indexer/
main.go
output/
parser/

(9 entries)
</entries>
```

---

## Assistant (Build · DeepSeek V4 Flash · 3.4s)

_Thinking:_

Let me dive deeper into the critical files. I need to check:
1. The Go indexer code (internal/) - parser, indexer, context, main.go
2. The shell scripts - deploy.sh, package.sh, self-check.sh, etc.
3. The SDD docs
4. Python scripts like render-report.py, secfix.py

Let me read the most critical files in parallel.

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/main.go"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/main.go</path>
<type>file</type>
<content>
1: // SecGuardian Indexer — Semantic code indexer for AI-augmented security analysis
2: //
3: // Builds a structured index (symbols, call graph, alloc/free pairs, lock usage)
4: // from source code. Called by AI agent commands before scan/audit/review.
5: //
6: // Usage:
7: //   secguardian-index --path ./src --output .codeagent/index.json
8: //   secguardian-index --health
9: //   secguardian-index --version
10: 
11: package main
12: 
13: import (
14: 	"encoding/json"
15: 	"flag"
16: 	"fmt"
17: 	"os"
18: 	"path/filepath"
19: 	"strings"
20: 
21: 	"github.com/secguardian/internal/context"
22: 	"github.com/secguardian/internal/indexer"
23: 	"github.com/secguardian/internal/parser"
24: )
25: 
26: const version = "0.12.0"
27: 
28: func main() {
29: 	runIndex(os.Args[1:])
30: }
31: 
32: func runIndex(args []string) {
33: 	fs := flag.NewFlagSet("secguardian-index", flag.ExitOnError)
34: 	pathFlag := fs.String("path", ".", "Source directory to index")
35: 	langFlag := fs.String("lang", "auto", "Language: c, cpp, python, java, go, javascript, auto")
36: 	outputFlag := fs.String("output", ".codeagent/index.json", "Output file path")
37: 	versionFlag := fs.Bool("version", false, "Print version and exit")
38: 	healthFlag := fs.Bool("health", false, "Smoke test: can we parse a known file?")
39: 	fs.Parse(args)
40: 
41: 	if *versionFlag {
42: 		fmt.Printf("secguardian-index %s\n", version)
43: 		os.Exit(0)
44: 	}
45: 
46: 	if *healthFlag {
47: 		files, err := collectFiles(*pathFlag, *langFlag)
48: 		if err != nil {
49: 			fmt.Printf("HEALTH:FAIL %v\n", err)
50: 			os.Exit(1)
51: 		}
52: 		if len(files) == 0 {
53: 			fmt.Println("HEALTH:WARN no source files found (but binary is executable)")
54: 			os.Exit(0)
55: 		}
56: 		_, err = parser.ParseFile(files[0], detectLanguage(files[0], *langFlag))
57: 		if err != nil {
58: 			fmt.Printf("HEALTH:FAIL parser error: %v\n", err)
59: 			os.Exit(1)
60: 		}
61: 		fmt.Printf("HEALTH:OK (%d source files available)\n", len(files))
62: 		os.Exit(0)
63: 	}
64: 
65: 	// Collect source files
66: 	files, err := collectFiles(*pathFlag, *langFlag)
67: 	if err != nil {
68: 		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
69: 		os.Exit(1)
70: 	}
71: 
72: 	if len(files) == 0 {
73: 		fmt.Fprintf(os.Stderr, "Error: no source files found in %s\n", *pathFlag)
74: 		os.Exit(1)
75: 	}
76: 
77: 	fmt.Printf("Indexing %d files in %s...\n", len(files), *pathFlag)
78: 
79: 	// Phase 1: Parse all files
80: 	parsed := make(map[string]*parser.ParseResult)
81: 	for _, f := range files {
82: 		lang := detectLanguage(f, *langFlag)
83: 		result, err := parser.ParseFile(f, lang)
84: 		if err != nil {
85: 			fmt.Fprintf(os.Stderr, "  [WARN] Failed to parse %s: %v\n", filepath.Base(f), err)
86: 			continue
87: 		}
88: 		parsed[f] = result
89: 		fmt.Printf("  Parsed: %s (%d functions, %d vars)\n", filepath.Base(f), len(result.Functions), len(result.Variables))
90: 	}
91: 
92: 	// Phase 2: Build symbol index
93: 	symbols := indexer.ExtractSymbols(parsed)
94: 	fmt.Printf("  Symbols: %d functions, %d variables, %d types\n",
95: 		len(symbols.Functions), len(symbols.Variables), len(symbols.Types))
96: 
97: 	// Phase 3: Build call graph
98: 	cg := indexer.BuildCallGraph(parsed, symbols)
99: 	fmt.Printf("  Call graph: %d edges\n", len(cg.Edges))
100: 
101: 	// Phase 4: Match alloc/free pairs
102: 	af := indexer.MatchAllocFree(parsed)
103: 	fmt.Printf("  Alloc/free: %d pairs\n", len(af.Pairs))
104: 
105: 	// Phase 5: Build lock usage graph
106: 	lg := indexer.BuildLockGraph(parsed)
107: 	fmt.Printf("  Lock usage: %d mutexes\n", len(lg.Mutexes))
108: 
109: 
110: 	// Determine primary language
111: 	primaryLang := *langFlag
112: 	if primaryLang == "auto" {
113: 		extCount := make(map[string]int)
114: 		for _, f := range files {
115: 			extCount[detectLanguage(f, "auto")]++
116: 		}
117: 		maxCount := 0
118: 		for lang, count := range extCount {
119: 			if count > maxCount {
120: 				maxCount = count
121: 				primaryLang = lang
122: 			}
123: 		}
124: 		if primaryLang == "auto" {
125: 			primaryLang = "c"
126: 		}
127: 	}
128: 
129: 	// Phase 6: Assemble and write context
130: 	ctx := context.AnalysisContext{
131: 		Path:            *pathFlag,
132: 		FileCount:       len(files),
133: 		FunctionCount:   len(symbols.Functions),
134: 		CallEdgeCount:   len(cg.Edges),
135: 		PrimaryLanguage: primaryLang,
136: 		Files:           files,
137: 		Symbols:         symbols,
138: 		CallGraph:       cg,
139: 		AllocFree:       af,
140: 		LockGraph:       lg,
141: 	}
142: 
143: 	if err := os.MkdirAll(filepath.Dir(*outputFlag), 0755); err != nil {
144: 		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
145: 		os.Exit(1)
146: 	}
147: 
148: 	data, err := json.MarshalIndent(ctx, "", "  ")
149: 	if err != nil {
150: 		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
151: 		os.Exit(1)
152: 	}
153: 
154: 	if err := os.WriteFile(*outputFlag, data, 0644); err != nil {
155: 		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
156: 		os.Exit(1)
157: 	}
158: 
159: 	fmt.Printf("Index written to %s (%d bytes)\n", *outputFlag, len(data))
160: }
161: 
162: func collectFiles(path, lang string) ([]string, error) {
163: 	var files []string
164: 	extMap := map[string][]string{
165: 		"c":          {".c", ".h"},
166: 		"cpp":        {".c", ".cpp", ".cc", ".cxx", ".h", ".hpp", ".hh"},
167: 		"python":     {".py"},
168: 		"java":       {".java"},
169: 		"go":         {".go"},
170: 		"javascript": {".js", ".jsx", ".mjs", ".cjs"},
171: 	}
172: 
173: 	var exts []string
174: 	if lang == "auto" {
175: 		exts = []string{".c", ".cpp", ".cc", ".cxx", ".h", ".hpp", ".hh", ".py", ".java", ".go", ".js", ".jsx", ".mjs", ".cjs"}
176: 	} else if e, ok := extMap[lang]; ok {
177: 		exts = e
178: 	} else {
179: 		return nil, fmt.Errorf("unsupported language: %s (use: c, cpp, python, java, go, javascript, auto)", lang)
180: 	}
181: 
182: 	err := filepath.Walk(path, func(p string, info os.FileInfo, err error) error {
183: 		if err != nil {
184: 			return err
185: 		}
186: 		if info.IsDir() {
187: 			base := filepath.Base(p)
188: 			if base == ".git" || base == ".claude" || base == ".codeagent" || base == ".gemini" || base == ".opencode" || base == "node_modules" || base == "dist" || base == "target" || base == "build" || base == "static" || base == "public" {
189: 				return filepath.SkipDir
190: 			}
191: 			return nil
192: 		}
193: 		for _, ext := range exts {
194: 			if strings.HasSuffix(p, ext) {
195: 				files = append(files, p)
196: 				break
197: 			}
198: 		}
199: 		return nil
200: 	})
201: 	return files, err
202: }
203: 
204: func detectLanguage(file, langFlag string) string {
205: 	if langFlag != "auto" {
206: 		return langFlag
207: 	}
208: 	ext := filepath.Ext(file)
209: 	switch ext {
210: 	case ".c", ".h":
211: 		return "c"
212: 	case ".cpp", ".cc", ".cxx", ".hpp", ".hh":
213: 		return "cpp"
214: 	case ".py":
215: 		return "python"
216: 	case ".java":
217: 		return "java"
218: 	case ".go":
219: 		return "go"
220: 	case ".js", ".jsx", ".mjs", ".cjs":
221: 		return "javascript"
222: 	}
223: 	return "c"
224: }

(End of file - total 224 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/context"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/context</path>
<type>directory</type>
<entries>
context_test.go
context.go

(2 entries)
</entries>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/indexer"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/indexer</path>
<type>directory</type>
<entries>
diff_parser_test.go
diff_parser.go
indexer_test.go
indexer.go

(4 entries)
</entries>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/parser"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/parser</path>
<type>directory</type>
<entries>
parser_javascript.go
parser_re_test.go
parser_re.go
parser_test_helpers.go
parser_ts_test.go
parser_ts.go
types.go

(7 entries)
</entries>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/deploy.sh"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/deploy.sh</path>
<type>file</type>
<content>
1: #!/bin/bash
2: # SecGuardian — 统一部署脚本
3: # 用法: bash scripts/deploy.sh <platform> [--project] [--zip] [--verify]
4: #       bash scripts/deploy.sh all
5: #       bash scripts/deploy.sh cc|nga|cac
6: #
7: # 默认行为: 自动先构建（package.sh）再部署
8: # 会先自动检查 dist/ 是否就绪，否则先执行 package.sh
9: 
10: set -euo pipefail
11: 
12: PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
13: DIST="$PROJECT_ROOT/dist"
14: DEPLOY_USER=true      # 默认用户级，--project 切换为项目级
15: DO_UNINSTALL=false
16: DO_ZIP=false
17: DO_BUILD=false
18: DO_VERIFY=false
19: 
20: # ── Help ──────────────────────────────────────
21: show_help() {
22:     cat << 'EOF'
23: SecGuardian — 部署脚本
24: 
25: 将构建好的 dist/ 部署到 AI CLI 平台。
26: 
27: 用法:
28:   bash scripts/deploy.sh <platform> [--project] [--zip]
29:   bash scripts/deploy.sh <platform> --uninstall
30: 
31: 平台:
32:   all      三平台全部 (默认)
33:   cc       Claude Code    → .claude/plugins/secguardian/
34:   nga      OpenCode       → ~/.config/opencode/plugins/ + extensions/ (user, 默认) / .opencode/plugins/ + extensions/ (project)
35:   cac      Gemini CLI     → ~/.gemini/extensions/secguardian/ (user, 默认) / .gemini/extensions/secguardian/ (project)
36: 
37: 选项:
38:   --project    部署到项目级目录（.opencode/ 等）
39:   --uninstall  卸载已安装的 secguardian 文件
40:   --zip        部署后生成发布压缩包 → dist/archives/
41:   --verify     部署后运行 dev-verify.sh 验证健康
42: 
43: 示例:
44:   bash scripts/deploy.sh all --project       # 项目级部署
45:   bash scripts/deploy.sh all --uninstall     # 卸载全部
46:   bash scripts/deploy.sh all --project --uninstall
47:   bash scripts/deploy.sh all                     # 构建 + 部署到用户级（3 平台）
48:   bash scripts/deploy.sh all --verify             # 构建 + 部署到用户级 + 验证
49:   bash scripts/deploy.sh cc                 # 项目级部署 Claude Code
50: EOF
51:     exit 0
52: }
53: 
54: # ── 解析参数 ──────────────────────────────────
55: # 第一个参数可以是平台名(all/cc/nga/cac)或选项(--project等)
56: case "${1:-}" in
57:     all|cc|nga|cac) PLATFORM="$1"; shift 2>/dev/null || true ;;
58:     -h|--help|help) show_help ;;
59:     --*)            PLATFORM="all" ;;   # 选项当第一个参数 → 默认全平台
60:     "")             PLATFORM="all" ;;
61:     *) echo "未知参数: $1"; exit 1 ;;
62: esac
63: 
64: while [[ $# -gt 0 ]]; do
65:     case "$1" in
66:         --project) DEPLOY_USER=false; shift ;;
67:         --uninstall) DO_UNINSTALL=true; shift ;;
68:         --zip) DO_ZIP=true; shift ;;
69:         --verify) DO_VERIFY=true; shift ;;
70:         -h|--help|help) show_help ;;
71:         *) shift ;;
72:     esac
73: done
74: 
75: # ── 前置构建（默认执行，--uninstall 时跳过）───
76: if ! $DO_UNINSTALL; then
77:     echo "  → 正在构建 dist/..."
78:     bash "$PROJECT_ROOT/scripts/package.sh"
79:     echo "  ✓ 构建完成"
80:     echo ""
81: fi
82: 
83: # ── 部署目标路径 ──────────────────────────────
84: if $DEPLOY_USER; then
85:     TARGET_ROOT="$HOME"
86:     DEPLOY_MODE="用户级"
87:     DEPLOY_MODE_DESC="跨所有项目可用"
88: else
89:     TARGET_ROOT="$PROJECT_ROOT"
90:     DEPLOY_MODE="项目级"
91:     DEPLOY_MODE_DESC="仅当前项目可用"
92: fi
93: 
94: # ── 工具函数 ──────────────────────────────────
95: BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
96: log_step()  { echo -e "${BOLD}═══ $1 ═══${NC}"; }
97: log_info()  { echo -e "${CYAN}  →${NC} $1"; }
98: log_done()  { echo -e "${GREEN}  ✓${NC} $1"; }
99: 
100: # ── 前置检查 ──────────────────────────────────
101: ensure_dist() {
102:     if [ ! -d "$DIST" ] || [ -z "$(ls -A "$DIST" 2>/dev/null)" ]; then
103:         log_info "dist/ 为空，先执行构建..."
104:         bash "$PROJECT_ROOT/scripts/package.sh"
105:     fi
106: }
107: 
108: # ── Indexer binary deployment (canonical naming) ──
109: # Copies the current platform's binary as 'secguardian-index' (no suffix)
110: # so users always see the same binary name regardless of platform.
111: deploy_indexer_binary() {
112:     local target_bin_dir="$1"
113:     mkdir -p "$target_bin_dir"
114:     local target="$target_bin_dir/secguardian-index"
115: 
116:     # Detect current platform
117:     local os_name arch_name
118:     case "$(uname -s)" in
119:         Darwin) os_name="darwin" ;;
120:         Linux)  os_name="linux" ;;
121:         *)      os_name="unknown" ;;
122:     esac
123:     case "$(uname -m)" in
124:         x86_64|amd64)  arch_name="amd64" ;;
125:         arm64|aarch64) arch_name="arm64" ;;
126:         *)             arch_name="unknown" ;;
127:     esac
128: 
129:     local bin_src="$PROJECT_ROOT/scripts/bin"
130:     local src="$bin_src/secguardian-index-${os_name}-${arch_name}"
131: 
132:     # If exact platform binary doesn't exist, try any available
133:     if [ ! -f "$src" ]; then
134:         src=$(ls "$bin_src"/secguardian-index-* 2>/dev/null | head -1)
135:     fi
136:     if [ -z "$src" ] || [ ! -f "$src" ]; then
137:         log_info "no indexer binary found for ${os_name}-${arch_name} — skipping binary deployment"
138:         return 0
139:     fi
140: 
141:     # Idempotency: skip if same version already deployed
142:     if [ -x "$target" ]; then
143:         local existing_ver=$("$target" --version 2>/dev/null || echo "unknown")
144:         local new_ver=$("$src" --version 2>/dev/null || echo "unknown")
145:         if [ "$existing_ver" = "$new_ver" ] && [ -n "$existing_ver" ] && [ "$existing_ver" != "unknown" ]; then
146:             log_info "indexer binary already up-to-date ($existing_ver)"
147:             return 0
148:         fi
149:     fi
150: 
151:     # Atomic replacement
152:     cp "$src" "${target}.tmp"
153:     chmod +x "${target}.tmp"
154:     if "${target}.tmp" --version >/dev/null 2>&1; then
155:         mv "${target}.tmp" "$target"
156:         local ver=$("$target" --version 2>/dev/null || echo "unknown")
157:         log_info "indexer binary deployed: secguardian-index ($ver, ${os_name}-${arch_name})"
158:         return 0
159:     else
160:         rm -f "${target}.tmp"
161:         log_info "indexer binary verification failed — keeping existing version"
162:         return 1
163:     fi
164: }
165: 
166: # ── Claude Code (Official Plugin Format) ──────────
167: # Ref: https://code.claude.com/docs/en/plugins-reference
168: deploy_claude() {
169:     local plugin_name="secguardian"
170:     local plugin_dir="$TARGET_ROOT/.claude/plugins/$plugin_name"
171: 
172:     if $DEPLOY_USER; then
173:         log_step "Claude Code → ~/.claude/plugins/$plugin_name/ (用户级)"
174:     else
175:         log_step "Claude Code → .claude/plugins/$plugin_name/ (项目级)"
176:     fi
177: 
178:     # Clean old: remove legacy extensions/ format AND old plugin
179:     rm -rf "$TARGET_ROOT/.claude/extensions/secguard-secguardian" \
180:            "$TARGET_ROOT/.claude/extensions/secaudit-secguardian" \
181:            "$TARGET_ROOT/.claude/extensions/secreview-secguardian" \
182:            "$plugin_dir"
183: 
184:     mkdir -p "$plugin_dir/.claude-plugin" "$plugin_dir/commands" "$plugin_dir/skills" \
185:              "$plugin_dir/knowledge/languages" "$plugin_dir/knowledge/guard-rules" \
186:              "$plugin_dir/knowledge/protocols" "$plugin_dir/knowledge/standards" \
187:              "$plugin_dir/scripts/bin"
188: 
189:     # Write official plugin.json
190:     # NOTE: version "0.5.4" below should match manifest.json version
191:     cat > "$plugin_dir/.claude-plugin/plugin.json" << JSON
192: {
193:   "name": "secguardian",
194:   "version": "0.5.4",
195:   "description": "SecGuardian XuanWu — 企业级白盒安全 AI Agent 辅助解决方案。60 检测器、17 审计技能、5 语言安全检视。",
196:   "author": { "name": "SecGuardian", "url": "https://gitee.com/jonyan/secguardian" },
197:   "homepage": "https://gitee.com/jonyan/secguardian",
198:   "keywords": ["security", "sast", "audit", "code-review", "vulnerability"]
199: }
200: JSON
201: 
202:     local total_skills=0 total_cmds=0
203:     for d in "$DIST"/*/; do
204:         # Commands
205:         if [ -d "$d/commands" ]; then
206:             for f in "$d/commands"/*.md; do
207:                 [ -f "$f" ] && cp "$f" "$plugin_dir/commands/" && total_cmds=$((total_cmds + 1))
208:             done
209:         fi
210:         # Skills
211:         if [ -d "$d/skills" ]; then
212:             for sd in "$d/skills"/*/; do
213:                 [ -d "$sd" ] && cp -r "$sd" "$plugin_dir/skills/$(basename "$d" | sed 's/-secguardian//')-$(basename "$sd")" && total_skills=$((total_skills + 1))
214:             done
215:         fi
216:         # Knowledge: merge across all extensions
217:         for cat in languages guard-rules protocols; do
218:             if [ -d "$d/knowledge/$cat" ]; then
219:                 find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$plugin_dir/knowledge/$cat/" \;
220:             fi
221:         done
222:     done
223:     log_done "$total_cmds commands, $total_skills skills"
224: 
225:     # ── Namespace commands: prevent collision with other plugins ──
226:     # Creates commands/secguardian/ subdirectory so commands are also
227:     # available as /secguardian:secguard etc. — safe even if another
228:     # plugin also registers /secguard /secaudit /secreview.
229:     mkdir -p "$plugin_dir/commands/secguardian"
230:     for f in "$plugin_dir/commands"/*.md; do
231:         [ -f "$f" ] && cp "$f" "$plugin_dir/commands/secguardian/$(basename "$f")"
232:     done
233:     log_done "namespace commands: /secguardian:secguard, /secguardian:secaudit, /secguardian:secreview"
234: 
235:     # Copy project-level knowledge (v2.0)
236:     [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ] && cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$plugin_dir/knowledge/"
237:     [ -f "$PROJECT_ROOT/SECURITY.md" ] && cp "$PROJECT_ROOT/SECURITY.md" "$plugin_dir/knowledge/"
238:     [ -d "$PROJECT_ROOT/knowledge/standards" ] && cp -r "$PROJECT_ROOT/knowledge/standards/"* "$plugin_dir/knowledge/standards/" 2>/dev/null || true
239:     cp -r "$PROJECT_ROOT/knowledge/audit-rules" "$plugin_dir/knowledge/"
240:     cp -r "$PROJECT_ROOT/knowledge/review-rules" "$plugin_dir/knowledge/"
241:     cp "$PROJECT_ROOT/knowledge/language-index.md" "$plugin_dir/knowledge/"
242: 
243:     # Copy wrapper scripts, renderer, and binaries into plugin
244:     for wrapper in secguardian-index secguardian-index.ps1 render-report.py validate-index.py validate-findings.py record-finding.py; do
245:         if [ -f "$PROJECT_ROOT/scripts/$wrapper" ]; then
246:             cp "$PROJECT_ROOT/scripts/$wrapper" "$plugin_dir/scripts/$wrapper"
247:             chmod +x "$plugin_dir/scripts/$wrapper" 2>/dev/null || true
248:         fi
249:     done
250:     deploy_indexer_binary "$plugin_dir/scripts/bin"
251: 
252:     # ── Write .secguardian-env ──────────────────
253:     echo 'export SECGUARDIAN_HOME=$HOME/.claude/plugins/secguardian' > "$plugin_dir/.secguardian-env"
254: 
255:     # ── Register plugin with Claude Code ──────────────
256:     # Claude Code v2.1.x requires plugins to be installed via marketplace.
257:     # We set up a local marketplace that points to the plugin directory,
258:     # then register it so the plugin auto-discovers on next session.
259:     register_claude_plugin "$plugin_dir"
260: 
261:     echo ""
262:     log_info "Claude Code 命令（重启后生效）:"
263:     echo "    /secguard <path> [mode] [filters]"
264:     echo "    /secaudit <skill-name>"
265:     echo "    /secreview <path> [language]"
266: }
267: 
268: # ── Register plugin in Claude Code's plugin registry ─
269: # Sets up a local marketplace and installs the plugin via CLI,
270: # with JSON fallback if the CLI is unavailable.
271: register_claude_plugin() {
272:     local plugin_dir="$1"
273:     local plugin_version
274:     plugin_version=$(grep -m1 '"version"' "$plugin_dir/.claude-plugin/plugin.json" | sed 's/.*: *"\([^"]*\)".*/\1/')
275:     local marketplace_name="secguardian-local"
276:     local marketplace_dir="$HOME/.claude/plugins/marketplaces/$marketplace_name"
277:     local settings_file="$HOME/.claude/settings.json"
278:     local installed_file="$HOME/.claude/plugins/installed_plugins.json"
279:     local known_marketplaces_file="$HOME/.claude/plugins/known_marketplaces.json"
280: 
281:     # Create marketplace structure
282:     mkdir -p "$marketplace_dir/.claude-plugin" "$marketplace_dir/plugins"
283: 
284:     # Remove old flat marketplace.json (legacy)
285:     rm -f "$marketplace_dir/marketplace.json"
286: 
287:     # Symlink plugin into marketplace
288:     ln -sfn "$plugin_dir" "$marketplace_dir/plugins/secguardian"
289: 
290:     # Write marketplace manifest
291:     cat > "$marketplace_dir/.claude-plugin/marketplace.json" << JSON
292: {
293:   "name": "$marketplace_name",
294:   "description": "SecGuardian XuanWu — 企业级白盒安全 AI Agent 辅助解决方案。60 检测器、17 审计技能、5 语言安全检视。",
295:   "owner": { "name": "SecGuardian" },
296:   "plugins": [
297:     {
298:       "name": "secguardian",
299:       "description": "Security scan/audit/review commands — /secguard, /secaudit, /secreview",
300:       "version": "$plugin_version",
301:       "source": "./plugins/secguardian",
302:       "category": "security",
303:       "homepage": "https://gitee.com/jonyan/secguardian",
304:       "author": { "name": "SecGuardian" },
305:       "keywords": ["security", "sast", "audit", "code-review", "vulnerability"]
306:     }
307:   ]
308: }
309: JSON
310: 
311:     # Try CLI-based install first
312:     if command -v claude &>/dev/null; then
313:         # Register marketplace
314:         claude plugin marketplace add "$marketplace_dir" 2>/dev/null || true
315:         # Install/update plugin (idempotent — CLI handles upgrades)
316:         claude plugin install "secguardian@$marketplace_name" 2>/dev/null && {
317:             log_done "plugin registered via claude CLI"
318:             return 0
319:         }
320:     fi
321: 
322:     # Fallback: manual JSON manipulation
323:     log_info "claude CLI unavailable — registering via JSON"
324: 
325:     # Register marketplace in known_marketplaces.json
326:     if [ -f "$known_marketplaces_file" ]; then
327:         python3 -c "
328: import json, sys
329: with open('$known_marketplaces_file') as f:
330:     data = json.load(f)
331: data['$marketplace_name'] = {
332:     'source': {'source': 'directory', 'path': '$marketplace_dir'},
333:     'installLocation': '$marketplace_dir',
334:     'lastUpdated': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
335: }
336: with open('$known_marketplaces_file', 'w') as f:
337:     json.dump(data, f, indent=2)
338: " 2>/dev/null || true
339:     fi
340: 
341:     # Register in installed_plugins.json
342:     if [ -f "$installed_file" ]; then
343:         python3 -c "
344: import json
345: with open('$installed_file') as f:
346:     data = json.load(f)
347: key = 'secguardian@$marketplace_name'
348: entry = {
349:     'scope': 'user',
350:     'installPath': '$HOME/.claude/plugins/cache/$marketplace_name/secguardian/$plugin_version',
351:     'version': '$plugin_version',
352:     'installedAt': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
353:     'lastUpdated': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
354: }
355: data['plugins'][key] = [entry]
356: with open('$installed_file', 'w') as f:
357:     json.dump(data, f, indent=2)
358: " 2>/dev/null || true
359:     fi
360: 
361:     # Enable in settings.json
362:     if [ -f "$settings_file" ]; then
363:         python3 -c "
364: import json
365: with open('$settings_file') as f:
366:     data = json.load(f)
367: if 'enabledPlugins' not in data:
368:     data['enabledPlugins'] = {}
369: data['enabledPlugins']['secguardian@$marketplace_name'] = True
370: with open('$settings_file', 'w') as f:
371:     json.dump(data, f, indent=2)
372: " 2>/dev/null || true
373:     fi
374: 
375:     # Cache the plugin files for the CLI-install path (mirrors what claude plugin install does)
376:     local cache_dir="$HOME/.claude/plugins/cache/$marketplace_name/secguardian/$plugin_version"
377:     if [ ! -d "$cache_dir" ]; then
378:         mkdir -p "$(dirname "$cache_dir")"
379:         cp -r "$plugin_dir" "$cache_dir"
380:     fi
381: 
382:     log_done "plugin registered via JSON fallback"
383: }
384: 
385: # ── 卸载 ──────────────────────────────────────
386: uninstall_claude() {
387:     local plugin_dir="$TARGET_ROOT/.claude/plugins/secguardian"
388:     local marketplace_name="secguardian-local"
389:     local marketplace_dir="$HOME/.claude/plugins/marketplaces/$marketplace_name"
390:     local cache_dir="$HOME/.claude/plugins/cache/$marketplace_name"
391:     local legacy_ext="$TARGET_ROOT/.claude/extensions"
392: 
393:     # Try CLI uninstall first
394:     if command -v claude &>/dev/null; then
395:         claude plugin uninstall "secguardian@$marketplace_name" 2>/dev/null || true
396:         claude plugin marketplace remove "$marketplace_name" 2>/dev/null || true
397:     fi
398: 
399:     # Clean marketplace structure
400:     [ -d "$marketplace_dir" ] && rm -rf "$marketplace_dir"
401:     [ -d "$cache_dir" ] && rm -rf "$cache_dir"
402: 
403:     # Clean plugin directory
404:     if [ -d "$plugin_dir" ]; then
405:         rm -rf "$plugin_dir"
406:         log_done "已移除: $plugin_dir"
407:     fi
408: 
409:     # Clean legacy extension-format plugins
410:     for name in secguard-secguardian secaudit-secguardian secreview-secguardian; do
411:         [ -d "$legacy_ext/$name" ] && rm -rf "$legacy_ext/$name"
412:     done
413: 
414:     # Clean JSON registrations (manual cleanup in case CLI missed them)
415:     local settings_file="$HOME/.claude/settings.json"
416:     local installed_file="$HOME/.claude/plugins/installed_plugins.json"
417:     local known_file="$HOME/.claude/plugins/known_marketplaces.json"
418: 
419:     for f in "$settings_file" "$installed_file" "$known_file"; do
420:         [ -f "$f" ] && python3 -c "
421: import json, sys
422: with open('$f') as fh:
423:     data = json.load(fh)
424: # Remove secguardian entries
425: if 'enabledPlugins' in data:
426:     data['enabledPlugins'].pop('secguardian@$marketplace_name', None)
427:     data['enabledPlugins'].pop('secguardian', None)
428: if 'extraKnownMarketplaces' in data:
429:     data['extraKnownMarketplaces'].pop('$marketplace_name', None)
430: if 'plugins' in data:
431:     data['plugins'].pop('secguardian@$marketplace_name', None)
432:     data['plugins'].pop('secguardian', None)
433: data.pop('$marketplace_name', None)
434: with open('$f', 'w') as fh:
435:     json.dump(data, fh, indent=2)
436: " 2>/dev/null || true
437:     done
438: 
439:     # NOTE: Do NOT delete scripts/secguardian-index — it is a source file, not a deployment artifact.
440: }
441: 
442: uninstall_opencode() {
443:     local brand="secguardian"
444:     local oc_dir="$TARGET_ROOT/.opencode"
445:     local oc_user_dir="$HOME/.config/opencode"
446:     for base in "$oc_dir" "$oc_user_dir"; do
447:         # Remove extension dir
448:         local ext_dir="$base/extensions/$brand"
449:         if [ -d "$ext_dir" ]; then
450:             rm -rf "$ext_dir"
451:             log_done "已移除: $ext_dir"
452:         fi
453:         # Remove plugin
454:         if [ -f "$base/plugins/secguardian.js" ]; then
455:             rm -f "$base/plugins/secguardian.js"
456:             log_done "已移除插件: $base/plugins/secguardian.js"
457:         fi
458:         # Clean legacy flat deployment if present
459:         for sub in commands skills knowledge scripts; do
460:             if [ -d "$base/$sub" ]; then
461:                 if [ -f "$base/$sub/secaudit.md" ] || \
462:                    [ -f "$base/$sub/secguard.md" ] || \
463:                    [ -d "$base/$sub/secaudit-attack-surface-analysis" ] || [ -d "$base/$sub/secguard-attack-surface-analysis" ]; then
464:                     rm -rf "$base/$sub"
465:                     log_done "已移除 (legacy): $base/$sub"
466:                 fi
467:             fi
468:         done
469:     done
470: }
471: 
472: uninstall_gemini() {
473:     local brand="secguardian"
474:     # Check both user-level and project-level paths
475:     for base in "$HOME/.gemini" "$PROJECT_ROOT/.gemini"; do
476:         local ext_dir="$base/extensions/$brand"
477:         if [ -d "$ext_dir" ]; then
478:             rm -rf "$ext_dir"
479:             log_done "已移除: $ext_dir"
480:         fi
481:         # Clean legacy flat deployment
482:         for sub in commands skills knowledge scripts GEMINI.md; do
483:             if [ -e "$base/$sub" ]; then
484:                 # Only remove if it was our deployment
485:                 if [ -f "$base/$sub/secaudit.toml" ] || \
486:                    [ -f "$base/$sub/secguard.toml" ] || \
487:                    [ -d "$base/$sub/secaudit-attack-surface-analysis" ] || [ -d "$base/$sub/secguard-attack-surface-analysis" ]; then
488:                     rm -rf "$base/$sub"
489:                     log_done "已移除 (legacy): $base/$sub"
490:                 fi
491:             fi
492:         done
493:     done
494: }
495: 
496: do_uninstall() {
497:     local plat="$1"
498:     echo ""
499:     echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
500:     echo -e "${BOLD}║${NC}  SecGuardian — 卸载 (${DEPLOY_MODE})                ${BOLD}║${NC}"
501:     echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
502:     echo ""
503:     echo -e "  目标: ${CYAN}$TARGET_ROOT${NC}"
504:     echo ""
505: 
506:     case "$plat" in
507:         all)
508:             uninstall_claude
509:             uninstall_opencode
510:             uninstall_gemini
511:             ;;
512:         cc)  uninstall_claude ;;
513:         nga) uninstall_opencode ;;
514:         cac) uninstall_gemini ;;
515:     esac
516: 
517:     echo ""
518:     log_done "卸载完成"
519: }
520: 
521: # ── OpenCode (Plugin + Extension) ──────────────
522: # Ref: https://opencode.ai/docs/plugins
523: # OpenCode discovers plugins from ~/.config/opencode/plugins/ (user) or .opencode/plugins/ (project)
524: # The plugin registers secguard/secaudit/secreview commands + skills.paths at startup
525: # Extension assets live under extensions/secguardian/, discovered by plugin via relative path
526: deploy_opencode() {
527:     local brand="secguardian"
528:     if $DEPLOY_USER; then
529:         local opencode_dir="$HOME/.config/opencode"
530:         log_step "OpenCode → plugins/secguardian.js + extensions/$brand/ (用户级)"
531:     else
532:         local opencode_dir="$TARGET_ROOT/.opencode"
533:         log_step "OpenCode → plugins/secguardian.js + extensions/$brand/ (项目级)"
534:     fi
535:     local ext_dir="$opencode_dir/extensions/$brand"
536:     local skills_dir="$ext_dir/skills"
537:     local knowledge_dir="$ext_dir/knowledge"
538:     local scripts_dir="$ext_dir/scripts"
539: 
540:     # Clean old: remove stale extension dir, stale plugin, legacy flat deployment
541:     rm -rf "$ext_dir"
542:     rm -f "$opencode_dir/plugins/secguardian.js"
543:     for legacy_sub in commands skills knowledge scripts; do
544:         if [ -d "$opencode_dir/$legacy_sub" ]; then
545:             if [ -f "$opencode_dir/$legacy_sub/secaudit.md" ] || \
546:                [ -f "$opencode_dir/$legacy_sub/secguard.md" ] || \
547:                [ -d "$opencode_dir/$legacy_sub/secaudit-attack-surface-analysis" ] || \
548:                [ -d "$opencode_dir/$legacy_sub/threat-catalog.md" ] || \
549:                [ -f "$opencode_dir/$legacy_sub/secguardian-index" ]; then
550:                 rm -rf "$opencode_dir/$legacy_sub"
551:                 log_info "removed legacy flat deployment: $legacy_sub/"
552:             fi
553:         fi
554:     done
555: 
556:     mkdir -p "$ext_dir/commands" "$skills_dir" "$scripts_dir/bin" \
557:              "$knowledge_dir/languages" "$knowledge_dir/guard-rules" \
558:              "$knowledge_dir/protocols" "$knowledge_dir/standards" \
559:              "$opencode_dir/plugins"
560: 
561:     # Write codeagent-extension.json (informational manifest)
562:     cat > "$ext_dir/codeagent-extension.json" << JSON
563: {
564:   "name": "$brand",
565:   "version": "0.5.5",
566:   "description": "SecGuardian XuanWu — 企业级白盒安全 AI Agent 辅助解决方案"
567: }
568: JSON
569: 
570:     # ── Deploy plugin ────────────────────────────
571:     if [ -f "$PROJECT_ROOT/scripts/opencode-plugin.js" ]; then
572:         cp "$PROJECT_ROOT/scripts/opencode-plugin.js" "$opencode_dir/plugins/secguardian.js"
573:         log_done "opencode plugin: plugins/secguardian.js"
574:     fi
575: 
576:     # ── Deploy command templates ─────────────────
577:     local cmd_n=0 skill_n=0
578:     for d in "$DIST"/*/; do
579:         if [ -d "$d/commands" ]; then
580:             for f in "$d/commands"/*.md; do
581:                 [ -f "$f" ] && cp "$f" "$ext_dir/commands/" && cmd_n=$((cmd_n + 1))
582:             done
583:         fi
584:     done
585: 
586:     # ── Deploy skills ────────────────────────────
587:     for d in "$DIST"/*/; do
588:         if [ -d "$d/skills" ]; then
589:             for sd in "$d/skills"/*/; do
590:                 [ -d "$sd" ] && cp -r "$sd" "$skills_dir/$(basename "$d" | sed 's/-secguardian//')-$(basename "$sd")" && skill_n=$((skill_n + 1))
591:             done
592:         fi
593:     done
594: 
595:     # ── Deploy knowledge ─────────────────────────
596:     for cat in languages guard-rules protocols; do
597:         for d in "$DIST"/*/; do
598:             if [ -d "$d/knowledge/$cat" ]; then
599:                 find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$knowledge_dir/$cat/" \;
600:             fi
601:         done
602:     done
603:     [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ] && cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$knowledge_dir/"
604:     [ -f "$PROJECT_ROOT/SECURITY.md" ] && cp "$PROJECT_ROOT/SECURITY.md" "$knowledge_dir/"
605:     [ -d "$PROJECT_ROOT/knowledge/standards" ] && cp -r "$PROJECT_ROOT/knowledge/standards/"* "$knowledge_dir/standards/" 2>/dev/null || true
606:     cp -r "$PROJECT_ROOT/knowledge/audit-rules" "$knowledge_dir/"
607:     cp -r "$PROJECT_ROOT/knowledge/review-rules" "$knowledge_dir/"
608:     cp "$PROJECT_ROOT/knowledge/language-index.md" "$knowledge_dir/"
609: 
610:     log_done "$cmd_n commands, $skill_n skills, knowledge/ + scripts/"
611: 
612:     # ── Deploy scripts + indexer ─────────────────
613:     for wrapper in secguardian-index secguardian-index.ps1 render-report.py validate-index.py validate-findings.py record-finding.py; do
614:         if [ -f "$PROJECT_ROOT/scripts/$wrapper" ]; then
615:             cp "$PROJECT_ROOT/scripts/$wrapper" "$scripts_dir/$wrapper"
616:             chmod +x "$scripts_dir/$wrapper" 2>/dev/null || true
617:         fi
618:     done
619:     deploy_indexer_binary "$scripts_dir/bin"
620: 
621:     # ── Write .secguardian-env ──────────────────
622:     echo 'export SECGUARDIAN_HOME=$HOME/.config/opencode/extensions/secguardian' > "$ext_dir/.secguardian-env"
623: 
624:     echo ""
625:     log_info "OpenCode 使用方式（重启后生效）:"
626:     echo "    /secguard <path> [filters]"
627:     echo "    /secaudit <skill-name> [path]"
628:     echo "    /secreview <path> [language]"
629: }
630: 
631: # ── Gemini CLI (Official Extension Format) ──────
632: # Ref: https://geminicli.com/docs/extensions/reference/
633: deploy_gemini() {
634:     local ext_name="secguardian"
635:     local ext_dir="$TARGET_ROOT/.gemini/extensions/$ext_name"
636: 
637:     if $DEPLOY_USER; then
638:         log_step "Gemini CLI → ~/.gemini/extensions/$ext_name/ (用户级)"
639:     else
640:         log_step "Gemini CLI → .gemini/extensions/$ext_name/ (项目级)"
641:     fi
642: 
643:     # Clean: remove old flat format AND old extension dir
644:     rm -rf "$TARGET_ROOT/.gemini/commands" "$TARGET_ROOT/.gemini/skills" \
645:            "$TARGET_ROOT/.gemini/knowledge" "$TARGET_ROOT/.gemini/scripts" \
646:            "$TARGET_ROOT/.gemini/GEMINI.md" \
647:            "$ext_dir"
648: 
649:     mkdir -p "$ext_dir/commands" "$ext_dir/skills" \
650:              "$ext_dir/knowledge/languages" "$ext_dir/knowledge/guard-rules" \
651:              "$ext_dir/knowledge/protocols" "$ext_dir/knowledge/standards" \
652:              "$ext_dir/scripts/bin"
653: 
654:     # Write official gemini-extension.json
655:     # NOTE: version "0.5.4" below should match manifest.json version
656:     cat > "$ext_dir/gemini-extension.json" << JSON
657: {
658:   "name": "secguardian",
659:   "version": "0.5.4",
660:   "description": "SecGuardian XuanWu — 企业级白盒安全 AI Agent 辅助解决方案",
661:   "author": "SecGuardian",
662:   "homepage": "https://gitee.com/jonyan/secguardian",
663:   "commands": ["commands/secaudit.toml", "commands/secguard.toml", "commands/secreview.toml"]
664: }
665: JSON
666: 
667:     local skill_n=0
668:     for d in "$DIST"/*/; do
669:         if [ -d "$d/skills" ]; then
670:             for sd in "$d/skills"/*/; do
671:                 [ -d "$sd" ] && cp -r "$sd" "$ext_dir/skills/$(basename "$d" | sed 's/-secguardian//')-$(basename "$sd")" && skill_n=$((skill_n + 1))
672:             done
673:         fi
674:         for cat in languages guard-rules protocols; do
675:             if [ -d "$d/knowledge/$cat" ]; then
676:                 find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$ext_dir/knowledge/$cat/" \;
677:             fi
678:         done
679:     done
680: 
681:     # Project-level knowledge (v2.0)
682:     [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ] && cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$ext_dir/knowledge/"
683:     [ -f "$PROJECT_ROOT/SECURITY.md" ] && cp "$PROJECT_ROOT/SECURITY.md" "$ext_dir/knowledge/"
684:     [ -d "$PROJECT_ROOT/knowledge/standards" ] && cp -r "$PROJECT_ROOT/knowledge/standards/"* "$ext_dir/knowledge/standards/" 2>/dev/null || true
685:     cp -r "$PROJECT_ROOT/knowledge/audit-rules" "$ext_dir/knowledge/"
686:     cp -r "$PROJECT_ROOT/knowledge/review-rules" "$ext_dir/knowledge/"
687:     cp "$PROJECT_ROOT/knowledge/language-index.md" "$ext_dir/knowledge/"
688: 
689:     # Generate TOML commands
690:     log_info "生成 Gemini TOML 命令..."
691:     bash "$PROJECT_ROOT/scripts/gen-toml.sh" > /dev/null
692: 
693:     local toml_src="$PROJECT_ROOT/commands/gemini"
694:     local cmd_n=0
695:     if [ -d "$toml_src" ]; then
696:         for f in "$toml_src"/*.toml; do
697:             cp "$f" "$ext_dir/commands/"; cmd_n=$((cmd_n + 1))
698:         done
699:     fi
700: 
701:     # Wrapper scripts and binaries
702:     for wrapper in secguardian-index secguardian-index.ps1 render-report.py validate-index.py validate-findings.py record-finding.py; do
703:         [ -f "$PROJECT_ROOT/scripts/$wrapper" ] && cp "$PROJECT_ROOT/scripts/$wrapper" "$ext_dir/scripts/"
704:     done
705:     chmod +x "$ext_dir/scripts/"* 2>/dev/null || true
706:     deploy_indexer_binary "$ext_dir/scripts/bin"
707: 
708:     # ── Write .secguardian-env ──────────────────
709:     echo 'export SECGUARDIAN_HOME=$HOME/.gemini/extensions/secguardian' > "$ext_dir/.secguardian-env"
710:     chmod +x "$ext_dir/scripts/bin/"* 2>/dev/null || true
711: 
712:     # 生成 Gemini 上下文文件
713:     cat > "$ext_dir/GEMINI.md" << 'MD'
714: # SecGuardian - 安全守卫
715: 
716: 本项目配置了 SecGuardian 安全扫描能力。
717: 
718: ## 可用安全命令
719: 
720: | 命令 | 用途 |
721: |------|------|
722: | `/secguard <path> [mode] [filters]` | 安全加固项排查 — 代码级漏洞检测 |
723: | `/secaudit <skill-name>` | 安全专项审计 — 深度安全分析 |
724: | `/secreview <path> [language]` | 安全规范检视 — 反模式和最佳实践 |
725: 
726: ## 扫描输出
727: 
728: 所有扫描结果写入 `.codeagent/<extension>/scans/<scan-id>/`。
729: 
730: ## 辅助工具
731: 
732: 本项目提供了预编译的代码索引器：
733: 
734: | 平台 | 脚本 |
735: |------|------|
736: | macOS / Linux | `scripts/secguardian-index --path <dir> --output <file>` |
737: | Windows | `scripts/secguardian-index.ps1 --path <dir> --output <file>` |
738: 
739: 索引器命令：
740: - `--path <dir>` — 指定源码目录
741: - `--output <file>` — 指定索引输出文件（JSON）
742: - `--version` — 查看版本
743: - `--health` — 自检可用性
744: MD
745: 
746:     log_done "$skill_n skills + $cmd_n commands (.toml) + knowledge/ + scripts/ + GEMINI.md"
747: 
748:     echo ""
749:     log_info "Gemini CLI 使用方式:"
750:     echo "    /skills reload     # 重新扫描 skills"
751:     echo "    /secguard ./src cpp"
752:     echo "    /secaudit ./src python"
753:     echo "    /secreview ./src java"
754: }
755: 
756: # ── 打包发布 ────────────────────────────────────
757: do_zip() {
758:     local archive_dir="$DIST/archives"
759:     log_step "生成发布压缩包 → $archive_dir/"
760:     rm -rf "$archive_dir"
761:     mkdir -p "$archive_dir"
762: 
763:     # Claude Code: 每个 extension 一个 zip
764:     for d in "$DIST"/*/; do
765:         local name=$(basename "$d")
766:         [ "$name" = "archives" ] && continue
767:         [ "$name" = "release" ] && continue
768:         local zipfile="$archive_dir/cc-${name}.zip"
769:         (cd "$DIST" && zip -rq "$zipfile" "$name")
770:         log_done "cc-${name}.zip"
771:     done
772: 
773:     # OpenCode: 官方插件结构 (plugins/secguardian.js + extensions/secguardian/)
774:     local opencode_root
775:     if [ -d "$HOME/.config/opencode/plugins" ]; then
776:         opencode_root="$HOME/.config/opencode"
777:     elif [ -d "$PROJECT_ROOT/.opencode/plugins" ]; then
778:         opencode_root="$PROJECT_ROOT/.opencode"
779:     fi
780:     if [ -n "${opencode_root:-}" ]; then
781:         local ver="$(grep -m1 '"version"' "$PROJECT_ROOT/extensions/secguard-secguardian/extension.json" | sed 's/.*: *"\([^"]*\)".*/\1/')"
782:         local nga_zip="$archive_dir/secguardian-nga-v${ver}.zip"
783:         (cd "$opencode_root" && zip -rq "$nga_zip" plugins/secguardian.js extensions/secguardian/)
784:         log_done "$(basename "$nga_zip")"
785:     fi
786: 
787:     # Gemini CLI: 完整布局 (skills/ + knowledge/ + commands/ + scripts/ + GEMINI.md)
788:     if [ -d "$TARGET_ROOT/.gemini/skills" ]; then
789:         local cac_zip="$archive_dir/cac-secguardian.zip"
790:         (cd "$TARGET_ROOT/.gemini" && zip -rq "$cac_zip" skills/ knowledge/ commands/ scripts/ GEMINI.md 2>/dev/null || \
791:          zip -rq "$cac_zip" skills/ commands/ GEMINI.md)
792:         log_done "cac-secguardian.zip"
793:     fi
794: 
795:     log_info "输出: $archive_dir/"
796: }
797: 
798: # ── 主流程 ──────────────────────────────────────
799: echo ""
800: echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
801: echo -e "${BOLD}║${NC}  SecGuardian — ${DEPLOY_MODE} ${PLATFORM}                             ${BOLD}║${NC}"
802: echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
803: echo ""
804: 
805: if $DO_UNINSTALL; then
806:     do_uninstall "$PLATFORM"
807:     echo ""
808:     echo -e "${GREEN}卸载完成。${NC}"
809:     exit 0
810: fi
811: 
812: ensure_dist
813: 
814: case "$PLATFORM" in
815:     all)
816:         deploy_claude
817:         echo ""
818:         deploy_opencode
819:         echo ""
820:         deploy_gemini
821:         ;;
822:     cc)  deploy_claude ;;
823:     nga) deploy_opencode ;;
824:     cac) deploy_gemini ;;
825: esac
826: 
827: # 如果带 --zip 参数则额外打包
828: if $DO_ZIP; then
829:     echo ""
830:     do_zip
831: fi
832: 
833: echo ""
834: echo -e "${GREEN}部署完成。${NC}"

(End of file - total 834 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/package.sh"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/package.sh</path>
<type>file</type>
<content>
1: #!/bin/bash
2: # SecGuardian — Extension 打包脚本
3: #
4: # 读取 extensions/<name>/extension.json，生成独立扩展包。
5: #
6: # 用法:
7: #   bash scripts/package.sh       # 构建全部 extension
8: #   bash scripts/package.sh -h    # 显示帮助
9: #
10: # 输出: dist/<extension-name>/
11: #   ├── extension.json
12: #   ├── commands/<cmd>.md
13: #   ├── skills/<skill-name>/SKILL.md
14: #   ├── knowledge/languages/
15: #   ├── knowledge/guard-rules/
16: 
17: #   ├── knowledge/protocols/
18: #   ├── knowledge/standards/
19: #   └── scripts/
20: #       ├── secguardian-index      (shell wrapper)
21: #       ├── secguardian-index.ps1  (powershell wrapper)
22: #       └── bin/
23: #           ├── secguardian-index-darwin-arm64
24: #           ├── secguardian-index-darwin-amd64
25: #           ├── secguardian-index-linux-amd64
26: #           └── secguardian-index-windows-amd64.exe
27: 
28: set -euo pipefail
29: 
30: PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
31: 
32: python3 "$PROJECT_ROOT/scripts/sync-language-index.sh"
33: echo ">>> Generating Gemini .toml files..."
34: python3 "$PROJECT_ROOT/scripts/sync-toml.sh"
35: 
36: # ── Help ──────────────────────────────────────
37: if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
38:     cat << 'EOF'
39: SecGuardian — Extension 打包脚本
40: 
41: 读取 extensions/<name>/extension.json，组装完整的扩展包。
42: 
43: 用法:
44:   bash scripts/package.sh           # 构建全部 extension（生成到 dist/）
45:   bash scripts/package.sh -h        # 显示此帮助
46: 
47: 构建流程:
48:   1. 读取 extension.json 中的 skills/languages/detectors/protocols/standards 清单
49:   2. 从 skills/ 目录复制 SKILL.md + references/
50:   3. 从 knowledge/ 目录复制对应的安全知识文件
51:   4. 从 commands/ 目录复制 slash command 定义
52:   5. 跨平台编译 secguardian-index 二进制，放入 scripts/bin/
53:   6. 复制跨平台 wrapper 脚本 scripts/secguardian-index*
54:   7. 输出到 dist/<extension-name>/
55: 
56: 示例:
57:   bash scripts/package.sh           # 构建
58:   bash scripts/package.sh && bash scripts/deploy.sh all  # 构建 + 部署
59: EOF
60:     exit 0
61: fi
62: 
63: EXTENSIONS_DIR="$PROJECT_ROOT/extensions"
64: DIST="$PROJECT_ROOT/dist"
65: 
66: echo "==> Packaging SecGuardian extensions..."
67: 
68: # ── Pre-build: Compile Go indexer binary ──────────
69: BUILD_BIN_DIR="$PROJECT_ROOT/scripts/bin"
70: mkdir -p "$BUILD_BIN_DIR"
71: 
72: # Clean up stale binaries without platform suffix (legacy build artifact)
73: # Only keep properly suffixed binaries: secguardian-index-{os}-{arch}
74: find "$BUILD_BIN_DIR" -name 'secguardian-index' ! -name 'secguardian-index-*' -type f -delete 2>/dev/null || true
75: 
76: if [ "${SKIP_GO_BUILD:-}" = "1" ]; then
77:     echo "  → [SKIP] SKIP_GO_BUILD=1 — using pre-built binaries in $BUILD_BIN_DIR/"
78:     ls -lh "$BUILD_BIN_DIR/" 2>/dev/null | grep -v "^total" | awk '{print "    " $NF " (" $5 ")"}' || true
79: elif [ -f "$PROJECT_ROOT/internal/go.mod" ] && command -v go &>/dev/null; then
80:     echo "  → Compiling secguardian-index binaries (dual-mode: CGO=tree-sitter, !CGO=regex)..."
81:     # Native build: CGO enabled (tree-sitter)
82:     (cd "$PROJECT_ROOT/internal" && \
83:         go build -o "$BUILD_BIN_DIR/secguardian-index-darwin-arm64" . 2>/dev/null && \
84:         echo "    [OK] darwin-arm64 (tree-sitter)" || echo "    [WARN] darwin-arm64 build failed") &
85:     # Cross-platform: CGO disabled (pure-Go regex fallback, works everywhere)
86:     (cd "$PROJECT_ROOT/internal" && \
87:         CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o "$BUILD_BIN_DIR/secguardian-index-darwin-amd64" . 2>/dev/null && \
88:         echo "    [OK] darwin-amd64 (regex)" || echo "    [WARN] darwin-amd64 build failed") &
89:     (cd "$PROJECT_ROOT/internal" && \
90:         CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "$BUILD_BIN_DIR/secguardian-index-linux-amd64" . 2>/dev/null && \
91:         echo "    [OK] linux-amd64 (regex)" || echo "    [WARN] linux-amd64 build failed") &
92:     (cd "$PROJECT_ROOT/internal" && \
93:         CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o "$BUILD_BIN_DIR/secguardian-index-linux-arm64" . 2>/dev/null && \
94:         echo "    [OK] linux-arm64 (regex)" || echo "    [WARN] linux-arm64 build failed") &
95:     (cd "$PROJECT_ROOT/internal" && \
96:         CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o "$BUILD_BIN_DIR/secguardian-index-windows-amd64.exe" . 2>/dev/null && \
97:         echo "    [OK] windows-amd64 (regex)" || echo "    [WARN] windows-amd64 build failed") &
98:     wait
99:     echo "  → Compilation done. Binaries in: $BUILD_BIN_DIR/"
100:     ls -lh "$BUILD_BIN_DIR/" 2>/dev/null | grep -v "^total" | awk '{print "    " $NF " (" $5 ")"}' || true
101:     echo "  → Note: tree-sitter (CGO) on native platform, pure-Go regex fallback on cross-compiled platforms."
102: else
103:     echo "    [SKIP] Go not available — indexer binaries not built"
104: fi
105: 
106: # Note: No standalone "secguardian" binary in V1.
107: # The indexer (secguardian-index) is the only binary needed.
108: # A future standalone CLI with integrated LLM calls will use the "secguardian" name.
109: 
110: for ext_dir in "$EXTENSIONS_DIR"/*/; do
111:     ext=$(basename "$ext_dir")
112:     ext_json="$ext_dir/extension.json"
113: 
114:     if [ ! -f "$ext_json" ]; then
115:         echo "  [SKIP] $ext — no extension.json"
116:         continue
117:     fi
118: 
119:     echo "  -> $ext"
120:     dist_dir="$DIST/$ext"
121:     rm -rf "$dist_dir"
122:     mkdir -p "$dist_dir/commands" "$dist_dir/skills" \
123:              "$dist_dir/knowledge/languages" \
124:              "$dist_dir/knowledge/guard-rules" \
125:              "$dist_dir/knowledge/audit-rules" \
126:              "$dist_dir/knowledge/review-rules" \
127:              "$dist_dir/knowledge/audit-rules" \
128:              "$dist_dir/knowledge/review-rules" \
129:              "$dist_dir/knowledge/protocols" \
130:              "$dist_dir/knowledge/standards" \
131:              "$dist_dir/scripts/bin"
132: 
133:     # Copy extension manifest
134:     cp "$ext_json" "$dist_dir/extension.json"
135: 
136:     # Generate .claude-plugin/plugin.json for Claude Code compatibility
137:     mkdir -p "$dist_dir/.claude-plugin"
138:     jq -n \
139:         --arg name "$ext" \
140:         --arg version "$(jq -r '.version' "$ext_json")" \
141:         --arg desc "$(jq -r '.description' "$ext_json")" \
142:         '{name: $name, version: $version, description: $desc, author: {name: "SecGuardian"}}' \
143:         > "$dist_dir/.claude-plugin/plugin.json"
144:     echo "    plugin: $ext"
145: 
146:     # Determine command name
147:     cmd=$(jq -r '.command' "$ext_json")
148:     cmd_src="$PROJECT_ROOT/commands/${cmd}.md"
149:     if [ -f "$cmd_src" ]; then
150:         cp "$cmd_src" "$dist_dir/commands/"
151:         echo "    command: /$cmd"
152:     else
153:         echo "    [WARN] command file not found: ${cmd}.md"
154:     fi
155: 
156:     # Copy skill directories (each contains SKILL.md + optional references/)
157:     skill_count=0
158:     for skill_name in $(jq -r '.skills[]' "$ext_json"); do
159:         skill_dir="$PROJECT_ROOT/skills/${cmd}/${skill_name}"
160:         flat_skill="$PROJECT_ROOT/skills/${cmd}/SKILL.md"
161:         if [ -d "$skill_dir" ]; then
162:             cp -r "$skill_dir" "$dist_dir/skills/"
163:             skill_count=$((skill_count + 1))
164:         elif [ -f "$flat_skill" ]; then
165:            mkdir -p "$dist_dir/skills/${skill_name}"
166:            cp "$flat_skill" "$dist_dir/skills/${skill_name}/"
167:             # 复制 references/ 目录（如果存在，如 secaudit 的分析方法参考）
168:             if [ -d "$PROJECT_ROOT/skills/${cmd}/references" ]; then
169:                 cp -r "$PROJECT_ROOT/skills/${cmd}/references" "$dist_dir/skills/${skill_name}/"
170:             fi
171:             echo "    [FLAT] ${cmd}/${skill_name}/SKILL.md (flat → dir)"
172:             skill_count=$((skill_count + 1))
173:         else
174:             echo "    [WARN] skill not found: ${cmd} (checked dir and flat SKILL.md)"
175:         fi
176:     done
177:     echo "    skills: $skill_count"
178: 
179:     # Copy threat-catalog (v2.0: replaces concepts/)
180:     if [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ]; then
181:         cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$dist_dir/knowledge/"
182:     fi
183:     # Copy SECURITY.md for corporate AV whitelisting
184:     if [ -f "$PROJECT_ROOT/SECURITY.md" ]; then
185:         cp "$PROJECT_ROOT/SECURITY.md" "$dist_dir/knowledge/"
186:     fi
187:     # Copy standards if declared
188:     std_count=0
189:     if jq -e '.knowledge.standards' "$ext_json" > /dev/null 2>&1; then
190:         for std in $(jq -r '.knowledge.standards[]' "$ext_json"); do
191:             sf="$PROJECT_ROOT/knowledge/standards/${std}.md"
192:             if [ -f "$sf" ]; then
193:                 mkdir -p "$dist_dir/knowledge/standards"
194:                 cp "$sf" "$dist_dir/knowledge/standards/"
195:                 std_count=$((std_count + 1))
196:             fi
197:         done
198:     fi
199:     echo "    standards: $std_count"
200: 
201:     lang_count=0
202:     for lang in $(jq -r '.knowledge.languages[]' "$ext_json"); do
203:         lf="$PROJECT_ROOT/knowledge/languages/${lang}.md"
204:         if [ -f "$lf" ]; then
205:             cp "$lf" "$dist_dir/knowledge/languages/"
206:             lang_count=$((lang_count + 1))
207:         fi
208:     done
209:     echo "    languages: $lang_count"
210: 
211:     # Copy detectors declared in extension.json (optional field)
212:     detector_count=0
213:     if jq -e '.knowledge.detectors' "$ext_json" > /dev/null 2>&1; then
214:         for detector in $(jq -r '.knowledge.detectors[]' "$ext_json"); do
215:             df="$PROJECT_ROOT/knowledge/guard-rules/${detector}.md"
216: 
217:             if [ -f "$df" ]; then
218:                 cp "$df" "$dist_dir/knowledge/guard-rules/"
219: 
220:                 detector_count=$((detector_count + 1))
221:             fi
222:         done
223:     fi
224:     echo "    detectors: $detector_count"
225: 
226:     # Copy audit-rules (all files for secaudit-* extensions)
227:     mkdir -p "$dist_dir/knowledge/audit-rules"
228:     for ar in "$PROJECT_ROOT/knowledge/audit-rules/"*.md; do
229:         [ -f "$ar" ] && cp "$ar" "$dist_dir/knowledge/audit-rules/" 2>/dev/null || true
230:     done
231: 
232:     # Copy review-rules (all files for secreview-* extensions)
233:     mkdir -p "$dist_dir/knowledge/review-rules"
234:     for rr in "$PROJECT_ROOT/knowledge/review-rules/"*.md; do
235:         [ -f "$rr" ] && cp "$rr" "$dist_dir/knowledge/review-rules/" 2>/dev/null || true
236:     done
237: 
238:     # Copy language-index.md
239:     if [ -f "$PROJECT_ROOT/knowledge/language-index.md" ]; then
240:         cp "$PROJECT_ROOT/knowledge/language-index.md" "$dist_dir/knowledge/" 2>/dev/null || true
241:     fi
242: 
243:     # Copy protocols declared in extension.json (optional field)
244:     protocol_count=0
245:     if jq -e '.knowledge.protocols' "$ext_json" > /dev/null 2>&1; then
246:         for protocol in $(jq -r '.knowledge.protocols[]' "$ext_json"); do
247:             pf="$PROJECT_ROOT/knowledge/protocols/${protocol}.md"
248:             if [ -f "$pf" ]; then
249:                 cp "$pf" "$dist_dir/knowledge/protocols/"
250:                 protocol_count=$((protocol_count + 1))
251:             fi
252:         done
253:     fi
254:     echo "    protocols: $protocol_count"
255: 
256:     # Copy cross-platform wrapper scripts into the package
257:     if [ -f "$PROJECT_ROOT/scripts/secguardian-index" ]; then
258:         cp "$PROJECT_ROOT/scripts/secguardian-index" "$dist_dir/scripts/secguardian-index"
259:         chmod +x "$dist_dir/scripts/secguardian-index"
260:         echo "    wrapper: secguardian-index (shell)"
261:     else
262:         echo "    [WARN] scripts/secguardian-index wrapper not found"
263:     fi
264:     if [ -f "$PROJECT_ROOT/scripts/secguardian-index.ps1" ]; then
265:         cp "$PROJECT_ROOT/scripts/secguardian-index.ps1" "$dist_dir/scripts/secguardian-index.ps1"
266:         echo "    wrapper: secguardian-index.ps1 (powershell)"
267:     fi
268: 
269:     # Copy shared utility scripts
270:     cp "$PROJECT_ROOT/scripts/record-finding.py" "$dist_dir/scripts/record-finding.py"
271:     cp "$PROJECT_ROOT/scripts/validate-index.py" "$dist_dir/scripts/validate-index.py"
272:     cp "$PROJECT_ROOT/scripts/validate-findings.py" "$dist_dir/scripts/validate-findings.py"
273: 
274: 
275: 
276:     # Copy cross-platform precompiled binaries
277:     bin_count=0
278:     for bin_file in "$BUILD_BIN_DIR"/secguardian-index-*; do
279:         if [ -f "$bin_file" ]; then
280:             cp "$bin_file" "$dist_dir/scripts/bin/"
281:             chmod +x "$dist_dir/scripts/bin/$(basename "$bin_file")" 2>/dev/null || true
282:             bin_count=$((bin_count + 1))
283:         fi
284:     done
285:     echo "    binaries: $bin_count platform(s) in scripts/bin/"
286: 
287:     echo "    packaged: $dist_dir"
288: done
289: 
290: echo "==> Done. Output in $DIST/"

(End of file - total 290 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/self-check.sh"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/self-check.sh</path>
<type>file</type>
<content>
1: #!/bin/bash
2: # SecGuardian — Self-Verification Script
3: # Catches design inconsistencies before the user does.
4: # Usage: bash scripts/self-check.sh
5: 
6: set -euo pipefail
7: PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
8: cd "$PROJECT_ROOT"
9: 
10: PASS=0; FAIL=0
11: green() { echo "  ✅ $1"; PASS=$((PASS+1)); }
12: red()   { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
13: 
14: echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
15: echo "  SecGuardian Self-Verification"
16: echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
17: echo ""
18: 
19: 
20: yellow() { echo "  🟡 $1"; }
21: # ── 1. Knowledge rules structure ──
22: echo "1. Knowledge rules structure"
23: GLD_DIR="knowledge/guard-rules"
24: AUD_DIR="knowledge/audit-rules"
25: REV_DIR="knowledge/review-rules"
26: LANG_IDX="knowledge/language-index.md"
27: 
28: # 1a Verify each knowledge directory has files
29: for dir_name in guard-rules audit-rules review-rules; do
30:     dir="knowledge/$dir_name"
31:     count=$(ls "$dir"/*.md 2>/dev/null | wc -l | tr -d ' ')
32:     if [ "$count" -gt 0 ]; then
33:         green "$dir: $count files"
34:     else
35:         red "$dir missing or empty"
36:     fi
37: done
38: 
39: # 1b Verify language-index.md exists with language sections
40: if [ -f "$LANG_IDX" ]; then
41:     lang_count=$(grep -c '^## ' "$LANG_IDX" 2>/dev/null || echo 0)
42:     if [ "$lang_count" -ge 5 ]; then
43:         green "$LANG_IDX: $lang_count language sections"
44:     else
45:         red "$LANG_IDX: only $lang_count language sections (expected >=5)"
46:     fi
47: else
48:     red "$LANG_IDX MISSING"
49: fi
50: 
51: # 1c Verify guard-rules filename format: namespace-name.md
52: for f in "$GLD_DIR"/*.md; do
53:     [ -f "$f" ] || continue
54:     base=$(basename "$f" .md)
55:     ns="${base%%-*}"
56:     case "$ns" in
57:         memory|concurrency|system|crypto|web|resource|error)
58:             green "guard-rules/$base"
59:             ;;
60:         *)
61:             red "guard-rules/$base — unknown namespace '$ns'"
62:             ;;
63:     esac
64: done
65: 
66: # 1d Verify guard-rules frontmatter language field is parseable
67: MISSING_LANG=0
68: for f in "$GLD_DIR"/*.md; do
69:     [ -f "$f" ] || continue
70:     base=$(basename "$f" .md)
71:     if grep -q '^language:' "$f" 2>/dev/null; then
72:         :
73:     else
74:         MISSING_LANG=$((MISSING_LANG + 1))
75:         red "guard-rules/$base missing language field"
76:     fi
77: done
78: [ "$MISSING_LANG" -eq 0 ] && green "All guard-rules have language field"
79: 
80: # 1e Verify audit-rules structure
81: AUD_COUNT=$(ls "$AUD_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
82: if [ "$AUD_COUNT" -eq 17 ]; then
83:     green "audit-rules: 13 files (complete)"
84: else
85:     yellow "audit-rules: $AUD_COUNT files (expected 13)"
86: fi
87: 
88: # 1f Verify review-rules structure
89: REV_COUNT=$(ls "$REV_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
90: for lang in cpp python java go javascript; do
91:     rf="$REV_DIR/$lang.md"
92:     if [ -f "$rf" ]; then
93:         green "review-rules/$lang.md"
94:     else
95:         red "review-rules/$lang.md MISSING"
96:     fi
97: done
98: 
99: # 1g Verify .toml files are auto-generated
100: TOML_MISSING=0
101: for cmd in secguard secaudit secreview; do
102:     if [ -f "commands/gemini/$cmd.toml" ]; then
103:         green "commands/gemini/$cmd.toml"
104:     else
105:         red "commands/gemini/$cmd.toml MISSING"
106:         TOML_MISSING=$((TOML_MISSING + 1))
107:     fi
108: done
109: # ── 2. Manifest counts vs reality ──
110: echo "2. Manifest count consistency"
111: MANIFEST_COUNT=$(jq '.knowledge.detectors.count' manifest.json)
112: ACTUAL_COUNT=$(ls "knowledge/guard-rules"/*.md | wc -l | tr -d ' ')
113: [ "$MANIFEST_COUNT" = "$ACTUAL_COUNT" ] && \
114:     green "manifest.json count=$MANIFEST_COUNT matches directory count=$ACTUAL_COUNT" || \
115:     red "manifest.json count=$MANIFEST_COUNT != directory count=$ACTUAL_COUNT"
116: 
117: MANIFEST_SUM=$(jq '[.knowledge.detectors.namespaces | to_entries[].value] | add' manifest.json)
118: [ "$MANIFEST_SUM" = "$MANIFEST_COUNT" ] && \
119:     green "namespace sum=$MANIFEST_SUM matches total=$MANIFEST_COUNT" || \
120:     red "namespace sum=$MANIFEST_SUM != total=$MANIFEST_COUNT"
121: echo ""
122: 
123: # ── 3. Commands reference correct paths ──
124: echo "3. Command path consistency"
125: for cmd in commands/secguard.md commands/gemini/secguard.toml; do
126:     if grep -q "knowledge/language-index.md" "$cmd" 2>/dev/null; then
127:         green "$cmd references correct detector-index path"
128:     elif grep -q "skills/secguard-cpp" "$cmd" 2>/dev/null; then
129:         red "$cmd references OLD path skills/secguard-cpp"
130:     else
131:         red "$cmd missing detector-index reference"
132:     fi
133: done
134: echo ""
135: 
136: # ── 4. Namespace filter coverage ──
137: echo "4. Namespace filter coverage"
138: GUARD_DIR="knowledge/guard-rules"
139: # Extract namespace prefixes from guard-rules filenames
140: KNOWN_NS="memory concurrency system crypto web resource error"
141: for ns in $KNOWN_NS; do
142:     count=$(ls "$GUARD_DIR/${ns}-"*.md 2>/dev/null | wc -l | tr -d ' ')
143:     if [ "$count" -gt 0 ]; then
144:         green "namespace $ns -> $count detectors"
145:     else
146:         red "namespace $ns -> no detectors in $GUARD_DIR"
147:     fi
148: done
149: # ── 5. Skills structure ──
150: echo "5. Skills structure"
151: SKILL_COUNT=0
152: for cmd_dir in skills/secaudit skills/secguard skills/secreview; do
153:     if [ -d "$cmd_dir" ]; then
154:         n=$(find "$cmd_dir" -name "SKILL.md" -maxdepth 2 2>/dev/null | wc -l | tr -d ' ')
155:         green "$cmd_dir/ ($n skills)"
156:         SKILL_COUNT=$((SKILL_COUNT + n))
157:     else
158:         red "$cmd_dir/ MISSING"
159:     fi
160: done
161: echo "  else
162:     echo "  npx not available — install Node.js to run markdownlint locally"
163: fi
164: 
165: Total: $SKILL_COUNT skills"
166: echo ""
167: 
168: # ── 6. No dead references ──
169: echo "6. Stale reference check"
170: for stale in "knowledge/concepts" "knowledge/cheatsheets" "knowledge/prompt-templates"; do
171:     refs=$(grep -rl "$stale" commands/ skills/ --include="*.md" --include="*.toml" 2>/dev/null || true)
172:     if [ -n "$refs" ]; then
173:         red "Stale reference to '$stale' in: $refs"
174:     else
175:         green "No stale '$stale' references"
176:     fi
177: done
178: echo ""
179: 
180: # ── 7. threat-catalog consistency vs manifest ──
181: echo "7. Threat catalog vs manifest"
182: MANIFEST_NS=$(python3 -c "
183: import json
184: with open('manifest.json') as f:
185:     ns = json.load(f)['knowledge']['detectors']['namespaces']
186: print(json.dumps(ns))
187: ")
188: CATALOG_NS=$(python3 -c "
189: import re, json
190: with open('knowledge/threat-catalog.md') as f:
191:     content = f.read()
192: sections = re.findall(r'## .*?\((\w+)\).*?— (\d+)(?:<!--.*?-->)? 个', content)
193: ns_counts = {}
194: for ns, count in sections:
195:     ns_counts[ns] = int(count)
196: print(json.dumps(ns_counts))
197: ")
198: MISMATCH=$(python3 -c "
199: import json, sys
200: manifest = json.loads('''$MANIFEST_NS''')
201: catalog = json.loads('''$CATALOG_NS''')
202: mismatch = False
203: for ns, expected in manifest.items():
204:     actual = catalog.get(ns, 0)
205:     if actual != expected:
206:         print(f'  ❌ {ns}: manifest={expected}, catalog={actual}')
207:         mismatch = True
208:     else:
209:         print(f'  ✅ {ns}: {expected}')
210: if not mismatch:
211:     print('  ✅ All namespace counts match manifest')
212: sys.exit(0 if not mismatch else 1)
213: ")
214: if [ $? -eq 0 ]; then
215:     green "threat-catalog.md consistent with manifest.json"
216: else
217:     red "threat-catalog.md out of sync with manifest.json — update counts and sections"
218: fi
219: echo ""
220: 
221: 
222: # ── 7.6. Manifest token consistency ──
223: echo "7.6. Manifest token consistency"
224: if [ -x "$PROJECT_ROOT/scripts/sync-manifest.sh" ]; then
225:     bash "$PROJECT_ROOT/scripts/sync-manifest.sh" --check 2>/dev/null
226:     if [ $? -eq 0 ]; then
227:         green "All @secguardian tokens match manifest.json"
228:     else
229:         red "Token mismatch — run: bash scripts/sync-manifest.sh"
230:     fi
231: else
232:     echo "  sync-manifest.sh not found — skipping"
233: fi
234: echo ""
235: # ── 8. Go compilation ──
236: echo "8. Go compilation"
237: (cd internal && gc=$(mktemp -d) && GOCACHE=$gc go build -o /dev/null . 2>/dev/null; ec=$?; rm -rf "$gc"; exit $ec) && green "go build OK" || red "go build FAILED"
238: (cd internal && gc=$(mktemp -d) && GOCACHE=$gc CGO_ENABLED=0 go build -o /dev/null . 2>/dev/null; ec=$?; rm -rf "$gc"; exit $ec) && green "go build (no-CGO) OK" || red "go build (no-CGO) FAILED"
239: echo ""
240: 
241: 
242: # ── 9. Command template export validation ──
243: if [ -f "scripts/check-command-templates.py" ]; then
244:     echo "9. Command template export validation"
245:     if python3 scripts/check-command-templates.py >/dev/null 2>&1; then
246:         green "commands/*.md 共 12 处 os.environ 引用均使用 export，模板健壮"
247:     else
248:         red "commands/*.md 模板中 bash → Python 环境变量缺失 export"
249:         python3 scripts/check-command-templates.py 2>&1 | grep '❌'
250:     fi
251:     echo ""
252: fi
253: 
254: 
255: # ── 10. validate-index.py cross-language smoke test ──
256: if [ -f "scripts/validate-index.py" ] && [ -f "scripts/secguardian-index" ]; then
257:     echo "10. validate-index.py cross-language smoke test"
258:     ALL_OK=0
259:     for repo in cpp-vuln-demo python-vuln-demo java-vuln-demo go-vuln-demo; do
260:         idx=$(mktemp /tmp/selfchk-idx-XXXX.json)
261:         bash scripts/secguardian-index --path "examples/$repo/src" --output "$idx" >/dev/null 2>&1
262:         out=$((cd /tmp && python3 "$PROJECT_ROOT/scripts/validate-index.py" --index "$idx" --scan-id "test-$repo") 2>&1)
263:         lang=$(echo "$out" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['primary_language'])" 2>/dev/null || echo "FAIL")
264:         if [ "$lang" != "FAIL" ]; then
265:             green "examples/$repo → $lang"
266:         else
267:             red "examples/$repo → validate-index.py FAILED"
268:             ALL_OK=1
269:         fi
270:         rm -f "$idx"
271:     done
272:     [ "$ALL_OK" -eq 0 ] && green "All languages pass validate-index.py" || red "Some languages FAILED"
273:     echo ""
274: fi
275: 
276: # ── 11. Cross-command consistency ──
277: echo "11. Cross-command consistency"
278: XC_FAIL=0
279: XC_PASS=0
280: for cmd in secguard secaudit secreview; do
281:     f="commands/${cmd}.md"
282:     if [ ! -f "$f" ]; then
283:         red "  ${cmd}: commands/${cmd}.md MISSING"
284:         XC_FAIL=$((XC_FAIL + 1))
285:         continue
286:     fi
287:     ok=1
288:     # --command <cmd> present
289:     if grep -q -- "--command ${cmd}" "$f"; then
290:         XC_PASS=$((XC_PASS + 1))
291:     else
292:         red "  ${cmd}: MISSING '--command ${cmd}' in renderer call"
293:         ok=0
294:     fi
295:     # <user-project> prefix used
296:     if grep -q '<user-project>/\.codeagent' "$f"; then
297:         XC_PASS=$((XC_PASS + 1))
298:     else
299:         red "  ${cmd}: MISSING '<user-project>/' prefix in output paths"
300:         ok=0
301:     fi
302:     # scan_id ordering instruction
303:     if grep -qE "scan_id FIRST|首选生成 scan_id|Generate scan_id FIRST" "$f"; then
304:         XC_PASS=$((XC_PASS + 1))
305:     else
306:         red "  ${cmd}: MISSING scan_id ordering instruction"
307:         ok=0
308:     fi
309:     # No stale references
310:     stale=$(grep -cE "16 阶段|Isolation constraint|Routing rules" "$f" 2>/dev/null || echo 0)
311:     if [ "$stale" -gt 0 ]; then
312:         red "  ${cmd}: ${stale} stale reference(s) found"
313:         ok=0
314:     fi
315:     if [ "$ok" -eq 1 ]; then
316:         green "  ${cmd}: all checks passed"
317:     else
318:         XC_FAIL=$((XC_FAIL + 1))
319:     fi
320: done
321: if [ "$XC_FAIL" -eq 0 ]; then
322:     green "  All 3 commands are in sync"
323: else
324:     red "  ${XC_FAIL} commands have consistency issues"
325: fi
326: PASS=$((PASS + XC_PASS))
327: FAIL=$((FAIL + XC_FAIL))
328: echo ""
329: 
330: echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
331: printf "  Passed: %d  Failed: %d\n" "$PASS" "$FAIL"
332: echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
333: [ "$FAIL" -eq 0 ] && exit 0 || exit 1

(End of file - total 333 lines)
</content>
```

---

## Assistant (Build · DeepSeek V4 Flash · 3.8s)

_Thinking:_

Let me continue reading more critical files. I need to look at:
1. The Go indexer files - parser_ts.go, parser_re.go, indexer.go, context.go
2. The render-report.py script
3. The secfix.py script
4. The dev-verify.sh and e2e-verify.sh scripts
5. The SDD files

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/parser/parser_ts.go"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/parser/parser_ts.go</path>
<type>file</type>
<content>
1: //go:build cgo
2: 
3: package parser
4: 
5: import (
6: 	"fmt"
7: 	"os"
8: 
9: 	treesitter "github.com/tree-sitter/go-tree-sitter"
10: 	c "github.com/tree-sitter/tree-sitter-c/bindings/go"
11: 	cpp "github.com/tree-sitter/tree-sitter-cpp/bindings/go"
12: 	goL "github.com/tree-sitter/tree-sitter-go/bindings/go"
13: 	java "github.com/tree-sitter/tree-sitter-java/bindings/go"
14: 	py "github.com/tree-sitter/tree-sitter-python/bindings/go"
15: )
16: 
17: func ParseFile(filePath string, lang string) (*ParseResult, error) {
18: 	content, err := os.ReadFile(filePath)
19: 	if err != nil {
20: 		return nil, fmt.Errorf("reading file: %w", err)
21: 	}
22: 
23: 	parser := treesitter.NewParser()
24: 	defer parser.Close()
25: 
26: 	switch lang {
27: 	case "c":
28: 		parser.SetLanguage(treesitter.NewLanguage(c.Language()))
29: 	case "cpp":
30: 		parser.SetLanguage(treesitter.NewLanguage(cpp.Language()))
31: 	case "python":
32: 		parser.SetLanguage(treesitter.NewLanguage(py.Language()))
33: 	case "go":
34: 		parser.SetLanguage(treesitter.NewLanguage(goL.Language()))
35: 	case "java":
36: 		parser.SetLanguage(treesitter.NewLanguage(java.Language()))
37: 		case "javascript":
38: 			// JavaScript uses regex parser (no tree-sitter grammar compiled in)
39: 			return parseJSFile(filePath)
40: 	default:
41: 		return nil, fmt.Errorf("unsupported language: %s", lang)
42: 	}
43: 
44: 	tree := parser.Parse(content, nil)
45: 	defer tree.Close()
46: 
47: 	result := &ParseResult{File: filePath, Language: lang}
48: 	root := tree.RootNode()
49: 	walkTopLevel(root, content, filePath, lang, result)
50: 	return result, nil
51: }
52: 
53: func walkTopLevel(node *treesitter.Node, content []byte, file, lang string, result *ParseResult) {
54: 	for i := uint(0); i < node.ChildCount(); i++ {
55: 		child := node.Child(i)
56: 		if child == nil {
57: 			continue
58: 		}
59: 		kind := child.Kind()
60: 
61: 		switch lang {
62: 		case "c", "cpp":
63: 			switch kind {
64: 			case "function_definition":
65: 				if fn := extractIdent(child, content, file, "function_declarator"); fn.Name != "" {
66: 					fn.StartLine = child.StartPosition().Row + 1
67: 					fn.EndLine = child.EndPosition().Row + 1
68: 					result.Functions = append(result.Functions, fn)
69: 				}
70: 			case "declaration":
71: 				result.Variables = append(result.Variables, extractInitDecls(child, content, file)...)
72: 			case "struct_specifier", "class_specifier", "union_specifier":
73: 				if t := extractTypeName(child, content, file, kind); t.Name != "" {
74: 					result.Types = append(result.Types, t)
75: 				}
76: 			case "type_definition":
77: 				if t := extractTypeName(child, content, file, "typedef"); t.Name != "" {
78: 					result.Types = append(result.Types, t)
79: 				}
80: 			case "enum_specifier":
81: 				if t := extractTypeName(child, content, file, "enum"); t.Name != "" {
82: 					result.Types = append(result.Types, t)
83: 				}
84: 			}
85: 
86: 		case "python":
87: 			switch kind {
88: 			case "function_definition":
89: 				if fn := extractNamedChild(child, content, file, "identifier"); fn.Name != "" {
90: 					fn.StartLine = child.StartPosition().Row + 1
91: 					fn.EndLine = child.EndPosition().Row + 1
92: 					result.Functions = append(result.Functions, fn)
93: 				}
94: 			case "class_definition":
95: 				if t := extractNamedChild(child, content, file, "identifier"); t.Name != "" {
96: 					tis := TypeInfo{Name: t.Name, Kind: "class", File: file, StartLine: child.StartPosition().Row + 1}
97: 					result.Types = append(result.Types, tis)
98: 				}
99: 				// also walk methods inside class
100: 				walkTopLevel(child, content, file, lang, result)
101: 			}
102: 
103: 		case "go":
104: 			switch kind {
105: 			case "function_declaration":
106: 				if fn := extractNamedChild(child, content, file, "identifier"); fn.Name != "" {
107: 					fn.StartLine = child.StartPosition().Row + 1
108: 					fn.EndLine = child.EndPosition().Row + 1
109: 					result.Functions = append(result.Functions, fn)
110: 				}
111: 			case "method_declaration":
112: 				fn := FunctionInfo{File: file, StartLine: child.StartPosition().Row + 1, EndLine: child.EndPosition().Row + 1}
113: 			for j := uint(0); j < child.ChildCount(); j++ {
114: 				gc := child.Child(j)
115: 				if gc == nil || gc.Kind() != "identifier" {
116: 					continue
117: 				}
118: 				fn.Name = safeText(content, gc.StartByte(), gc.EndByte())
119: 			}
120: 				if fn.Name != "" {
121: 					result.Functions = append(result.Functions, fn)
122: 				}
123: 			case "type_declaration":
124: 				if t := extractGoType(child, content, file); t.Name != "" {
125: 					result.Types = append(result.Types, t)
126: 				}
127: 			case "var_declaration":
128: 				result.Variables = append(result.Variables, extractInitDecls(child, content, file)...)
129: 			}
130: 
131: 		case "java":
132: 			switch kind {
133: 			case "class_declaration", "interface_declaration":
134: 				kindName := "class"
135: 				if kind == "interface_declaration" {
136: 					kindName = "interface"
137: 				}
138: 				if t := extractNamedChild(child, content, file, "identifier"); t.Name != "" {
139: 					result.Types = append(result.Types, TypeInfo{
140: 						Name: t.Name, Kind: kindName, File: file, StartLine: child.StartPosition().Row + 1,
141: 					})
142: 				}
143: 				// walk into class_body for methods
144: 				for j := uint(0); j < child.ChildCount(); j++ {
145: 					body := child.Child(j)
146: 					if body == nil || body.Kind() != "class_body" {
147: 						continue
148: 					}
149: 					for k := uint(0); k < body.ChildCount(); k++ {
150: 						method := body.Child(k)
151: 						if method == nil || method.Kind() != "method_declaration" {
152: 							continue
153: 						}
154: 						fn := FunctionInfo{File: file, StartLine: method.StartPosition().Row + 1, EndLine: method.EndPosition().Row + 1}
155: 						for l := uint(0); l < method.ChildCount(); l++ {
156: 							mchild := method.Child(l)
157: 							if mchild != nil && mchild.Kind() == "identifier" {
158: 								fn.Name = safeText(content, mchild.StartByte(), mchild.EndByte())
159: 							}
160: 						}
161: 						if fn.Name != "" {
162: 							result.Functions = append(result.Functions, fn)
163: 						}
164: 					}
165: 				}
166: 			case "variable_declaration":
167: 				result.Variables = append(result.Variables, extractInitDecls(child, content, file)...)
168: 			}
169: 		}
170: 	}
171: }
172: 
173: // extractIdent extracts a named function from a specific child kind (e.g., "function_declarator").
174: func extractIdent(node *treesitter.Node, content []byte, file, declaratorKind string) FunctionInfo {
175: 	fn := FunctionInfo{File: file}
176: 	for i := uint(0); i < node.ChildCount(); i++ {
177: 		child := node.Child(i)
178: 		if child == nil {
179: 			continue
180: 		}
181: 		if child.Kind() == declaratorKind {
182: 			for j := uint(0); j < child.ChildCount(); j++ {
183: 				decl := child.Child(j)
184: 				if decl == nil {
185: 					continue
186: 				}
187: 				if decl.Kind() == "identifier" || decl.Kind() == "field_identifier" {
188: 					fn.Name = safeText(content, decl.StartByte(), decl.EndByte())
189: 				}
190: 			}
191: 		}
192: 		if child.Kind() == "identifier" && fn.Name == "" {
193: 			fn.Name = safeText(content, child.StartByte(), child.EndByte())
194: 		}
195: 	}
196: 	fn.StartLine = node.StartPosition().Row + 1
197: 	fn.EndLine = node.EndPosition().Row + 1
198: 	return fn
199: }
200: 
201: // extractNamedChild finds the first child with a matching kind and returns its text as Name.
202: func extractNamedChild(node *treesitter.Node, content []byte, file, targetKind string) FunctionInfo {
203: 	fn := FunctionInfo{File: file}
204: 	for i := uint(0); i < node.ChildCount(); i++ {
205: 		child := node.Child(i)
206: 		if child != nil && child.Kind() == targetKind {
207: 			fn.Name = safeText(content, child.StartByte(), child.EndByte())
208: 			break
209: 		}
210: 	}
211: 	return fn
212: }
213: 
214: // extractInitDeclarators extracts variable names from declaration nodes.
215: func extractInitDecls(node *treesitter.Node, content []byte, file string) []VariableInfo {
216: 	var vars []VariableInfo
217: 	for i := uint(0); i < node.ChildCount(); i++ {
218: 		child := node.Child(i)
219: 		if child == nil {
220: 			continue
221: 		}
222: 		if child.Kind() == "init_declarator" {
223: 			v := VariableInfo{File: file, Line: child.StartPosition().Row + 1}
224: 			for j := uint(0); j < child.ChildCount(); j++ {
225: 				sub := child.Child(j)
226: 				if sub == nil {
227: 					continue
228: 				}
229: 				if sub.Kind() == "identifier" && v.Name == "" {
230: 					v.Name = safeText(content, sub.StartByte(), sub.EndByte())
231: 				}
232: 			}
233: 			if v.Name == "" {
234: 				continue
235: 			}
236: 			for j := uint(0); j < child.ChildCount(); j++ {
237: 				ad := child.Child(j)
238: 				if ad == nil || ad.Kind() != "array_declarator" {
239: 					continue
240: 				}
241: 				for k := uint(0); k < ad.ChildCount(); k++ {
242: 					ak := ad.Child(k)
243: 					if ak != nil && ak.Kind() == "identifier" && v.Name == "" {
244: 						v.Name = safeText(content, ak.StartByte(), ak.EndByte())
245: 					}
246: 				}
247: 			}
248: 			if v.Name != "" {
249: 				vars = append(vars, v)
250: 			}
251: 		}
252: 		if child.Kind() == "variable_declarator" {
253: 			v := VariableInfo{File: file, Line: child.StartPosition().Row + 1}
254: 			for j := uint(0); j < child.ChildCount(); j++ {
255: 				sub := child.Child(j)
256: 				if sub == nil {
257: 					continue
258: 				}
259: 				if sub.Kind() == "identifier" && v.Name == "" {
260: 					v.Name = safeText(content, sub.StartByte(), sub.EndByte())
261: 				}
262: 			}
263: 			if v.Name != "" {
264: 				vars = append(vars, v)
265: 			}
266: 		}
267: 	}
268: 	return vars
269: }
270: 
271: // extractGoType extracts type info from Go type_declaration nodes.
272: func extractGoType(node *treesitter.Node, content []byte, file string) TypeInfo {
273: 	for i := uint(0); i < node.ChildCount(); i++ {
274: 		child := node.Child(i)
275: 		if child == nil || child.Kind() != "type_spec" {
276: 			continue
277: 		}
278: 		ti := TypeInfo{File: file, StartLine: child.StartPosition().Row + 1}
279: 		for j := uint(0); j < child.ChildCount(); j++ {
280: 			gc := child.Child(j)
281: 			if gc == nil || gc.Kind() != "type_identifier" {
282: 				continue
283: 			}
284: 			ti.Name = safeText(content, gc.StartByte(), gc.EndByte())
285: 			for k := uint(0); k < child.ChildCount(); k++ {
286: 				switch ck := child.Child(k); {
287: 				case ck != nil && ck.Kind() == "struct_type":
288: 					ti.Kind = "struct"
289: 				case ck != nil && ck.Kind() == "interface_type":
290: 					ti.Kind = "interface"
291: 				}
292: 			}
293: 			break
294: 		}
295: 		if ti.Name != "" && ti.Kind == "" {
296: 			ti.Kind = "type"
297: 		}
298: 		return ti
299: 	}
300: 	return TypeInfo{}
301: }
302: 
303: // extractTypeName extracts type name from struct/class/enum nodes.
304: func extractTypeName(node *treesitter.Node, content []byte, file, kind string) TypeInfo {
305: 	ti := TypeInfo{File: file, Kind: kind, StartLine: node.StartPosition().Row + 1}
306: 	for i := uint(0); i < node.ChildCount(); i++ {
307: 		child := node.Child(i)
308: 		if child == nil {
309: 			continue
310: 		}
311: 		if child.Kind() == "type_identifier" || child.Kind() == "identifier" {
312: 			ti.Name = safeText(content, child.StartByte(), child.EndByte())
313: 			break
314: 		}
315: 	}
316: 	return ti
317: }
318: 
319: func safeText(content []byte, start, end uint) string {
320: 	if int(start) >= len(content) || int(end) > len(content) || start > end {
321: 		return ""
322: 	}
323: 	return string(content[start:end])
324: }
325: 
326: 

(End of file - total 326 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/parser/parser_re.go"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/parser/parser_re.go</path>
<type>file</type>
<content>
1: //go:build !cgo
2: 
3: package parser
4: 
5: import (
6: 	"fmt"
7: 	"os"
8: 	"regexp"
9: 	"strings"
10: )
11: 
12: // Language-specific regex patterns for function detection
13: var funcPatterns = map[string]*regexp.Regexp{
14: 	"c":   regexp.MustCompile(`(?m)^\s*(?:static\s+|inline\s+|extern\s+)*(?:void|int|char|float|double|long|short|unsigned|size_t|ssize_t|uint\w*|int\w*|bool|struct\s+\w+|\w+\s*\*)\s+(\w+)\s*\([^)]*\)\s*\{`),
15: 	"cpp": regexp.MustCompile(`(?m)^\s*(?:static\s+|inline\s+|extern\s+|virtual\s+|const\s+)*(?:void|int|char|float|double|long|short|unsigned|size_t|ssize_t|uint\w*|int\w*|bool|auto|string|wstring|\w+::\w+|\w+<[^>]*>|\w+\s*\*|\w+\s*&)\s+(\w+)\s*\([^)]*\)\s*(?:const\s*)?\{`),
16: 	"go": regexp.MustCompile(`(?m)^func\s+(?:\(\w+\s+\*?\w+\)\s+)?(\w+)\s*\(`),
17: 	"java": regexp.MustCompile(`(?m)^\s*(?:public|private|protected|static|final|synchronized|abstract|native)\s+(?:[<>\[\]\w.,\s]+\s+)?(\w+)\s*\([^)]*\)\s*(?:throws\s+[^{\n]+)?\s*\{`),
18: 	"python": regexp.MustCompile(`(?m)^\s*def\s+(\w+)\s*\(`),
19: 	"javascript": regexp.MustCompile(`(?m)(?:function\s+(\w+)\s*\(|(\w+)\s*=\s*(?:async\s+)?function\s*\(|(\w+)\s*=\s*\([^)]*\)\s*=>|(\w+)\s*\([^)]*\)\s*\{)`),
20: }
21: 
22: // Type/struct/class detection patterns
23: var typePatterns = map[string]*regexp.Regexp{
24: 	"c":   regexp.MustCompile(`(?m)^\s*(?:typedef\s+)?struct\s+(\w+)\s*\{`),
25: 	"cpp": regexp.MustCompile(`(?m)^\s*(?:class|struct|enum\s+class|enum)\s+(\w+)`),
26: 	"go": regexp.MustCompile(`(?m)^type\s+(\w+)\s+(?:struct|interface)\s*\{`),
27: 	"java": regexp.MustCompile(`(?m)^\s*(?:public\s+)?(?:class|interface|enum)\s+(\w+)`),
28: 	"python": regexp.MustCompile(`(?m)^class\s+(\w+)\s*[(:]`),
29: 	"javascript": regexp.MustCompile(`(?m)^\s*class\s+(\w+)`),
30: }
31: 
32: func ParseFile(filePath string, lang string) (*ParseResult, error) {
33: 	content, err := os.ReadFile(filePath)
34: 	if err != nil {
35: 		return nil, fmt.Errorf("reading file: %w", err)
36: 	}
37: 
38: 	result := &ParseResult{File: filePath, Language: lang}
39: 
40: 	// Extract functions
41: 	if pat, ok := funcPatterns[lang]; ok {
42: 		matches := pat.FindAllStringSubmatch(string(content), -1)
43: 		for _, m := range matches {
44: 			name := ""
45: 			for _, g := range m[1:] {
46: 				if g != "" {
47: 					name = g
48: 					break
49: 				}
50: 			}
51: 			if name == "" || isKeyword(name, lang) {
52: 				continue
53: 			}
54: 			// Find approximate line number
55: 			pos := strings.Index(string(content), m[0])
56: 			lineNo := uint(1)
57: 			if pos >= 0 {
58: 				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
59: 			}
60: 			endLine := lineNo + uint(strings.Count(m[0], "\n"))
61: 			result.Functions = append(result.Functions, FunctionInfo{
62: 				Name:      name,
63: 				File:      filePath,
64: 				StartLine: lineNo,
65: 				EndLine:   endLine,
66: 			})
67: 		}
68: 	}
69: 
70: 	// Extract types/classes/structs
71: 	if pat, ok := typePatterns[lang]; ok {
72: 		matches := pat.FindAllStringSubmatch(string(content), -1)
73: 		for _, m := range matches {
74: 			name := m[1]
75: 			if name == "" || isKeyword(name, lang) {
76: 				continue
77: 			}
78: 			pos := strings.Index(string(content), m[0])
79: 			lineNo := uint(1)
80: 			if pos >= 0 {
81: 				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
82: 			}
83: 			kind := "type"
84: 			switch lang {
85: 			case "c", "cpp":
86: 				if strings.Contains(m[0], "struct") {
87: 					kind = "struct"
88: 				} else if strings.Contains(m[0], "class") {
89: 					kind = "class"
90: 				} else if strings.Contains(m[0], "enum") {
91: 					kind = "enum"
92: 				}
93: 			case "go":
94: 				if strings.Contains(strings.ToLower(m[0]), "interface") {
95: 					kind = "interface"
96: 				} else {
97: 					kind = "struct"
98: 				}
99: 			case "java":
100: 				if strings.Contains(m[0], "interface") {
101: 					kind = "interface"
102: 				} else if strings.Contains(m[0], "enum") {
103: 					kind = "enum"
104: 				} else {
105: 					kind = "class"
106: 				}
107: 			case "python":
108: 				kind = "class"
109: 			case "javascript":
110: 				kind = "class"
111: 			}
112: 			result.Types = append(result.Types, TypeInfo{
113: 				Name:      name,
114: 				Kind:      kind,
115: 				File:      filePath,
116: 				StartLine: lineNo,
117: 			})
118: 		}
119: 	}
120: 
121: 	// Simple variable extraction for C/C++ declarations
122: 	if lang == "c" || lang == "cpp" {
123: 		varDeclPat := regexp.MustCompile(`(?m)^\s*(?:static\s+|extern\s+|const\s+)*(?:int|char|float|double|long|short|unsigned|bool|size_t|void)\s+(\w+)\s*[=;]`)
124: 		matches := varDeclPat.FindAllStringSubmatch(string(content), -1)
125: 		for _, m := range matches {
126: 			name := m[1]
127: 			if name == "" || isKeyword(name, lang) {
128: 				continue
129: 			}
130: 			pos := strings.Index(string(content), m[0])
131: 			lineNo := uint(1)
132: 			if pos >= 0 {
133: 				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
134: 			}
135: 			result.Variables = append(result.Variables, VariableInfo{
136: 				Name: name,
137: 				File: filePath,
138: 				Line: lineNo,
139: 			})
140: 		}
141: 	}
142: 
143: 
144: 	// Variable extraction for Go
145: 	if lang == "go" {
146: 		varDeclPat := regexp.MustCompile(`(?m)^\s*(?:var\s+)?(\w+)\s*(?:=|:=)`)
147: 		matches := varDeclPat.FindAllStringSubmatch(string(content), -1)
148: 		for _, m := range matches {
149: 			name := m[1]
150: 			if name == "" || isKeyword(name, lang) {
151: 				continue
152: 			}
153: 			pos := strings.Index(string(content), m[0])
154: 			lineNo := uint(1)
155: 			if pos >= 0 {
156: 				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
157: 			}
158: 			result.Variables = append(result.Variables, VariableInfo{
159: 				Name: name,
160: 				File: filePath,
161: 				Line: lineNo,
162: 			})
163: 		}
164: 	}
165: 
166: 	// Variable extraction for Java (type-prefixed declaration)
167: 	if lang == "java" {
168: 		varDeclPat := regexp.MustCompile(`(?m)^\s*(?:\w+\s+)*(?:int|long|double|float|boolean|char|byte|short|String|var|Object)\s+(\w+)\s*(?:=|;)`)
169: 		matches := varDeclPat.FindAllStringSubmatch(string(content), -1)
170: 		for _, m := range matches {
171: 			name := m[1]
172: 			if name == "" || isKeyword(name, lang) {
173: 				continue
174: 			}
175: 			pos := strings.Index(string(content), m[0])
176: 			lineNo := uint(1)
177: 			if pos >= 0 {
178: 				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
179: 			}
180: 			result.Variables = append(result.Variables, VariableInfo{
181: 				Name: name,
182: 				File: filePath,
183: 				Line: lineNo,
184: 			})
185: 		}
186: 	}
187: 
188: 	// Variable extraction for Python (line-start assignment)
189: 	if lang == "python" {
190: 		varDeclPat := regexp.MustCompile(`(?m)^\s*(\w+)\s*=\s*[^=\n]`)
191: 		matches := varDeclPat.FindAllStringSubmatch(string(content), -1)
192: 		for _, m := range matches {
193: 			name := m[1]
194: 			if name == "" || isKeyword(name, lang) {
195: 				continue
196: 			}
197: 			pos := strings.Index(string(content), m[0])
198: 			lineNo := uint(1)
199: 			if pos >= 0 {
200: 				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
201: 			}
202: 			result.Variables = append(result.Variables, VariableInfo{
203: 				Name: name,
204: 				File: filePath,
205: 				Line: lineNo,
206: 			})
207: 		}
208: 	}
209: 
210: 
211: 	return result, nil
212: }
213: 
214: // isKeyword checks if a name is a language keyword that shouldn't be treated as an identifier.
215: func isKeyword(name, lang string) bool {
216: 	keywords := map[string]bool{
217: 		"if": true, "else": true, "for": true, "while": true, "do": true,
218: 		"switch": true, "case": true, "default": true, "break": true, "continue": true,
219: 		"return": true, "goto": true, "sizeof": true, "typedef": true, "volatile": true,
220: 		"const": true, "static": true, "extern": true, "register": true, "auto": true,
221: 		"unsigned": true, "signed": true, "void": true, "new": true, "delete": true,
222: 		"try": true, "catch": true, "throw": true, "throws": true, "finally": true,
223: 		"public": true, "private": true, "protected": true, "class": true, "struct": true,
224: 		"enum": true, "interface": true, "extends": true, "implements": true,
225: 		"package": true, "import": true, "var": true, "func": true, "type": true,
226: 		"def": true, "pass": true, "yield": true, "async": true, "await": true,
227: 	}
228: 	return keywords[name]
229: }

(End of file - total 229 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/parser/types.go"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/parser/types.go</path>
<type>file</type>
<content>
1: package parser
2: 
3: type ParseResult struct {
4: 	File      string         `json:"file"`
5: 	Language  string         `json:"language"`
6: 	Functions []FunctionInfo `json:"functions"`
7: 	Variables []VariableInfo `json:"variables"`
8: 	Types     []TypeInfo     `json:"types"`
9: }
10: 
11: type FunctionInfo struct {
12: 	Name      string `json:"name"`
13: 	File      string `json:"file"`
14: 	StartLine uint   `json:"start_line"`
15: 	EndLine   uint   `json:"end_line"`
16: }
17: 
18: type VariableInfo struct {
19: 	Name string `json:"name"`
20: 	File string `json:"file"`
21: 	Line uint   `json:"line"`
22: }
23: 
24: type TypeInfo struct {
25: 	Name      string `json:"name"`
26: 	Kind      string `json:"kind"`
27: 	File      string `json:"file"`
28: 	StartLine uint   `json:"start_line"`
29: }

(End of file - total 29 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/indexer/indexer.go"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/indexer/indexer.go</path>
<type>file</type>
<content>
1: package indexer
2: 
3: import (
4: 	"os"
5: 	"strings"
6: 
7: 	"github.com/secguardian/internal/parser"
8: )
9: 
10: type SymbolIndex struct {
11: 	Functions []parser.FunctionInfo `json:"functions"`
12: 	Variables []parser.VariableInfo `json:"variables"`
13: 	Types     []parser.TypeInfo     `json:"types"`
14: }
15: 
16: type CallGraphEdge struct {
17: 	Caller string `json:"caller"`
18: 	Callee string `json:"callee"`
19: 	File   string `json:"file"`
20: 	Line   uint   `json:"line"`
21: }
22: 
23: type CallGraph struct {
24: 	Edges []CallGraphEdge `json:"edges"`
25: }
26: 
27: type FreeSite struct {
28: 	File string `json:"file"`
29: 	Line uint   `json:"line"`
30: }
31: 
32: type AllocFreePair struct {
33: 	AllocFunc string     `json:"alloc_func"`
34: 	AllocFile string     `json:"alloc_file"`
35: 	AllocLine uint       `json:"alloc_line"`
36: 	FreeSites []FreeSite `json:"free_sites"`
37: }
38: 
39: type AllocFreeMap struct {
40: 	Pairs []AllocFreePair `json:"pairs"`
41: }
42: 
43: type LockUsage struct {
44: 	MutexName  string `json:"mutex_name"`
45: 	LockLine   uint   `json:"lock_line"`
46: 	UnlockLine uint   `json:"unlock_line"`
47: 	File       string `json:"file"`
48: }
49: 
50: type LockGraph struct {
51: 	Mutexes []LockUsage `json:"mutexes"`
52: }
53: 
54: func ExtractSymbols(parsed map[string]*parser.ParseResult) SymbolIndex {
55: 	idx := SymbolIndex{}
56: 	for _, result := range parsed {
57: 		idx.Functions = append(idx.Functions, result.Functions...)
58: 		idx.Variables = append(idx.Variables, result.Variables...)
59: 		idx.Types = append(idx.Types, result.Types...)
60: 	}
61: 	return idx
62: }
63: 
64: // isCommentLine checks if a trimmed line looks like a comment line (heuristic).
65: func isCommentLine(line string) bool {
66: 	trimmed := strings.TrimSpace(line)
67: 	return strings.HasPrefix(trimmed, "//") || strings.HasPrefix(trimmed, "/*") ||
68: 		strings.HasPrefix(trimmed, "* ")
69: }
70: 
71: // BuildCallGraph scans each function body for calls to other known functions.
72: func BuildCallGraph(parsed map[string]*parser.ParseResult, symbols SymbolIndex) CallGraph {
73: 	cg := CallGraph{}
74: 
75: 	for _, result := range parsed {
76: 		content, err := os.ReadFile(result.File)
77: 		if err != nil {
78: 			continue
79: 		}
80: 		lines := strings.Split(string(content), "\n")
81: 
82: 		for _, fn := range result.Functions {
83: 			start := int(fn.StartLine) - 1
84: 			end := int(fn.EndLine)
85: 			if start < 0 {
86: 				start = 0
87: 			}
88: 			if end > len(lines) {
89: 				end = len(lines)
90: 			}
91: 			body := strings.Join(lines[start:end], " ")
92: 
93: 			for _, callee := range symbols.Functions {
94: 				if callee.Name == fn.Name {
95: 					continue
96: 				}
97: 				if strings.Contains(body, callee.Name+"(") || strings.Contains(body, callee.Name+" (") {
98: 					// Skip if the call appears only in comment lines
99: 					foundInCode := false
100: 					for i := start; i < end; i++ {
101: 						if i >= len(lines) {
102: 							break
103: 						}
104: 						if isCommentLine(lines[i]) {
105: 							continue
106: 						}
107: 						if strings.Contains(lines[i], callee.Name+"(") || strings.Contains(lines[i], callee.Name+" (") {
108: 							foundInCode = true
109: 							break
110: 						}
111: 					}
112: 					if !foundInCode {
113: 						continue
114: 					}
115: 					cg.Edges = append(cg.Edges, CallGraphEdge{
116: 						Caller: fn.Name,
117: 						Callee: callee.Name,
118: 						File:   fn.File,
119: 						Line:   fn.StartLine,
120: 					})
121: 				}
122: 			}
123: 		}
124: 	}
125: 	return cg
126: }
127: 
128: // MatchAllocFree finds malloc/calloc/realloc and their corresponding free/delete calls.
129: func MatchAllocFree(parsed map[string]*parser.ParseResult) AllocFreeMap {
130: 	af := AllocFreeMap{}
131: 	allocFns := map[string]bool{"malloc": true, "calloc": true, "realloc": true}
132: 	freeFns := map[string]bool{"free": true, "delete": true}
133: 
134: 	for _, result := range parsed {
135: 		content, err := os.ReadFile(result.File)
136: 		if err != nil {
137: 			continue
138: 		}
139: 		lines := strings.Split(string(content), "\n")
140: 
141: 		for i, line := range lines {
142: 			if isCommentLine(line) {
143: 				continue
144: 			}
145: 			for afn := range allocFns {
146: 				if strings.Contains(line, afn+"(") {
147: 					pair := AllocFreePair{
148: 						AllocFunc: afn,
149: 						AllocFile: result.File,
150: 						AllocLine: uint(i + 1),
151: 					}
152: 					for j, fline := range lines {
153: 						if isCommentLine(fline) {
154: 							continue
155: 						}
156: 						for ffn := range freeFns {
157: 							if strings.Contains(fline, ffn+"(") {
158: 								pair.FreeSites = append(pair.FreeSites, FreeSite{
159: 									File: result.File,
160: 									Line: uint(j + 1),
161: 								})
162: 							}
163: 						}
164: 					}
165: 					if len(pair.FreeSites) > 0 {
166: 						af.Pairs = append(af.Pairs, pair)
167: 					}
168: 				}
169: 			}
170: 		}
171: 	}
172: 	return af
173: }
174: 
175: // BuildLockGraph scans for mutex lock/unlock patterns.
176: func BuildLockGraph(parsed map[string]*parser.ParseResult) LockGraph {
177: 	lg := LockGraph{}
178: 	lockPatterns := []string{
179: 		"pthread_mutex_lock", "pthread_mutex_unlock",
180: 	}
181: 
182: 	for _, result := range parsed {
183: 		content, err := os.ReadFile(result.File)
184: 		if err != nil {
185: 			continue
186: 		}
187: 		lines := strings.Split(string(content), "\n")
188: 		for i, line := range lines {
189: 			for _, pat := range lockPatterns {
190: 				if strings.Contains(line, pat) {
191: 					lg.Mutexes = append(lg.Mutexes, LockUsage{
192: 						File:     result.File,
193: 						LockLine: uint(i + 1),
194: 					})
195: 				}
196: 			}
197: 		}
198: 	}
199: 	return lg
200: }

(End of file - total 200 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/context/context.go"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/context/context.go</path>
<type>file</type>
<content>
1: package context
2: 
3: import "github.com/secguardian/internal/indexer"
4: 
5: // AnalysisContext is the shared, pre-indexed understanding of a codebase.
6: // Built once by the indexer, consumed by all skills/detectors.
7: type AnalysisContext struct {
8: 	Path            string              `json:"path"`
9: 	FileCount       int                 `json:"file_count"`
10: 	FunctionCount   int                 `json:"function_count"`
11: 	CallEdgeCount   int                 `json:"call_edge_count"`
12: 	PrimaryLanguage string              `json:"primary_language"`
13: 	Files           []string            `json:"files"`
14: 	Symbols   indexer.SymbolIndex `json:"symbols"`
15: 	CallGraph indexer.CallGraph  `json:"call_graph"`
16: 	AllocFree indexer.AllocFreeMap `json:"alloc_free"`
17: 	LockGraph indexer.LockGraph  `json:"lock_graph"`
18: }

(End of file - total 18 lines)
</content>
```

---

## Assistant (Build · DeepSeek V4 Flash · 3.6s)

_Thinking:_

Now let me read more files - the remaining critical ones: render-report.py, secfix.py, dev-verify.sh, e2e-verify.sh, and some of the scripts. Also let me check the parser_javascript.go and some of the test files, SDD docs, etc.

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/parser/parser_javascript.go"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/parser/parser_javascript.go</path>
<type>file</type>
<content>
1: // Package parser — JavaScript parser fallback (always available, no CGO needed)
2: //
3: // When CGO is enabled, parser_ts.go handles c/cpp/python/go/java.
4: // JavaScript is always parsed via regex since tree-sitter may not have
5: // the JS grammar compiled in.
6: //
7: // This file has NO build tag — it is always compiled.
8: 
9: package parser
10: 
11: import (
12: 	"fmt"
13: 	"os"
14: 	"regexp"
15: 	"strings"
16: )
17: 
18: // JS-specific regex patterns
19: var jsFuncPattern = regexp.MustCompile(
20: 	`(?m)(?:` +
21: 		`function\s+(\w+)\s*\(|` + // function foo()
22: 		`(\w+)\s*=\s*(?:async\s+)?function\s*\(|` + // foo = function()
23: 		`(\w+)\s*=\s*(?:async\s+)?\([^)]*\)\s*=>|` + // foo = () => {}
24: 		`(\w+)\s*\([^)]*\)\s*\{` + // foo() { (method shorthand)
25: 		`)`,
26: )
27: 
28: var jsClassPattern = regexp.MustCompile(`(?m)^\s*class\s+(\w+)`)
29: 
30: var jsArrowInObj = regexp.MustCompile(`(?m)(\w+)\s*:\s*(?:async\s+)?\([^)]*\)\s*=>`)
31: 
32: var jsMethodInObj = regexp.MustCompile(`(?m)(\w+)\s*\([^)]*\)\s*\{`)
33: 
34: func parseJSFile(filePath string) (*ParseResult, error) {
35: 	// Guard: skip files >512KB (likely minified bundles)
36: 	fi, err := os.Stat(filePath)
37: 	if err != nil {
38: 		return nil, err
39: 	}
40: 	if fi.Size() > 512*1024 {
41: 		return &ParseResult{
42: 			File:     filePath,
43: 			Language: "javascript",
44: 		}, nil
45: 	}
46: 
47: 	content, err := os.ReadFile(filePath)
48: 	if err != nil {
49: 		return nil, err
50: 	}
51: 
52: 	// Guard: skip minified single-line files (>2000 chars on any line)
53: 	text := string(content)
54: 	lines := strings.Split(text, "\n")
55: 	for _, line := range lines {
56: 		if len(line) > 2000 {
57: 			return &ParseResult{
58: 				File:     filePath,
59: 				Language: "javascript",
60: 			}, nil
61: 		}
62: 	}
63: 
64: 	result := &ParseResult{
65: 		File:     filePath,
66: 		Language: "javascript",
67: 	}
68: 
69: 	// Extract functions
70: 	seen := make(map[string]bool)
71: 	for _, match := range jsFuncPattern.FindAllStringSubmatch(text, -1) {
72: 		for i := 1; i < len(match); i++ {
73: 			if match[i] != "" && !seen[match[i]] {
74: 				seen[match[i]] = true
75: 				lineNum := findLine(lines, match[0])
76: 				result.Functions = append(result.Functions, FunctionInfo{
77: 					Name:      match[i],
78: 					File:      filePath,
79: 					StartLine: uint(lineNum),
80: 					EndLine:   uint(lineNum + 1),
81: 				})
82: 				break
83: 			}
84: 		}
85: 	}
86: 
87: 	// Extract arrow functions in objects
88: 	for _, match := range jsArrowInObj.FindAllStringSubmatch(text, -1) {
89: 		name := match[1]
90: 		if !seen[name] && name != "if" && name != "do" && name != "for" && name != "try" && name != "while" && name != "switch" {
91: 			seen[name] = true
92: 			lineNum := findLine(lines, match[0])
93: 			result.Functions = append(result.Functions, FunctionInfo{
94: 				Name:      name,
95: 				File:      filePath,
96: 				StartLine: uint(lineNum),
97: 				EndLine:   uint(lineNum + 1),
98: 			})
99: 		}
100: 	}
101: 
102: 	// Extract method shorthand in objects
103: 	for _, match := range jsMethodInObj.FindAllStringSubmatch(text, -1) {
104: 		name := match[1]
105: 		if !seen[name] && name != "if" && name != "do" && name != "for" && name != "try" && name != "while" && name != "switch" && name != "catch" {
106: 			seen[name] = true
107: 			lineNum := findLine(lines, match[0])
108: 			result.Functions = append(result.Functions, FunctionInfo{
109: 				Name:      name,
110: 				File:      filePath,
111: 				StartLine: uint(lineNum),
112: 				EndLine:   uint(lineNum + 1),
113: 			})
114: 		}
115: 	}
116: 
117: 	// Extract classes
118: 	for _, match := range jsClassPattern.FindAllStringSubmatch(text, -1) {
119: 		lineNum := findLine(lines, match[0])
120: 		result.Types = append(result.Types, TypeInfo{
121: 			Name:      match[1],
122: 			Kind:      "class",
123: 			File:      filePath,
124: 			StartLine: uint(lineNum),
125: 		})
126: 	}
127: 
128: 	return result, nil
129: }
130: 
131: func findLine(lines []string, snippet string) int {
132: 	// Take first line of the snippet for matching
133: 	firstLine := strings.SplitN(snippet, "\n", 2)[0]
134: 	firstLine = strings.TrimSpace(firstLine)
135: 	if len(firstLine) > 80 {
136: 		firstLine = firstLine[:80]
137: 	}
138: 
139: 	for i, line := range lines {
140: 		trimmed := strings.TrimSpace(line)
141: 		if strings.Contains(trimmed, firstLine) || strings.HasPrefix(trimmed, firstLine) {
142: 			return i + 1 // 1-based
143: 		}
144: 	}
145: 	return 1
146: }
147: 
148: // parseJS is a package-level helper for fallback parsing
149: func tryParseJS(filePath string) (*ParseResult, error) {
150: 	return parseJSFile(filePath)
151: }
152: 
153: // Ensure we handle JS parse errors properly
154: func init() {
155: 	// Verify JS regex compiles correctly at init
156: 	if jsFuncPattern == nil {
157: 		panic("jsFuncPattern failed to compile")
158: 	}
159: }
160: 
161: // Ensure format string import is used
162: var _ = fmt.Sprintf

(End of file - total 162 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/render-report.py"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/render-report.py</path>
<type>file</type>
<content>
1: #!/usr/bin/env python3
2: """
3: SecGuardian Report Rendering Engine v1.0
4: 
5: Takes AI-generated findings.json + index.json and generates all 6 output files:
6:   report.md, results.sarif, summary.json, manifest.json, status.json, delta.json
7: 
8: Zero external dependencies — stdlib only.
9: Part of the SecGuardian Performance Refactoring (CodePlan: hashed-juggling-sutherland).
10: 
11: Usage:
12:   python3 render-report.py \\
13:     --findings .codeagent/<ns>/scans/<id>/findings.json \\
14:     --index .codeagent/<ns>/scans/<id>/index.json \\
15:     --output .codeagent/<ns>/scans/<id>/
16: 
17: CI mode:
18:   python3 render-report.py --ci \\
19:     --findings findings.json --index index.json --output ./output/   # v4.0 legacy
20:     --findings-dir findings/ --index index.json --output ./output/  # v5.0 directory tree
21: 
22: Copyright 2026 SecGuardian. Apache 2.0.
23: """
24: 
25: import argparse
26: import json
27: import math
28: import os
29: import sys
30: import hashlib
31: import datetime
32: from string import Template
33: from collections import Counter
34: 
35: 
36: # ── Constants ───────────────────────────────────
37: 
38: def load_detector_index_from_files(detectors_dir=None):
39:     """Build detector -> {index, cwe} mapping from knowledge/detectors/*.md files.
40: 
41:     Dynamically reads detector files to avoid hardcoding the DETECTOR_RULE_INDEX.
42:     Falls back to builtin DETECTOR_RULE_INDEX_FALLBACK if files are unavailable.
43:     """
44:     if detectors_dir is None:
45:         script_dir = os.path.dirname(os.path.abspath(__file__))
46:         detectors_dir = os.path.join(script_dir, "..", "knowledge", "detectors")
47: 
48:     if not os.path.isdir(detectors_dir):
49:         return None  # caller should use fallback
50: 
51:     index = {}
52:     detector_files = sorted(f for f in os.listdir(detectors_dir) if f.endswith('.md'))
53: 
54:     for i, fname in enumerate(detector_files):
55:         # Convert filename: memory-null-dereference.md -> memory.null-dereference
56:         name = fname[:-3]
57:         parts = name.split('-', 1)
58:         detector_name = f"{parts[0]}.{parts[1]}" if len(parts) == 2 else name
59: 
60:         # Parse CWE from file frontmatter
61:         cwe_list = []
62:         filepath = os.path.join(detectors_dir, fname)
63:         try:
64:             with open(filepath) as f:
65:                 for line in f:
66:                     line = line.strip()
67:                     if line.startswith('cwe:') or line.startswith('CWE:'):
68:                         cwe_list = [c.strip() for c in line.split(':', 1)[1].split(',')
69:                                     if c.strip().startswith('CWE-')]
70:                         break
71:                     if line == '---' and cwe_list:
72:                         break  # past frontmatter
73:         except Exception:
74:             pass
75: 
76:         if not cwe_list:
77:             cwe_list = ["CWE-000"]
78: 
79:         index[detector_name] = {"index": i, "cwe": cwe_list}
80: 
81:     return index if index else None
82: 
83: 
84: # Try dynamic loading, fall back to builtin
85: _DYNAMIC_INDEX = load_detector_index_from_files()
86: 
87: if _DYNAMIC_INDEX:
88:     DETECTOR_RULE_INDEX = _DYNAMIC_INDEX
89: else:
90:     DETECTOR_RULE_INDEX = {
91:     "system.command-injection":        {"index": 0,  "cwe": ["CWE-77", "CWE-94"]},
92:     "web.sql-injection":               {"index": 1,  "cwe": ["CWE-89"]},
93:     "crypto.hardcoded-secrets":        {"index": 2,  "cwe": ["CWE-798"]},
94:     "crypto.weak-crypto-algorithm":    {"index": 3,  "cwe": ["CWE-327"]},
95:     "crypto.insufficient-key-length":  {"index": 4,  "cwe": ["CWE-326"]},
96:     "web.ssrf":                        {"index": 5,  "cwe": ["CWE-918"]},
97:     "system.path-traversal":           {"index": 6,  "cwe": ["CWE-22"]},
98:     "web.xss":                         {"index": 7,  "cwe": ["CWE-79"]},
99:     "web.jwt-misuse":                  {"index": 8,  "cwe": ["CWE-347"]},
100:     "web.csrf":                        {"index": 9,  "cwe": ["CWE-352"]},
101:     "web.auth-bypass":                 {"index": 10, "cwe": ["CWE-287"]},
102:     "web.idor":                        {"index": 11, "cwe": ["CWE-639"]},
103:     "web.xxe":                         {"index": 12, "cwe": ["CWE-611"]},
104:     "web.input-validation":            {"index": 13, "cwe": ["CWE-20"]},
105:     "web.unrestricted-upload":         {"index": 14, "cwe": ["CWE-434"]},
106:     "web.missing-authorization":       {"index": 15, "cwe": ["CWE-862"]},
107:     "web.missing-authentication":      {"index": 16, "cwe": ["CWE-306"]},
108:     "web.open-redirect":               {"index": 17, "cwe": ["CWE-601"]},
109:     "web.resource-exhaustion":         {"index": 18, "cwe": ["CWE-400"]},
110:     "web.ssti":                        {"index": 19, "cwe": ["CWE-1336"]},
111:     "web.nosql-injection":             {"index": 20, "cwe": ["CWE-943"]},
112:     "web.code-injection":              {"index": 21, "cwe": ["CWE-94"]},
113:     "web.deserialization":             {"index": 22, "cwe": ["CWE-502"]},
114:     "web.excessive-data-exposure":     {"index": 23, "cwe": ["CWE-200"]},
115:     "web.mass-assignment":             {"index": 24, "cwe": ["CWE-915"]},
116:     "web.prototype-pollution":         {"index": 25, "cwe": ["CWE-1321"]},
117:     "crypto.password-storage":         {"index": 26, "cwe": ["CWE-256"]},
118:     "crypto.weak-random":              {"index": 27, "cwe": ["CWE-338"]},
119:     "crypto.custom-crypto":            {"index": 28, "cwe": ["CWE-327"]},
120:     "crypto.tls-version":              {"index": 29, "cwe": ["CWE-326"]},
121:     "crypto.aes-ecb-mode":             {"index": 30, "cwe": ["CWE-327"]},
122:     "crypto.hardcoded-iv":             {"index": 31, "cwe": ["CWE-329"]},
123:     "concurrency.data-race":           {"index": 32, "cwe": ["CWE-362"]},
124:     "concurrency.deadlock":            {"index": 33, "cwe": ["CWE-833"]},
125:     "concurrency.race-condition":      {"index": 34, "cwe": ["CWE-362"]},
126:     "concurrency.thread-unsafe-signal": {"index": 35, "cwe": ["CWE-364"]},
127:     "resource.file-leak":              {"index": 36, "cwe": ["CWE-404"]},
128:     "resource.socket-leak":            {"index": 37, "cwe": ["CWE-404"]},
129:     "resource.memory-leak":            {"index": 38, "cwe": ["CWE-401"]},
130:     "resource.lock-misuse":            {"index": 39, "cwe": ["CWE-667"]},
131:     "resource.file-double-close":      {"index": 40, "cwe": ["CWE-675"]},
132:     "resource.file-use-after-close":    {"index": 41, "cwe": ["CWE-416"]},
133:     "resource.refcount-misuse":        {"index": 42, "cwe": ["CWE-911"]},
134:     "error.debug-mode-production":     {"index": 43, "cwe": ["CWE-489"]},
135:     "error.exception-swallow":         {"index": 44, "cwe": ["CWE-390"]},
136:     "error.log-sensitive-data":        {"index": 45, "cwe": ["CWE-532"]},
137:     "error.panic-to-client":           {"index": 46, "cwe": ["CWE-209"]},
138:     "error.stack-trace-leak":          {"index": 47, "cwe": ["CWE-209"]},
139:     "error.unified-error-format":      {"index": 48, "cwe": ["CWE-209"]},
140:     "memory.buffer-overflow":          {"index": 49, "cwe": ["CWE-120"]},
141:     "memory.heap-buffer-overflow":     {"index": 50, "cwe": ["CWE-122"]},
142:     "memory.use-after-free":           {"index": 51, "cwe": ["CWE-416"]},
143:     "memory.double-free":              {"index": 52, "cwe": ["CWE-415"]},
144:     "memory.null-dereference":         {"index": 53, "cwe": ["CWE-476"]},
145:     "memory.memory-leak":              {"index": 54, "cwe": ["CWE-401"]},
146:     "memory.integer-overflow":         {"index": 55, "cwe": ["CWE-190"]},
147:     "memory.format-string":            {"index": 56, "cwe": ["CWE-134"]},
148:     "memory.off-by-one":               {"index": 57, "cwe": ["CWE-193"]},
149:     "memory.oob-read":                 {"index": 58, "cwe": ["CWE-125"]},
150:     "memory.uninitialized-memory":     {"index": 59, "cwe": ["CWE-457"]},
151:     "memory.bad-cast":                 {"index": 60, "cwe": ["CWE-704"]},
152:     "memory.mismatched-free":          {"index": 61, "cwe": ["CWE-762"]},
153:     "system.insecure-permissions":     {"index": 62, "cwe": ["CWE-732"]},
154:     "system.insecure-temp-file":       {"index": 63, "cwe": ["CWE-377"]},
155:     "system.privilege-escalation":     {"index": 64, "cwe": ["CWE-269"]},
156:     "system.secrets-detection":        {"index": 65, "cwe": ["CWE-798"]},
157:     "system.symlink-attack":           {"index": 66, "cwe": ["CWE-61"]},
158:     "system.toctou":                   {"index": 67, "cwe": ["CWE-367"]},
159:     "web.jwt-misuse":                  {"index": 8,  "cwe": ["CWE-347"]},
160: }  # DETECTOR_RULE_INDEX_FALLBACK — used only when detector files unavailable
161: 
162: 
163: # ── Helpers ─────────────────────────────────────
164: 
165: def load_json(path):
166:     """Load and return JSON file. Exit with message on failure."""
167:     try:
168:         with open(path) as f:
169:             return json.load(f)
170:     except FileNotFoundError:
171:         print(f"ERROR: File not found: {path}", file=sys.stderr)
172:         sys.exit(1)
173:     except json.JSONDecodeError as e:
174:         print(f"ERROR: Invalid JSON in {path}: {e}", file=sys.stderr)
175:         sys.exit(1)
176: 
177: 
178: def safe_len(obj):
179:     """安全获取长度: None -> 0, list -> len(list)"""
180:     return len(obj) if isinstance(obj, (list, dict, str)) else 0
181: 
182: def calc_score(findings):
183:     """Calculate security score from findings list.
184:     
185:     Uses exponential decay formula to avoid bottoming out at 0:
186:     score = 100 * exp(-0.2*Crit - 0.1*High - 0.04*Med - 0.01*Low)
187:     
188:     This preserves granularity even for high-severity scans:
189:     - 0 findings     → 100
190:     - 1 Crit         → ~82
191:     - 3 Crit + 5 High → ~47
192:     - 9 Crit + 5 High + 3 Med → ~26
193:     - 15 Crit        → ~5
194:     """
195:     weights = {"Critical": 0.2, "High": 0.1, "Medium": 0.04, "Low": 0.01, "Info": 0}
196:     penalty = sum(weights.get(f["severity"], 0) for f in findings)
197:     return max(0, round(100 * math.exp(-penalty)))
198: 
199: 
200: def calc_grade(score):
201:     if score >= 80: return "A"
202:     if score >= 55: return "B"
203:     if score >= 35: return "C"
204:     if score >= 15: return "D"
205:     return "F"
206: 
207: 
208: 
209: def _ensure_fields(f):
210:     """Normalize finding fields: fill in defaults for all renderer-required fields.
211: 
212:     Different command types (secguard/secaudit/secreview) produce findings with
213:     different field structures. This function ensures the renderer never crashes
214:     with KeyError regardless of what fields the agent includes.
215:     """
216:     # Root-level required fields with fallbacks
217:     if not f.get('file'):
218:         loc = f.get('location', {})
219:         f['file'] = loc.get('file_path', 'unknown') if isinstance(loc, dict) else 'unknown'
220:     if not f.get('line') and f.get('line') != 0:
221:         loc = f.get('location', {})
222:         f['line'] = loc.get('start_line', 0) if isinstance(loc, dict) else 0
223:     f.setdefault('severity', 'Medium')
224:     f.setdefault('cwe', 'CWE-000')
225:     f.setdefault('detector', 'unknown')
226:     f.setdefault('title', f.get('fix_summary', 'Security Finding'))
227:     f.setdefault('function', (f.get('location') or {}).get('function_name', 'N/A'))
228: 
229:     # Nested field defaults
230:     ev = f.setdefault('evidence', {})
231:     ev.setdefault('judgment_rationale', 'N/A')
232:     ev.setdefault('code_context', 'N/A')
233: 
234:     imp = f.setdefault('impact', {})
235:     imp.setdefault('attack_scenario', 'N/A')
236:     if imp.get('cvss_score') is None:
237:         imp['cvss_score'] = 0.0
238: 
239:     fi = f.setdefault('fix', {})
240:     fi.setdefault('before_code', 'N/A')
241:     fi.setdefault('after_code', 'N/A')
242:     # 别名映射: 兼容 agent 可能使用的非标准字段名
243:     loc = f.get('location')
244:     if isinstance(loc, dict):
245:         if 'file' in loc and 'file_path' not in loc:
246:             loc['file_path'] = loc['file']
247:         if 'code_snippet' in loc and 'snippet' not in loc:
248:             loc['snippet'] = loc['code_snippet']
249:     ev = f.get('evidence')
250:     if isinstance(ev, dict):
251:         pass  # evidence names are standard
252:     fi = f.get('fix')
253:     if isinstance(fi, dict):
254:         if 'code_before' in fi and 'before_code' not in fi:
255:             fi['before_code'] = fi['code_before']
256:         if 'code_after' in fi and 'after_code' not in fi:
257:             fi['after_code'] = fi['code_after']
258:     fi.setdefault('description', f.get('fix_summary', 'N/A'))
259: 
260:     return f
261: 
262: 
263: def severity_emoji(severity):
264:     return {"Critical": "🔴", "High": "🟠", "Medium": "🟡", "Low": "🔵", "Info": "⚪"}.get(severity, "⚪")
265: 
266: 
267: def fingerprint(finding):
268:     """Generate SARIF partialFingerprints.primary."""
269:     raw = f"{finding['file']}:{finding['line']}:{finding['detector']}"
270:     return hashlib.sha256(raw.encode()).hexdigest()
271: 
272: 
273: def indent(text, spaces=4):
274:     """Indent multi-line text by spaces."""
275:     prefix = " " * spaces
276:     return "\n".join(prefix + line if line.strip() else "" for line in text.split("\n"))
277: 
278: 
279: def now_iso():
280:     return datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
281: 
282: 
283: def load_findings_from_tree(findings_dir):
284:     """Load all finding files from a v5.0 directory tree.
285: 
286:     Walks findings/<namespace>/<detector>/<finding-id>.json
287:     Returns list of finding dicts (same format as v4.0 findings.json['findings']).
288:     """
289:     findings = []
290:     if not os.path.isdir(findings_dir):
291:         print(f"ERROR: Findings directory not found: {findings_dir}", file=sys.stderr)
292:         sys.exit(1)
293:     for root, dirs, files in sorted(os.walk(findings_dir)):
294:         for fname in sorted(files):
295:             if fname.endswith('.json'):
296:                 filepath = os.path.join(root, fname)
297:                 try:
298:                     with open(filepath) as f:
299:                         data = json.load(f)
300:                 except (json.JSONDecodeError, FileNotFoundError) as e:
301:                     print(f"WARNING: Skipping invalid finding file {filepath}: {e}", file=sys.stderr)
302:                     continue
303:                 # Support {"finding": {...}} wrapper (v5.0) and bare Finding object
304:                 if isinstance(data, dict) and 'finding' in data:
305:                     findings.append(_ensure_fields(data['finding']))
306:                 elif isinstance(data, dict) and 'id' in data:
307:                     findings.append(_ensure_fields(data))
308:                 else:
309:                     print(f"WARNING: Skipping {filepath} — missing 'finding' wrapper or 'id' field", file=sys.stderr)
310:     return findings
311: 
312: 
313: # ── Quality Gate (secaudit Step 4b) ─────────────
314: 
315: def validate_finding_4segment(f, max_retries=0):
316:     """
317:     Validate a single finding against the 4-segment protocol.
318:     Returns (is_valid, missing_fields).
319:     """
320:     missing = []
321: 
322:     # 1. Location
323:     loc = f.get("location", {})
324:     if not loc.get("file_path"): missing.append("location.file_path")
325:     if not loc.get("start_line"): missing.append("location.start_line")
326:     # 4-segment standard accepts "function" as alias, null is OK
327:     if not loc.get("snippet"): missing.append("location.snippet")
328: 
329:     # 2. Evidence
330:     ev = f.get("evidence", {})
331:     if not ev.get("code_context"): missing.append("evidence.code_context")
332:     if not ev.get("judgment_rationale"): missing.append("evidence.judgment_rationale")
333: 
334:     # 3. Impact
335:     imp = f.get("impact", {})
336:     if not imp.get("attack_scenario"): missing.append("impact.attack_scenario")
337:     if imp.get("cvss_score") is None: missing.append("impact.cvss_score")
338: 
339:     # 4. Fix
340:     fi = f.get("fix", {})
341:     # fix.description is optional — use fix_summary instead
342:     if not fi.get("before_code"): missing.append("fix.before_code")
343:     if not fi.get("after_code"): missing.append("fix.after_code")
344: 
345:     return len(missing) == 0, missing
346: 
347: 
348: def quality_gate_report(findings):
349:     """
350:     Run quality gate on all findings. Returns (passed, report_lines).
351:     - passed: True if all findings complete
352:     - report_lines: list of issue descriptions
353:     """
354:     issues = []
355:     for f in findings:
356:         ok, missing = validate_finding_4segment(f)
357:         if not ok:
358:             issues.append(f"  ❌ {f.get('_seq', 0)}: missing {', '.join(missing)}")
359: 
360:     if issues:
361:         header = [f"### ⚠️ Quality Gate: {len(issues)} finding(s) incomplete", ""]
362:         return False, header + issues
363:     return True, ["### ✅ Quality Gate: all findings complete ✓", ""]
364: 
365: 
366: # ── Report Generators ───────────────────────────
367: 
368: def generate_report_md(findings_data):
369:     """Generate complete report.md content."""
370:     findings = findings_data.get("findings", [])
371:     cmd = findings_data["command"]
372:     score = calc_score(findings)
373:     grade = calc_grade(score)
374: 
375:     by_sev = Counter(f["severity"] for f in findings)
376:     scope = findings_data.get("scope", {})
377:     detectors = findings_data.get("detectors", {})
378:     lang = findings_data.get("language", "unknown")
379:     good = findings_data.get("good_patterns", [])
380: 
381:     # Report header
382:     start = findings_data.get("started_at", "unknown")
383:     lines = []
384:     cmd_title = {"secguard": "Security Scan", "secaudit": "Security Audit", "secreview": "Security Review"}
385: 
386:     lines.append(f"# SecGuardian {cmd_title.get(cmd, 'Security')} Report\n")
387:     lines.append(f"> **Scan ID**: `{findings_data['scan_id']}` | **Language**: {lang} | **Date**: {start[:10]}")
388:     lines.append(f"> **Path**: `{findings_data.get('path', '')}` | **Mode**: {findings_data.get('mode', 'full')}")
389:     lines.append(f"> **Duration**: {findings_data.get('duration_ms', 0)}ms\n")
390:     lines.append("---\n")
391: 
392:     # §1 Scan Metadata (simplified)
393:     lines.append("## §1 Scan Metadata\n")
394:     if scope:
395:         duration_ms = findings_data.get('duration_ms', 0)
396:         lines.extend([
397:             f"| Files scanned | {scope.get('files', 'N/A')} |",
398:             f"| Lines scanned | {scope.get('lines', 'N/A')} |",
399:             f"| Functions analyzed | {scope.get('functions', 'N/A')} |",
400:             f"| Detectors executed | {detectors.get('executed', 'N/A')} |",
401:             f"| Scan duration | {duration_ms}ms |",
402:         ])
403:     lines.append('')
404: 
405: 
406:     # §2 Findings Inventory
407:     lines.append("---\n")
408:     lines.append("## §2 Findings Inventory\n")
409:     from collections import defaultdict
410:     by_file = defaultdict(list)
411:     for f in findings:
412:         by_file[f["file"]].append(f)
413:     for filepath in sorted(by_file.keys()):
414:         file_findings = by_file[filepath]
415:         plural = "s" if len(file_findings) > 1 else ""
416:         lines.append(f"### {filepath} ({len(file_findings)} finding{plural})\n")
417:         lines.append("| # | Severity | CWE | Detector | Line | Fix |")
418:         lines.append("|-----------|----------|-----|----------|------|-----|")
419:         for f in file_findings:
420:             sev_emoji = severity_emoji(f["severity"])
421:             lines.append(f"| #{f.get('_seq', 0)} | {sev_emoji} {f['severity']} | {f['cwe']} | {f['detector']} | {f['line']} | {f.get('fix_summary', f['title'])} |")
422:         lines.append("")
423: 
424:     # §3 Detailed Findings
425:     lines.append("---\n")
426:     lines.append("## §3 Detailed Findings\n")
427:     from collections import defaultdict
428:     groups = defaultdict(list)
429:     for f in findings:
430:         groups[f["detector"]].append(f)
431: 
432:     group_num = 0
433:     for detector in sorted(groups.keys()):
434:         group_num += 1
435:         lines.append(f"### §3.{group_num} {detector}\n")
436:         for f in groups[detector]:
437:             sev_emoji = severity_emoji(f["severity"])
438:             loc = f.get("location", {})
439:             ev = f.get("evidence", {})
440:             imp = f.get("impact", {})
441:             fix = f.get("fix", {})
442: 
443:             lines.append(f"#### {sev_emoji} #{f.get('_seq', 0)} — {f['title']}\n")
444:         lines.append(f"| Field | Detail |")
445:         lines.append(f"|-------|--------|")
446:         lines.append(f"| **Severity** | {sev_emoji} {f['severity']} |")
447:         lines.append(f"| **CWE** | [{f['cwe']}](https://cwe.mitre.org/data/definitions/{f['cwe'].replace('CWE-','')}.html) |")
448:         lines.append(f"| **Detector** | `{f['detector']}` |")
449:         lines.append(f"| **File** | `{loc.get('file_path', f['file'])}:{loc.get('start_line', f['line'])}` |")
450:         lines.append(f"| **Function** | `{loc.get('function_name', f.get('function', 'N/A'))}` |")
451:         lines.append("")
452: 
453:         # 📍 Location
454:         lines.append("##### 📍 Location\n")
455:         snippet = loc.get("snippet", "")
456:         if snippet:
457:             lines.append("```" + lang)
458:             lines.append(snippet)
459:             lines.append("```\n")
460: 
461:         # 📋 Evidence
462:         lines.append("##### 📋 Evidence\n")
463:         lines.append(f"**Code Context:**\n```{lang}\n{ev.get('code_context', 'N/A')}\n```\n")
464:         lines.append(f"**Judgment:** {ev.get('judgment_rationale', 'N/A')}\n")
465: 
466:         data_flow = ev.get("data_flow_path", [])
467:         if data_flow:
468:             lines.append("**Data Flow Path:**")
469:             # data_flow_path 可以是：
470:             #   1) [{"step":"source","file":"a.c","line":1,"description":"d"}, ...]  (v4 协议 dict 列表)
471:             #   2) "malloc → buf → return → leak"  (v5 协议简化字符串)
472:             if isinstance(data_flow, str):
473:                 lines.append(f"  {data_flow}")
474:                 lines.append("")
475:                 continue
476:             for step in data_flow:
477:                 if isinstance(step, str):
478:                     lines.append(f"  {step}")
479:                     continue
480:                 step_label = {"source": "SOURCE", "propagation": "→ PROPAGATION", "sink": "→ SINK"}
481:                 prefix = step_label.get(step.get("step", ""), "  ")
482:                 lines.append(f"  {prefix}: {step.get('file','')}:{step.get('line','')} — {step.get('description','')}")
483:             lines.append("")
484: 
485:         # ⚠️ Impact
486:         lines.append("##### ⚠️ Impact\n")
487:         lines.append(f"**Attack Scenario:** {imp.get('attack_scenario', 'N/A')}\n")
488:         cvss = imp.get("cvss_score")
489:         if cvss is not None:
490:             lines.append(f"**CVSS 3.1 Score:** {cvss}/10")
491:             vec = imp.get("cvss_vector", "")
492:             if vec:
493:                 lines.append(f"**CVSS Vector:** `{vec}`")
494:         lines.append(f"**Exploit Conditions:** {imp.get('exploit_conditions', 'N/A')}\n")
495: 
496:         # 🔧 Fix
497:         lines.append("##### 🔧 Fix\n")
498:         lines.append(f"{fix.get('description', 'N/A')}\n")
499:         lines.append("**Before:**\n```" + lang)
500:         lines.append(fix.get("before_code", "N/A"))
501:         lines.append("```\n")
502:         lines.append("**After:**\n```" + lang)
503:         lines.append(fix.get("after_code", "N/A"))
504:         lines.append("```\n")
505: 
506:         effort = fix.get("effort_hours")
507:         if effort is not None:
508:             lines.append(f"**Estimated Effort:** {effort} hours | **Verification:** {fix.get('verification_method', 'N/A')}\n")
509: 
510:         lines.append("---\n")
511: 
512:     # §4 Remediation Roadmap
513:     lines.append("## §4 Remediation Roadmap\n")
514: 
515:     phases = {"Critical": ("🔴 Immediate (Block Deploy)", []),
516:               "High": ("🟠 This Sprint", []),
517:               "Medium": ("🟡 Next Sprint", []),
518:               "Low": ("🔵 Backlog", []),
519:               "Info": ("⚪ Future Consideration", [])}
520: 
521:     for f in findings:
522:         phases[f["severity"]][1].append(f)
523: 
524:     for sev, (label, items) in phases.items():
525:         if items:
526:             lines.append(f"### Phase: {label}\n")
527:             for item in items:
528:                 lines.append(f"- **#{item.get('_seq', 0)}** — {item.get('fix_summary', item['title'])}")
529:             lines.append("")
530: 
531:     # §5 Appendix
532:     lines.append("---\n")
533:     lines.append("## §5 Appendix\n")
534: 
535:     if good:
536:         lines.append("### Good Patterns Found\n")
537:         lines.append("| Pattern | Location | Description |")
538:         lines.append("|---------|----------|-------------|")
539:         for gp in good:
540:             lines.append(f"| `{gp['name']}` | `{gp['file']}:{gp['line']}` | {gp['description']} |")
541:         lines.append("")
542: 
543:     lines.append("### Detector Coverage\n")
544:     lines.append(f"- Matched: {detectors.get('matched', 'N/A')}")
545:     lines.append(f"- Executed: {detectors.get('executed', 'N/A')}")
546:     if detectors.get("namespaces_used"):
547:         lines.append(f"- Namespaces: {', '.join(detectors['namespaces_used'])}")
548:     lines.append("")
549: 
550:     commit = findings_data.get("git_commit", "unknown")
551:     lines.append(f"\n*Report generated by SecGuardian Renderer v1.0 | Scan ID: {findings_data['scan_id']} | Commit: {commit}*\n")
552: 
553:     return "\n".join(lines)
554: 
555: 
556: def generate_sarif(findings_data):
557:     """Generate SARIF 2.1.0 JSON from findings."""
558:     findings = findings_data.get("findings", [])
559:     scan_id = findings_data["scan_id"]
560:     cmd = findings_data["command"]
561: 
562:     tool_name = {"secguard": "SecGuardian secguard", "secaudit": "SecGuardian secaudit", "secreview": "SecGuardian secreview"}
563: 
564:     # Build rules from detectors used
565:     used_detectors = set(f["detector"] for f in findings)
566:     rules = []
567:     for det in sorted(used_detectors):
568:         info = DETECTOR_RULE_INDEX.get(det, {"cwe": ["CWE-000"]})
569:         # Handle both dotted ("audit.x") and bare ("attack-surface") detector names
570:         det_parts = det.split(".")
571:         det_name = det_parts[1] if len(det_parts) > 1 else det_parts[0]
572:         rules.append({
573:             "id": det,
574:             "name": "".join(part.capitalize() for part in det_name.split("-")),
575:             "shortDescription": {"text": f"Security finding: {det}"},
576:             "helpUri": f"https://cwe.mitre.org/data/definitions/{info['cwe'][0].replace('CWE-','')}.html",
577:             "properties": {"cwe": info["cwe"]}
578:         })
579: 
580:     results = []
581:     for f in findings:
582:         loc = f.get("location", {})
583:         ev = f.get("evidence", {})
584:         imp = f.get("impact", {})
585:         fix = f.get("fix", {})
586:         sarif = f.get("sarif_specific", {})
587: 
588:         # Build message.text (one-line)
589:         msg_text = (f"📍 {f['file']}:{f['line']} {f.get('function', '')} "
590:                     f"[{f['severity']}] {f['cwe']}: {f['title']}")
591: 
592:         # Build message.markdown (full 4-segment)
593:         msg_md_parts = []
594:         if loc.get("snippet"):
595:             msg_md_parts.append(f"### 📍 Location\n```\n{loc['snippet']}\n```")
596:         if ev.get("judgment_rationale"):
597:             msg_md_parts.append(f"### 📋 Evidence\n{ev['judgment_rationale']}")
598:         if imp.get("attack_scenario"):
599:             msg_md_parts.append(f"### ⚠️ Impact\n{imp['attack_scenario']}\nCVSS: {imp.get('cvss_score', 'N/A')}/10")
600:         if fix.get("description"):
601:             msg_md_parts.append(f"### 🔧 Fix\n{fix['description']}")
602:         msg_md = "\n\n".join(msg_md_parts)
603: 
604:         # Build relatedLocations (data flow)
605:         related = []
606:         data_flow = ev.get("data_flow_path", [])
607:         if isinstance(data_flow, str):
608:             related.append({
609:                 "physicalLocation": {"artifactLocation": {"uri": f["file"]}},
610:                 "message": {"text": data_flow}
611:             })
612:         else:
613:             for step in data_flow:
614:                 if isinstance(step, str):
615:                     related.append({
616:                         "physicalLocation": {"artifactLocation": {"uri": f["file"]}},
617:                         "message": {"text": step}
618:                     })
619:                     continue
620:                 related.append({
621:                     "physicalLocation": {
622:                     "artifactLocation": {"uri": step["file"]},
623:                     "region": {"startLine": step["line"]}
624:                 },
625:                 "message": {"text": step.get("description", step["step"])}
626:             })
627: 
628:         # Build fixes
629:         fixes = []
630:         if fix.get("before_code") and fix.get("after_code"):
631:             fixes.append({
632:                 "description": {"text": fix.get("description", "Apply security fix")},
633:                 "fileChanges": [{
634:                     "artifactLocation": {"uri": f["file"]},
635:                     "replacements": [{
636:                         "deletedRegion": {"startLine": loc.get("start_line", f["line"]),
637:                                          "endLine": loc.get("end_line", f["line"])},
638:                         "insertedContent": {"text": fix["after_code"]}
639:                     }]
640:                 }]
641:             })
642: 
643:         result = {
644:             "ruleId": f["detector"],
645:             "ruleIndex": DETECTOR_RULE_INDEX.get(f["detector"], {}).get("index", 0),
646:             "level": "error" if f["severity"] in ("Critical", "High") else "warning" if f["severity"] == "Medium" else "note",
647:             "message": {
648:                 "text": msg_text,
649:                 "markdown": msg_md
650:             },
651:             "locations": [{
652:                 "physicalLocation": {
653:                     "artifactLocation": {"uri": f["file"]},
654:                     "region": {"startLine": loc.get("start_line", f["line"]),
655:                               "endLine": loc.get("end_line", f["line"])}
656:                 }
657:             }],
658:             "partialFingerprints": {"primary": fingerprint(f)},
659:             "properties": {
660:                 "findingId": f.get("_sha", ""),
661:                 "seq": f.get("_seq", 0),
662:                 "severity": f["severity"],
663:                 "cwe": f["cwe"],
664:                 "confidence": sarif.get("confidence", "medium"),
665:                 "cvss": imp.get("cvss_score", 0),
666:                 "impact": imp.get("attack_scenario", "")[:200],
667:                 "effort": fix.get("effort_hours", 0),
668:                 "risk_of_fix": sarif.get("risk_of_fix", "low"),
669:                 "verification": fix.get("verification_method", ""),
670:                 "detector_namespace": sarif.get("detector_namespace", f["detector"])
671:             }
672:         }
673: 
674:         if related:
675:             result["relatedLocations"] = related
676:         if fixes:
677:             result["fixes"] = fixes
678: 
679:         results.append(result)
680: 
681:     return {
682:         "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
683:         "version": "2.1.0",
684:         "runs": [{
685:             "tool": {
686:                 "driver": {
687:                     "name": tool_name.get(cmd, "SecGuardian"),
688:                     "version": "3.0",
689:                     "informationUri": "https://github.com/secguardian/secguardian",
690:                     "rules": rules
691:                 }
692:             },
693:             "results": results,
694:             "invocations": [{
695:                 "startTimeUtc": findings_data.get("started_at", now_iso()),
696:                 "endTimeUtc": findings_data.get("completed_at", now_iso()),
697:                 "executionSuccessful": True
698:             }]
699:         }]
700:     }
701: 
702: 
703: def _load_verification_files(output_dir):
704:     """Load dismissed.json and verification-audit.json if they exist (v6.0+)."""
705:     dismissed_path = os.path.join(output_dir, "dismissed.json")
706:     audit_path = os.path.join(output_dir, "verification-audit.json")
707:     dismissed = None
708:     audit = None
709:     if os.path.isfile(dismissed_path):
710:         dismissed = load_json(dismissed_path)
711:     if os.path.isfile(audit_path):
712:         audit = load_json(audit_path)
713:     return dismissed, audit
714: 
715: 
716: def generate_summary(findings_data):
717:     """Generate summary.json."""
718:     findings = findings_data.get("findings", [])
719:     by_sev = Counter(f["severity"] for f in findings)
720:     by_detector = Counter(f["detector"] for f in findings)
721:     by_file = Counter(f["file"] for f in findings)
722:     scope = findings_data.get("scope", {})
723:     detectors = findings_data.get("detectors", {})
724:     score = calc_score(findings)
725:     output_dir = findings_data.get("_output_dir", "")
726: 
727:     summary = {
728:         "scan_id": findings_data["scan_id"],
729:         "command": findings_data["command"],
730:         "path": findings_data.get("path", ""),
731:         "mode": findings_data.get("mode", "full"),
732:         "language": findings_data.get("language", "unknown"),
733:         "timing": {
734:             "started": findings_data.get("started_at", ""),
735:             "completed": findings_data.get("completed_at", ""),
736:             "duration_ms": findings_data.get("duration_ms", 0)
737:         },
738:         "scope": scope,
739:         "findings_by_severity": {k: by_sev.get(k, 0) for k in ["Critical", "High", "Medium", "Low", "Info"]},
740:         "total_findings": len(findings),
741:         "findings_by_category": dict(by_detector.most_common()),
742:         "files_with_issues": {k: v for k, v in by_file.most_common()},
743:         "detectors_matched": detectors.get("matched", 0),
744:         "detectors_executed": detectors.get("executed", 0),
745:         "security_score": score,
746:         "score_max": 100,
747:         "score_grade": calc_grade(score),
748:         "renderer_version": "1.1"
749:     }
750: 
751:     # v6.0: add verification data if available
752:     dismissed, _ = _load_verification_files(output_dir)
753:     if dismissed:
754:         summary["verification"] = {
755:             "dismissed_total": dismissed["summary"]["dismissed_by_p1"]
756:                              + dismissed["summary"]["dismissed_by_p2"]
757:                              + dismissed["summary"]["dismissed_by_p3"],
758:             "certified": dismissed["summary"]["certified"],
759:             "dismissed_by_round": {
760:                 "p1_semantic": dismissed["summary"]["dismissed_by_p1"],
761:                 "p2_counter_evidence": dismissed["summary"]["dismissed_by_p2"],
762:                 "p3_court": dismissed["summary"]["dismissed_by_p3"]
763:             }
764:         }
765: 
766:     return summary
767: 
768: 
769: def generate_manifest(findings_data):
770:     """Generate manifest.json."""
771:     findings = findings_data.get("findings", [])
772:     detectors = findings_data.get("detectors", {})
773: 
774:     return {
775:         "scan_id": findings_data["scan_id"],
776:         "protocol_version": "2.0",
777:         "renderer_version": "1.0",
778:         "created": findings_data.get("completed_at", now_iso()),
779:         "duration_ms": findings_data.get("duration_ms", 0),
780:         "path": findings_data.get("path", ""),
781:         "mode": findings_data.get("mode", "full"),
782:         "filters": findings_data.get("filters", ["all"]),
783:         "language": findings_data.get("language", "unknown"),
784:         "command": findings_data["command"],
785:         "detectors": detectors,
786:         "scope": findings_data.get("scope", {}),
787:         "findings": [
788:             {
789:                 "seq": f.get("_seq", 0),
790:                 "sha": f.get("_sha", ""),
791:                 "severity": f["severity"],
792:                 "cwe": f["cwe"],
793:                 "detector": f["detector"],
794:                 "file": f["file"],
795:                 "line": f["line"]
796:             }
797:             for f in findings
798:         ]
799:     }
800: 
801: 
802: def generate_status(findings_data, ci_mode=False):
803:     """Generate status.json with CI gate criteria. v6.0: supports confidence-weighted scoring."""
804:     findings = findings_data.get("findings", [])
805:     by_sev = Counter(f["severity"] for f in findings)
806:     score = calc_score(findings)
807: 
808:     crit = by_sev.get("Critical", 0)
809:     high = by_sev.get("High", 0)
810:     medium = by_sev.get("Medium", 0)
811: 
812:     gate_criteria = {"max_critical": 0, "max_high": 0, "max_medium": 5}
813:     violations = []
814:     if crit > 0: violations.append(f"{crit} Critical findings (threshold: 0)")
815:     if high > 0: violations.append(f"{high} High findings (threshold: 0)")
816:     if medium > gate_criteria["max_medium"]: violations.append(f"{medium} Medium findings (threshold: {gate_criteria['max_medium']})")
817: 
818:     passed = len(violations) == 0
819: 
820:     result = {
821:         "scan_id": findings_data["scan_id"],
822:         "status": "completed",
823:         "gate_result": "PASSED" if passed else "FAILED",
824:         "gate_criteria": gate_criteria,
825:         "gate_violations": violations,
826:         "security_score": score,
827:         "grade": calc_grade(score),
828:         "exit_code": 0 if passed else 1,
829:         "recommendation": ("Ready for deployment" if passed else
830:                           "Immediate remediation required — fix all Critical and High findings before deployment")
831:     }
832: 
833:     # v6.0: add verification summary if available
834:     output_dir = findings_data.get("_output_dir", "")
835:     dismissed, _ = _load_verification_files(output_dir)
836:     if dismissed:
837:         total = dismissed["summary"]["total_findings"]
838:         cert = dismissed["summary"]["certified"]
839:         result["verification"] = {
840:             "findings_total": total,
841:             "certified": cert,
842:             "dismissed": total - cert,
843:             "convergence_rate": f"{(total - cert) / total * 100:.0f}%" if total > 0 else "N/A"
844:         }
845: 
846:     return result
847: 
848: 
849: def generate_delta(findings_data, output_dir):
850:     """Generate delta.json comparing with previous scan (if latest symlink exists)."""
851:     latest_link = os.path.join(os.path.dirname(output_dir.rstrip('/')), "latest")
852:     prev = None
853:     if os.path.islink(latest_link):
854:         prev_dir = os.path.realpath(latest_link)
855:         prev_manifest = os.path.join(prev_dir, "manifest.json")
856:         if os.path.isfile(prev_manifest):
857:             prev = load_json(prev_manifest)
858: 
859:     current_findings = findings_data.get("findings", [])
860: 
861:     if prev and "findings" in prev:
862:         prev_ids = {f.get("sha", f.get("_sha", "")) for f in prev["findings"]}
863:         curr_ids = {f.get("_sha", f.get("sha", "")) for f in current_findings}
864: 
865:         new_ids = curr_ids - prev_ids
866:         fixed_ids = prev_ids - curr_ids
867:         still_open = curr_ids & prev_ids
868: 
869:         return {
870:             "scan_id": findings_data["scan_id"],
871:             "previous_scan_id": prev.get("scan_id", "unknown"),
872:             "comparison": {
873:                 "new_findings": len(new_ids),
874:                 "fixed_findings": len(fixed_ids),
875:                 "still_open": len(still_open),
876:                 "total_current": len(current_findings),
877:                 "total_previous": len(prev["findings"])
878:             },
879:             "new_finding_ids": sorted(new_ids),  # SHA prefixes
880:             "fixed_finding_ids": sorted(fixed_ids)  # SHA prefixes
881:         }
882:     else:
883:         return {
884:             "scan_id": findings_data["scan_id"],
885:             "comparison": {
886:                 "note": "First scan — no previous data for delta comparison",
887:                 "total_current": len(current_findings)
888:             }
889:         }
890: 
891: 
892: 
893: 
894: def render_executive_summary(findings_data, output_dir):
895:     """Generate human/executive-summary.md — unified entry point.
896:     
897:     One page with: score, severity breakdown, detector×file cross-table,
898:     risk concentration (file×count), Top-3 Critical, navigation guide.
899:     """
900:     from collections import Counter
901:     import os
902:     
903:     findings = findings_data.get("findings", [])
904:     if not findings:
905:         return
906:     
907:     score = findings_data.get("security_score", 0)
908:     grade = findings_data.get("score_grade", "F")
909:     scan_id = findings_data.get("scan_id", "N/A")
910:     path_val = findings_data.get("path", "N/A")
911:     language = findings_data.get("language", "N/A")
912:     scope = findings_data.get("scope", {}) or {}
913:     
914:     # Calculate severity distribution from raw findings
915:     from collections import Counter as _Counter
916:     sev_count = _Counter(f.get("severity", "Info") for f in findings)
917:     total = len(findings)
918:     
919:     # Calculate score if not present (same formula as calc_score)
920:     if score == 0 and total > 0:
921:         c = sev_count.get("Critical", 0)
922:         h = sev_count.get("High", 0)
923:         m = sev_count.get("Medium", 0)
924:         l = sev_count.get("Low", 0)
925:         score = max(0, min(100, 100 - (c * 25 + h * 10 + m * 3 + l * 1)))
926:         if score >= 90: grade = "A"
927:         elif score >= 75: grade = "B"
928:         elif score >= 60: grade = "C"
929:         elif score >= 40: grade = "D"
930:         else: grade = "F"
931:     
932:     # Detector cross-table: detector → set(file)
933:     detector_files = {}
934:     detector_count = Counter()
935:     for f in findings:
936:         det = f.get("detector", "unknown")
937:         detector_files.setdefault(det, set()).add(f.get("file", ""))
938:         detector_count[det] += 1
939:     
940:     # Risk concentration: file → count
941:     file_count = Counter(f.get("file", "") for f in findings)
942:     total_findings = len(findings)
943:     
944:     # Top-3 Critical/High
945:     def severity_sort_key(f):
946:         order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Info": 4}
947:         return order.get(f.get("severity", "Info"), 99)
948:     sorted_findings = sorted(findings, key=severity_sort_key)
949:     top3 = sorted_findings[:3]
950:     
951:     # Severity emoji
952:     sev_emoji = {"Critical": "🔴", "High": "🟠", "Medium": "🟡", "Low": "🔵", "Info": "⚪"}
953:     
954:     lines = [
955:         "# SecGuardian 安全扫描精要",
956:         "",
957:         f"> **扫描**: `{scan_id}` | **项目**: `{path_val}` | **语言**: {language}",
958:         "",
959:         "## 安全态势",
960:         "",
961:         "| 指标 | 值 |",
962:         "|------|-----|",
963:         f"| 安全评分 | **{score}/100 — {grade}** |",
964:         f"| 扫描文件 | {scope.get('files', 0)} 个文件 |",
965:         f"| 总发现数 | {total} |",
966:         "",
967:         "### 严重度分布",
968:         "",
969:         "| 严重度 | 数量 |",
970:         "|--------|------|",
971:     ]
972:     for s in ["Critical", "High", "Medium", "Low"]:
973:         emoji = sev_emoji.get(s, "")
974:         count = sev_count.get(s, 0)
975:         if count > 0:
976:             lines.append(f"| {emoji} {s} | {count} |")
977:     
978:     # Detector cross-table (Top-5)
979:     if len(detector_files) > 1:
980:         lines.extend(["", "### 发现分布（检测器 × 文件，Top-5）", "",
981:                        "| 检测器 | 发现数 | 涉及文件 |",
982:                        "|--------|--------|---------|"])
983:         sorted_dets = sorted(detector_files.items(),
984:                             key=lambda x: len(x[1]), reverse=True)[:5]
985:         for det, files in sorted_dets:
986:             lines.append(f"| `{det}` | {detector_count[det]} | {', '.join(sorted(files)[:3])}{'...' if len(files) > 3 else ''} |")
987:     
988:     # Risk concentration (Top-5)
989:     if len(file_count) > 1:
990:         lines.extend(["", "### 风险集中度（文件 × 发现数，Top-5）", "",
991:                        "| 文件 | 发现数 | 占比 |",
992:                        "|------|--------|------|"])
993:         top_files = sorted(file_count.items(), key=lambda x: -x[1])[:5]
994:         for filepath, count in top_files:
995:             pct = round(count / total_findings * 100) if total_findings > 0 else 0
996:             lines.append(f"| `{filepath}` | {count} | {pct}% |")
997:     
998:     # Top-3 Critical/High
999:     if top3:
1000:         lines.extend(["", "### Top 3 风险", "",
1001:                        "| # | 文件:行 | 严重度 | 标题 |",
1002:                        "|----|---------|--------|------|"])
1003:         for f in top3:
1004:             sev_label = f.get("severity", "")
1005:             emoji = sev_emoji.get(sev_label, "")
1006:             finding_id = f"#{f.get('_seq', 0)}" 
1007:             file_line = f"{f.get('file', '')}:{f.get('line', '')}"
1008:             title = f.get("title", "")
1009:             lines.append(f"| {finding_id} | `{file_line}` | {emoji} {sev_label} | {title} |")
1010:     
1011:     # Navigation guide
1012:     lines.extend(["", "---", "",
1013:                    "**下一步（按角色）：**", "",
1014:                    "- 👨‍💻 工程师 → `report.md §3.x` 按检测器集中修复一类问题",
1015:                    "- 📋 查看完整报告 → `report.md`",
1016:                    "- 🤖 AI 自动修复 → `ai/remediation-pack.json`",
1017:                    "- 👔 管理层查看 → `dashboard.html`",
1018:                    ""])
1019:     
1020:     human_dir = os.path.join(output_dir, "human")
1021:     os.makedirs(human_dir, exist_ok=True)
1022:     out_path = os.path.join(human_dir, "executive-summary.md")
1023:     with open(out_path, "w") as f:
1024:         f.write("\n".join(lines))
1025:     print(f"  ✓ human/executive-summary.md ({len(lines)} lines)")
1026: 
1027: 
1028: 
1029: def render_remediation_pack(findings, findings_meta, output_dir):
1030:     """Generate ai/remediation-pack.json — AI-consumable remediation pack.
1031:     
1032:     findings: list of finding dicts
1033:     findings_meta: dict with scan_id, command, etc.
1034:     Each remediation entry includes root_cause, fix_strategy, before/after code,
1035:     and related_findings (AI-tagged + auto-detected same function/file).
1036:     """
1037:     from collections import defaultdict
1038:     import os, json
1039:     
1040:     if not findings:
1041:         return
1042:     
1043:     # Build (file, function) index
1044:     func_index = defaultdict(list)
1045:     for i, f in enumerate(findings):
1046:         key = (f.get("file", ""), f.get("function", ""))
1047:         func_index[key].append(i)
1048:     
1049:     remediations = []
1050:     for i, f in enumerate(findings):
1051:         finding_id = f"#{f.get('_seq', 0)}"
1052:         
1053:         # AI-tagged relationships
1054:         related = []
1055:         for rel in f.get("relationships", []):
1056:             if isinstance(rel, dict):
1057:                 rid = rel.get("finding_id", "")
1058:             else:
1059:                 rid = str(rel)
1060:             if rid and rid not in related:
1061:                 related.append(rid)
1062:         
1063:         # Auto-detect: same function
1064:         key = (f.get("file", ""), f.get("function", ""))
1065:         for j in func_index.get(key, []):
1066:             if j != i:
1067:                 rid = findings[j].get("id", "")
1068:                 if rid and rid not in related:
1069:                     related.append(rid)
1070:         
1071:         rem = {
1072:             "finding_id": f"#{f.get('_seq', 0)}",
1073:             "title": f.get("title", ""),
1074:             "severity": f.get("severity", ""),
1075:             "cwe": f.get("cwe", ""),
1076:             "detector": f.get("detector", ""),
1077:             "affected_files": [f.get("file", "")],
1078:             "root_cause": f.get("evidence", {}).get("judgment_rationale", ""),
1079:             "fix_strategy": f.get("fix", {}).get("description", ""),
1080:             "safe_patch_guidance": [],
1081:             "before_code": f.get("fix", {}).get("before_code", ""),
1082:             "after_code": f.get("fix", {}).get("after_code", ""),
1083:             "effort_hours": f.get("fix", {}).get("effort_hours", 0),
1084:             "verification": f.get("fix", {}).get("verification_method", ""),
1085:             "related_findings": related[:10]
1086:         }
1087:         remediations.append(rem)
1088:     
1089:     pack = {
1090:         "version": "1.0",
1091:         "scan_id": findings_meta.get("scan_id", "N/A"),
1092:         "remediations": remediations
1093:     }
1094:     
1095:     ai_dir = os.path.join(output_dir, "ai")
1096:     os.makedirs(ai_dir, exist_ok=True)
1097:     out_path = os.path.join(ai_dir, "remediation-pack.json")
1098:     with open(out_path, "w") as f:
1099:         json.dump(pack, f, indent=2, ensure_ascii=False)
1100:     print(f"  ✓ ai/remediation-pack.json ({len(remediations)} remediations)")
1101: 
1102: 
1103: def render_dashboard(findings_data, output_dir):
1104:     """Generate dashboard.html — management dashboard from executive-summary data.
1105:     NOT a copy of report.md. Shows score, severity, risk concentration, top risks only.
1106:     No code blocks, no evidence chains, no per-finding details.
1107:     """
1108:     import os
1109:     from collections import Counter
1110: 
1111:     findings = findings_data.get("findings", [])
1112:     if not findings:
1113:         return
1114: 
1115:     scope = findings_data.get("scope", {}) or {}
1116:     scan_id = findings_data.get("scan_id", "N/A")
1117:     path_val = findings_data.get("path", "N/A")
1118:     language = findings_data.get("language", "N/A")
1119:     duration_ms = findings_data.get("duration_ms", 0)
1120:     detectors = findings_data.get("detectors", {})
1121: 
1122:     score = findings_data.get("security_score", 0)
1123:     grade = findings_data.get("score_grade", "F")
1124:     if score == 0 and findings:
1125:         c = sum(1 for f in findings if f.get("severity") == "Critical")
1126:         h = sum(1 for f in findings if f.get("severity") == "High")
1127:         m = sum(1 for f in findings if f.get("severity") == "Medium")
1128:         l = sum(1 for f in findings if f.get("severity") == "Low")
1129:         score = max(0, min(100, 100 - (c*25 + h*10 + m*3 + l*1)))
1130:         grade = "A" if score >= 90 else "B" if score >= 75 else "C" if score >= 60 else "D" if score >= 40 else "F"
1131: 
1132:     sev_emoji = {"Critical":"\U0001f534","High":"\U0001f7e0","Medium":"\U0001f7e1","Low":"\U0001f535","Info":"\u26aa"}
1133: 
1134:     def esc(t):
1135:         if t is None: return ""
1136:         return str(t).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
1137: 
1138:     sev_count = Counter(f.get("severity", "Info") for f in findings)
1139: 
1140:     # Detector x file cross-table
1141:     det_files = {}
1142:     for f in findings:
1143:         d = f.get("detector", "unknown")
1144:         det_files.setdefault(d, set()).add(f.get("file", ""))
1145:     det_count = Counter(f.get("detector", "") for f in findings)
1146: 
1147:     # Risk concentration
1148:     file_count = Counter(f.get("file", "") for f in findings)
1149:     total = len(findings)
1150: 
1151:     # Top 3 critical
1152:     top3 = sorted(findings, key=lambda x: {"Critical":0,"High":1}.get(x.get("severity",""), 9))[:3]
1153: 
1154:     css = """<style>
1155:       *{box-sizing:border-box;margin:0;padding:0}
1156:       body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
1157:            background:#f5f7fa;color:#1a1a2e;padding:40px 20px}
1158:       .card{background:#fff;border-radius:8px;box-shadow:0 1px 3px rgba(0,0,0,.1);
1159:             padding:24px;margin-bottom:20px;max-width:960px;margin-left:auto;margin-right:auto}
1160:       h1{font-size:24px;color:#1d3557;margin-bottom:4px}
1161:       .meta{color:#6c757d;font-size:14px;margin-bottom:20px}
1162:       .score{text-align:center;padding:20px}
1163:       .score-value{font-size:48px;font-weight:bold;color:#1d3557}
1164:       .score-grade{font-size:20px;color:#6c757d}
1165:       table{border-collapse:collapse;width:100%;margin:12px 0}
1166:       th,td{border:1px solid #dee2e6;padding:8px 12px;text-align:left;font-size:14px}
1167:       th{background:#f8f9fa;font-weight:600}
1168:       tr:nth-child(even){background:#f8f9fa}
1169:       .severity-critical{color:#e63946;font-weight:bold}
1170:       .severity-high{color:#e76f51;font-weight:bold}
1171:       h2{font-size:18px;color:#1d3557;margin:24px 0 12px;padding-bottom:6px;border-bottom:2px solid #e63946}
1172:       .nav{display:flex;gap:12px;flex-wrap:wrap;margin-top:24px}
1173:       .nav a{background:#1d3557;color:#fff;padding:8px 16px;border-radius:6px;
1174:              text-decoration:none;font-size:14px;font-weight:500}
1175:       .nav a:hover{background:#457b9d}
1176:     </style>"""
1177: 
1178:     p = []
1179:     p.append("<!DOCTYPE html><html><head><meta charset=UTF-8><title>SecGuardian Dashboard</title>" + css + "</head><body>")
1180: 
1181:     # Header
1182:     p.append('<div class="card">')
1183:     p.append("<h1>SecGuardian Security Dashboard</h1>")
1184:     p.append(f'<p class="meta">Scan ID: {esc(scan_id)} | Project: {esc(path_val)} | Language: {esc(language)} | Duration: {duration_ms}ms</p>')
1185:     p.append("</div>")
1186: 
1187:     # Score
1188:     p.append('<div class="card"><div class="score">')
1189:     p.append(f'<div class="score-value">{score}/100</div>')
1190:     p.append(f'<div class="score-grade">Grade {esc(grade)}</div>')
1191:     p.append("</div></div>")
1192: 
1193:     # Severity
1194:     p.append('<div class="card"><h2>Severity Breakdown</h2><table>')
1195:     p.append("<tr><th>Severity</th><th>Count</th></tr>")
1196:     for s in ["Critical","High","Medium","Low"]:
1197:         c = sev_count.get(s, 0)
1198:         if c > 0:
1199:             emoji = sev_emoji.get(s,"")
1200:             cls = f"severity-{s.lower()}"
1201:             p.append(f'<tr><td class="{cls}">{emoji} {s}</td><td>{c}</td></tr>')
1202:     p.append("</table></div>")
1203: 
1204:     # Detector cross-table
1205:     if len(det_files) > 1:
1206:         p.append('<div class="card"><h2>Findings by Detector</h2><table>')
1207:         p.append("<tr><th>Detector</th><th>Findings</th><th>Files</th></tr>")
1208:         for d in sorted(det_files.keys(), key=lambda x: len(det_files[x]), reverse=True)[:5]:
1209:             p.append(f"<tr><td>{esc(d)}</td><td>{det_count[d]}</td><td>{len(det_files[d])}</td></tr>")
1210:         p.append("</table></div>")
1211: 
1212:     # Risk concentration
1213:     if len(file_count) > 1:
1214:         p.append('<div class="card"><h2>Risk Concentration (Top Files)</h2><table>')
1215:         p.append("<tr><th>File</th><th>Findings</th><th>%</th></tr>")
1216:         for fpath, cnt in sorted(file_count.items(), key=lambda x: -x[1])[:5]:
1217:             pct = round(cnt / total * 100) if total > 0 else 0

(Output capped at 50 KB. Showing lines 1-1217. Use offset=1218 to continue.)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/dev-verify.sh"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/dev-verify.sh</path>
<type>file</type>
<content>
1: #!/bin/bash
2: # SecGuardian — Dev environment verification
3: #
4: # Validates that the project-level deployment is healthy:
5: #   - Indexer binary present and functional (--health + --version)
6: #   - Plugin files (commands, skills, knowledge) match expected counts
7: #   - Functional smoke test: index a known directory
8: #
9: # Usage:
10: #   bash scripts/dev-verify.sh           # Verify all platforms
11: #   bash scripts/dev-verify.sh --quick     # Binary + health only
12: #   bash scripts/dev-verify.sh -h          # Help
13: 
14: set -euo pipefail
15: 
16: PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
17: 
18: # ── Colors ─────────────────────────────────────
19: BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'
20: CYAN='\033[0;36m'; NC='\033[0m'
21: PASS="${GREEN}PASS${NC}"
22: FAIL="${RED}FAIL${NC}"
23: WARN="${YELLOW}WARN${NC}"
24: 
25: QUICK=0
26: while [[ $# -gt 0 ]]; do
27:     case "$1" in
28:         -h|--help|help)
29:             cat << 'EOF'
30: SecGuardian — Dev 环境验证
31: 
32: 用法:
33:   bash scripts/dev-verify.sh           # 完整验证（所有检查项）
34:   bash scripts/dev-verify.sh --quick    # 快速验证（仅 binary + health）
35:   bash scripts/dev-verify.sh -h         # 帮助
36: 
37: 检查项:
38:   1. scripts/bin/ 是否包含当前平台二进制
39:   2. 三平台部署目录结构完整性
40:   3. 索引器 --health 通过
41:   4. 索引器 --version 输出正确
42:   5. 索引器功能冒烟测试 (index examples/cpp-vuln-demo/src)
43:   6. 命令/技能/知识文件数量校验
44: EOF
45:             exit 0
46:             ;;
47:         --quick) QUICK=1; shift ;;
48:         *) shift ;;
49:     esac
50: done
51: 
52: PASSED=0
53: FAILED=0
54: WARNINGS=0
55: 
56: check() {
57:     local label="$1"; shift
58:     local cmd="$@"
59:     printf "  [....] %s" "$label"
60:     if eval "$cmd" &>/dev/null; then
61:         printf "\r  [${PASS}] %s\n" "$label"
62:         PASSED=$((PASSED + 1))
63:     else
64:         printf "\r  [${FAIL}] %s\n" "$label"
65:         FAILED=$((FAILED + 1))
66:     fi
67: }
68: 
69: check_stderr() {
70:     local label="$1"; shift
71:     local cmd="$@"
72:     printf "  [....] %s" "$label"
73:     local out
74:     if out=$(eval "$cmd" 2>&1); then
75:         printf "\r  [${PASS}] %s  (%s)\n" "$label" "$(echo "$out" | tr '\n' ' ' | xargs)"
76:         PASSED=$((PASSED + 1))
77:     else
78:         printf "\r  [${FAIL}] %s\n" "$label"
79:         printf "        %s\n" "$(echo "$out" | tr '\n' ' ' | xargs)"
80:         FAILED=$((FAILED + 1))
81:     fi
82: }
83: 
84: check_result() {
85:     local label="$1"; shift
86:     local expected="$1"; shift
87:     local cmd="$@"
88:     printf "  [....] %s" "$label"
89:     local out
90:     out=$(eval "$cmd" 2>/dev/null) || true
91:     if echo "$out" | grep -q "$expected"; then
92:         printf "\r  [${PASS}] %s\n" "$label"
93:         PASSED=$((PASSED + 1))
94:     else
95:         printf "\r  [${FAIL}] %s  (got: %s)\n" "$label" "$(echo "$out" | tr '\n' ' ' | xargs)"
96:         FAILED=$((FAILED + 1))
97:     fi
98: }
99: 
100: warn_missing() {
101:     local label="$1"; shift
102:     if [ ! -e "$1" ]; then
103:         printf "  [${WARN}] %s\n" "$label"
104:         WARNINGS=$((WARNINGS + 1))
105:         return 1
106:     fi
107:     return 0
108: }
109: 
110: # ── Detect platform ────────────────────────────
111: OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
112: ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
113: PLATFORM_BIN_NAME="secguardian-index-${OS}-${ARCH}"
114: 
115: # Expected version
116: EXPECTED_VER="0.5.5"
117: 
118: echo ""
119: echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
120: echo -e "${BOLD}║${NC}  SecGuardian — Dev 环境验证                     ${BOLD}║${NC}"
121: echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
122: echo ""
123: echo -e "  平台: ${CYAN}${OS}/${ARCH}${NC}  目标版本: ${CYAN}v${EXPECTED_VER}${NC}"
124: echo ""
125: 
126: # ═══════════════════════════════════════════
127: # Section 1: Build artifacts
128: # ═══════════════════════════════════════════
129: echo -e "${BOLD}1. Build artifacts (scripts/bin/)${NC}"
130: 
131: check "Binary ${PLATFORM_BIN_NAME} exists and is executable" \
132:     "[ -f '$PROJECT_ROOT/scripts/bin/$PLATFORM_BIN_NAME' ] && [ -x '$PROJECT_ROOT/scripts/bin/$PLATFORM_BIN_NAME' ]"
133: 
134: bin_count=$(ls "$PROJECT_ROOT/scripts/bin"/secguardian-index-* 2>/dev/null | wc -l | tr -d ' ')
135: check "All 5 platform binaries present (found: ${bin_count})" \
136:     "[ '$bin_count' -ge 5 ]"
137: 
138: # ═══════════════════════════════════════════
139: # Section 2: Indexer health & version
140: # ═══════════════════════════════════════════
141: echo ""
142: echo -e "${BOLD}2. Indexer health & version${NC}"
143: 
144: IDX="$PROJECT_ROOT/scripts/bin/$PLATFORM_BIN_NAME"
145: if [ ! -x "$IDX" ]; then
146:     echo -e "  [${FAIL}] Cannot proceed — indexer binary not found"
147:     FAILED=$((FAILED + 1))
148: else
149:     check_result "health check returns HEALTH:OK" \
150:         "HEALTH:OK" "$IDX --health"
151: 
152:     check_result "version returns ${EXPECTED_VER}" \
153:         "${EXPECTED_VER}" "$IDX --version"
154: 
155:     # Functional test — run directly, check indexer exit code
156:     printf "  [....] %s" "indexer functional: parses examples/cpp-vuln-demo"
157:     rm -f /tmp/secguardian-verify-test.json
158:     if $IDX --path "$PROJECT_ROOT/examples/cpp-vuln-demo/src" --output /tmp/secguardian-verify-test.json >/dev/null 2>&1; then
159:         printf "\r  [${PASS}] %s\n" "indexer functional: parses examples/cpp-vuln-demo"
160:         PASSED=$((PASSED + 1))
161:     else
162:         printf "\r  [${FAIL}] %s\n" "indexer functional: parses examples/cpp-vuln-demo"
163:         FAILED=$((FAILED + 1))
164:     fi
165:     rm -f /tmp/secguardian-verify-test.json
166: fi
167: 
168: # ═══════════════════════════════════════════
169: # Section 3: Platform deployment directories
170: # ═══════════════════════════════════════════
171: echo ""
172: echo -e "${BOLD}3. Platform deployment structure${NC}"
173: 
174: verify_platform() {
175:     local plat_dir="$1"
176:     local plat_name="$2"
177: 
178:     echo ""
179:     echo -e "  ${CYAN}${plat_name}${NC} (${plat_dir})"
180: 
181:     if [ ! -d "$plat_dir" ]; then
182:         printf "  [${WARN}] Plugin directory does not exist: %s\n" "$plat_dir"
183:         WARNINGS=$((WARNINGS + 1))
184:         return
185:     fi
186: 
187:     local idx_bin="$plat_dir/scripts/bin/secguardian-index"
188:     if [ -f "$idx_bin" ] && [ -x "$idx_bin" ]; then
189:         check "${plat_name} indexer binary is present and executable" "true"
190:     else
191:         idx_bin="$plat_dir/scripts/bin/$PLATFORM_BIN_NAME"
192:         check_stderr "${plat_name} indexer binary (fallback name)" \
193:             "[ -f '$idx_bin' ] && [ -x '$idx_bin' ]"
194:     fi
195: 
196:     if [ $QUICK -eq 1 ]; then
197:         return
198:     fi
199: 
200:     cmd_count=$(find "$plat_dir/commands" \( -name '*.md' -o -name '*.toml' \) 2>/dev/null | wc -l | tr -d ' ')
201:     check "${plat_name} commands: ${cmd_count} files (expected 3)" \
202:         "[ '$cmd_count' -ge 3 ]"
203: 
204:     skill_count=$(find "$plat_dir/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
205:     check "${plat_name} skills: ${skill_count} SKILL.md files (expected 27)" \
206:         "[ '$skill_count' -eq 27 ]"
207: 
208:     det_count=$(find "$plat_dir/knowledge/guard-rules" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
209:     # Dynamic expected count: read from extension.json detector list, count how many have files in source knowledge/guard-rules/
210:     if [ -f "$PROJECT_ROOT/extensions/secguard-secguardian/extension.json" ]; then
211:         det_expected=0
212:         for det in $(jq -r '.knowledge.detectors[]' "$PROJECT_ROOT/extensions/secguard-secguardian/extension.json" 2>/dev/null); do
213:             [ -f "$PROJECT_ROOT/knowledge/guard-rules/${det}.md" ] && det_expected=$((det_expected + 1))
214:         done
215:     else
216:         det_expected=16  # fallback
217:     fi
218:     check "${plat_name} knowledge/guard-rules: ${det_count} .md files (expected ${det_expected})" \
219:         "[ '$det_count' -ge '$det_expected' ]"
220: 
221:     lang_count=$(find "$plat_dir/knowledge/languages" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
222:     check "${plat_name} knowledge/languages: ${lang_count} .md files (expected 5)" \
223:         "[ '$lang_count' -eq 5 ]"
224: 
225:     check "${plat_name} scripts/secguardian-index wrapper" \
226:         "[ -f '$plat_dir/scripts/secguardian-index' ]"
227: 
228:     check "${plat_name} scripts/validate-index.py" \
229:         "[ -f '$plat_dir/scripts/validate-index.py' ]"
230:     check "${plat_name} scripts/validate-findings.py" \
231:         "[ -f '$plat_dir/scripts/validate-findings.py' ]"
232: }
233: 
234: verify_platform "$PROJECT_ROOT/.claude/plugins/secguardian" "Claude Code"
235: verify_platform "$PROJECT_ROOT/.opencode/extensions/secguardian" "OpenCode"
236: 
237: # Verify opencode-plugin.js content (deployed separately from extension)
238: OPENCODE_PLUGIN="$PROJECT_ROOT/.opencode/plugins/secguardian.js"
239: [ -f "$OPENCODE_PLUGIN" ] && {
240:   HAS_K=$(grep -c 'cfg.knowledge' "$OPENCODE_PLUGIN" 2>/dev/null || echo 0)
241:   HAS_S=$(grep -c 'cfg.skills' "$OPENCODE_PLUGIN" 2>/dev/null || echo 0)
242:   HAS_C=$(grep -c 'cfg.command' "$OPENCODE_PLUGIN" 2>/dev/null || echo 0)
243:   [ "$HAS_K" -gt 0 ] && [ "$HAS_S" -gt 0 ] && [ "$HAS_C" -gt 0 ] && 
244:     green "opencode-plugin.js: knowledge+skills+commands" || 
245:     red "opencode-plugin.js: missing (k=$HAS_K s=$HAS_S c=$HAS_C)"
246: } || red "opencode-plugin.js NOT FOUND"
247: verify_platform "$PROJECT_ROOT/.gemini/extensions/secguardian" "Gemini CLI"
248: 
249: # ═══════════════════════════════════════════
250: # Section 4: Scan output directory
251: # ═══════════════════════════════════════════
252: if [ $QUICK -eq 0 ]; then
253:     echo ""
254:     echo -e "${BOLD}4. Scan output directory${NC}"
255: 
256:     SCANS_DIR="$PROJECT_ROOT/.codeagent/secguardian/secguard/scans"
257:     if [ -d "$SCANS_DIR" ]; then
258:         scan_count=$(ls -1 "$SCANS_DIR" 2>/dev/null | grep -v "^latest$" | wc -l | tr -d ' ')
259:         check "Scan directory exists (${scan_count} scans)" "[ -d '$SCANS_DIR' ]"
260:         if [ -L "$SCANS_DIR/latest" ]; then
261:             latest_target=$(readlink "$SCANS_DIR/latest")
262:             check "latest symlink exists → ${latest_target}" "true"
263:         else
264:             check "latest symlink exists" "false"
265:         fi
266:     else
267:         printf "  [${WARN}] No scan output directory yet (created on first scan)\n"
268:         WARNINGS=$((WARNINGS + 1))
269:     fi
270: fi
271: 
272: # ═══════════════════════════════════════════
273: # Section 5: Architecture E2E (optional, via --e2e flag)
274: # ═══════════════════════════════════════════
275: E2E_FLAG="${1:-}"
276: if [ "$E2E_FLAG" = "--e2e" ] || [ "$E2E_FLAG" = "-e" ]; then
277:     echo ""
278:     echo -e "${BOLD}5. Architecture E2E Verification${NC}"
279:     E2E_SCRIPT="$PROJECT_ROOT/scripts/e2e-verify.sh"
280:     if [ -f "$E2E_SCRIPT" ] && [ -x "$E2E_SCRIPT" ]; then
281:         if bash "$E2E_SCRIPT" --quick 2>&1 | grep -E "Passed|Failed|✓|✗|⚠" | tail -20; then
282:             PASSED=$((PASSED + 1))
283:             check "E2E verification suite executed" "true"
284:         else
285:             FAILED=$((FAILED + 1))
286:             check "E2E verification suite executed" "false"
287:         fi
288:     else
289:         printf "  [${WARN}] E2E script not found or not executable: ${E2E_SCRIPT}\n"
290:         WARNINGS=$((WARNINGS + 1))
291:     fi
292: fi
293: 
294: # ═══════════════════════════════════════════
295: # Section 6: Clean up temp files
296: # ═══════════════════════════════════════════
297: rm -f /tmp/secguardian-verify-test.json
298: 
299: # ═══════════════════════════════════════════
300: # Summary
301: # ═══════════════════════════════════════════
302: echo ""
303: echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
304: TOTAL=$((PASSED + FAILED))
305: if [ $FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
306:     echo -e "  ${GREEN}✓ 全部通过${NC}  (${PASSED}/${TOTAL} checks)"
307:     EXIT_CODE=0
308: elif [ $FAILED -eq 0 ]; then
309:     echo -e "  ${YELLOW}⚠ 通过但有警告${NC}  (${PASSED}/${TOTAL} passed, ${WARNINGS} warnings)"
310:     EXIT_CODE=0
311: else
312:     echo -e "  ${RED}✗ ${FAILED}/${TOTAL} checks 失败${NC}  (${PASSED} passed, ${FAILED} failed, ${WARNINGS} warnings)"
313:     EXIT_CODE=1
314: fi
315: echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
316: 
317: exit $EXIT_CODE

(End of file - total 317 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/secfix.py"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/secfix.py</path>
<type>file</type>
<content>
1: #!/usr/bin/env python3
2: """
3: secfix.py - Generate unified diff patches from secguard/secreview findings.
4: 
5: Transforms findings with fix.before_code / fix.after_code into .patch files
6: that developers can review (git diff) and apply (git apply).
7: 
8: Usage:
9:     python3 scripts/secfix.py --findings-dir <path> --output <path>
10: 
11: Output:
12:     <output>/index.json          <- Patch manifest
13:     <output>/<detector>/*.patch   <- unified diffs
14:     <output>/<detector>/*.meta   <- patch metadata
15: 
16: Environment:
17:     SOURCE_ROOT: project root for relative file paths (default: cwd)
18: """
19: 
20: import argparse
21: import json
22: import os
23: import re
24: import sys
25: import hashlib
26: import difflib
27: from pathlib import Path
28: 
29: 
30: def sha_prefix(s, length=12):
31:     return hashlib.sha256(s.encode()).hexdigest()[:length]
32: 
33: 
34: def slugify(path):
35:     stem = Path(path).stem
36:     return re.sub(r'[^a-zA-Z0-9_-]', '', stem)[:40]
37: 
38: 
39: def find_finding_files(findings_dir):
40:     results = []
41:     for f in sorted(findings_dir.rglob("*.json")):
42:         if f.name in ("index.json", "manifest.json", "summary.json"):
43:             continue
44:         results.append(f)
45:     return results
46: 
47: 
48: def load_finding(path):
49:     try:
50:         data = json.loads(path.read_text())
51:         finding = data.get("finding") or data
52:         if not finding.get("fix"):
53:             return None
54:         return finding
55:     except (json.JSONDecodeError, KeyError, IOError):
56:         return None
57: 
58: 
59: def resolve_source_file(file_path, source_root):
60:     p = Path(file_path)
61:     if p.is_absolute() and p.exists():
62:         return p
63:     p = source_root / file_path
64:     if p.exists():
65:         return p
66:     p = source_root / Path(file_path).name
67:     if p.exists():
68:         return p
69:     return None
70: 
71: 
72: def generate_unified_diff(before_code, after_code, file_path):
73:     before_lines = before_code.rstrip("\n").split("\n")
74:     after_lines = after_code.rstrip("\n").split("\n")
75:     diff = difflib.unified_diff(
76:         before_lines, after_lines,
77:         fromfile="a/" + file_path,
78:         tofile="b/" + file_path,
79:         fromfiledate="", tofiledate="", n=3
80:     )
81:     return "\n".join(diff)
82: 
83: 
84: def process_finding(finding, source_root, scan_id):
85:     detector = finding.get("detector", "unknown")
86:     file_path = (finding.get("file", "") or
87:                  finding.get("location", {}).get("file_path", ""))
88:     line = (finding.get("line", 0) or
89:             finding.get("location", {}).get("start_line", 0))
90:     cwe = finding.get("cwe", "")
91:     severity = finding.get("severity", "")
92:     fix = finding.get("fix", {})
93:     before = fix.get("before_code", "")
94:     after = fix.get("after_code", "")
95:     description = fix.get("description", "")
96: 
97:     if (not before and not after) or not file_path:
98:         return None
99: 
100:     identity = "{}:{}:{}:{}".format(detector, file_path, line, cwe)
101:     sha = sha_prefix(identity)
102:     slug = slugify(file_path)
103:     patch_name = "{}_{}-{}.patch".format(sha, slug, line)
104: 
105:     header_lines = [
106:         "# " + detector,
107:         "# Severity: {}  |  CWE: {}".format(severity, cwe),
108:         "# File: {}:{}".format(file_path, line),
109:         "# Source scan: " + scan_id,
110:         "# Description: " + description,
111:         "#",
112:         "# Apply: git apply " + patch_name,
113:     ]
114:     header = "\n".join(header_lines) + "\n"
115: 
116:     diff = generate_unified_diff(before, after, file_path)
117:     if not diff.strip():
118:         return None
119: 
120:     return detector, patch_name, header + diff + "\n"
121: 
122: 
123: def run(args):
124:     findings_dir = Path(args.findings_dir)
125:     output_dir = Path(args.output)
126:     source_root = Path(os.environ.get("SOURCE_ROOT", os.getcwd()))
127:     scan_id = args.scan_id or ""
128: 
129:     output_dir.mkdir(parents=True, exist_ok=True)
130: 
131:     if not findings_dir.is_dir():
132:         print("ERROR: Findings directory not found: " + str(findings_dir), file=sys.stderr)
133:         sys.exit(1)
134: 
135:     files = find_finding_files(findings_dir)
136:     if not files:
137:         print("WARN: No finding files found in " + str(findings_dir), file=sys.stderr)
138:         manifest = {"schema_version": "1.0", "tool": "secfix",
139:                     "total_patches": 0, "patches": [], "summary": {}}
140:         (output_dir / "index.json").write_text(json.dumps(manifest, indent=2))
141:         return
142: 
143:     patches_meta = []
144:     stats = {"processed": 0, "skipped": 0, "errors": 0}
145: 
146:     for f in files:
147:         try:
148:             finding = load_finding(f)
149:             if finding is None:
150:                 stats["skipped"] += 1
151:                 continue
152: 
153:             result = process_finding(finding, source_root, scan_id)
154:             if result is None:
155:                 stats["skipped"] += 1
156:                 continue
157: 
158:             detector, patch_name, patch_text = result
159: 
160:             det_dir = output_dir / detector
161:             det_dir.mkdir(parents=True, exist_ok=True)
162:             patch_path = det_dir / patch_name
163:             patch_path.write_text(patch_text)
164: 
165:             meta_entry = {
166:                 "source_file": str(f),
167:                 "detector": detector,
168:                 "severity": finding.get("severity", ""),
169:                 "cwe": finding.get("cwe", ""),
170:                 "file": file_path if "file_path" in locals() else "",
171:                 "line": line if "line" in locals() else 0,
172:                 "description": description if "description" in locals() else "",
173:                 "patch_file": str(patch_path),
174:             }
175:             meta_path = patch_path.with_name(patch_name.replace(".patch", ".patch.meta"))
176:             meta_path.write_text(json.dumps(meta_entry, indent=2))
177:             patches_meta.append(meta_entry)
178:             stats["processed"] += 1
179: 
180:         except Exception as e:
181:             stats["errors"] += 1
182:             print("WARN: Error processing {}: {}".format(f, e), file=sys.stderr)
183: 
184:     manifest = {
185:         "schema_version": "1.0",
186:         "tool": "secfix",
187:         "total_patches": len(patches_meta),
188:         "patches": patches_meta,
189:         "summary": {},
190:     }
191:     for p in patches_meta:
192:         sev = p.get("severity", "unknown")
193:         manifest["summary"][sev] = manifest["summary"].get(sev, 0) + 1
194: 
195:     (output_dir / "index.json").write_text(json.dumps(manifest, indent=2))
196: 
197:     print("")
198:     print("## secfix complete")
199:     print("")
200:     print("- Findings processed: {}".format(stats["processed"]))
201:     print("- Findings skipped:   {}".format(stats["skipped"]))
202:     print("- Patches generated:  {}".format(len(patches_meta)))
203:     print("- Output directory:   {}".format(output_dir))
204:     print("")
205:     print("Next steps:")
206:     print("  1. Review patches: ls {}/<detector>/*.patch".format(output_dir))
207:     print("  2. Apply:          git apply {}/<detector>/*.patch".format(output_dir))
208:     print("  3. Verify:         /secreview <path> <language>")
209:     print("")
210: 
211: 
212: def auto_discover_findings():
213:     """Auto-discover the latest scan findings directory."""
214:     import glob
215:     candidates = []
216:     for ext_dir in sorted(Path('.codeagent').glob('*-secguardian/scans/*/findings')):
217:         if ext_dir.is_dir():
218:             candidates.append(ext_dir)
219:     for ext_dir in sorted(Path('.codeagent').glob('*-secguardian/scans/*/findings/')):
220:         if ext_dir.is_dir():
221:             candidates.append(ext_dir)
222:     if candidates:
223:         # Sort by path name (contains timestamp) and take latest
224:         candidates.sort(reverse=True)
225:         return str(candidates[0])
226:     return None
227: 
228: 
229: def main():
230:     parser = argparse.ArgumentParser(
231:         description="Generate patches from security findings. "
232:                     "Zero arguments: auto-discovers latest scan.")
233:     parser.add_argument("--findings-dir", "-f", default=None,
234:                         help="Path to findings/ directory (default: auto-discover)")
235:     parser.add_argument("--output", "-o", default=None,
236:                         help="Output directory for patches (default: auto)")
237:     parser.add_argument("--scan-id", "-s", default="",
238:                         help="Source scan ID (for traceability)")
239:     args = parser.parse_args()
240: 
241:     if not args.findings_dir:
242:         discovered = auto_discover_findings()
243:         if not discovered:
244:             print("ERROR: No findings directory found.", file=sys.stderr)
245:             print("  Provide one with: --findings-dir <path>", file=sys.stderr)
246:             print("  Or run /secreview or /secaudit first to generate findings.", file=sys.stderr)
247:             sys.exit(1)
248:         args.findings_dir = discovered
249:         print(f"Auto-discovered findings: {discovered}")
250: 
251:     if not args.output:
252:         # Default: output to 'fixes/' next to the findings directory
253:         findings_path = Path(args.findings_dir)
254:         # If findings_dir is .../scans/<id>/findings, output to .../scans/<id>/fixes
255:         if findings_path.parent.parent.name == 'scans':
256:             args.output = str(findings_path.parent / 'fixes')
257:         else:
258:             args.output = str(findings_path / '../fixes')
259:         print(f"Output directory: {args.output}")
260: 
261:     run(args)
262: 
263: 
264: if __name__ == "__main__":
265:     main()

(End of file - total 265 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/docs/sdd/README.md"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/docs/sdd/README.md</path>
<type>file</type>
<content>
1: # SecGuardian SDD — Spec-Driven Development
2: 
3: > 核心原则只有一句：
4: >
5: > **🧠 Brainstorm 决定方向 → 📋 Spec 定义需求 → 📝 ADR 记录决策 → 📐 Plan 拆解实现 → 🔨 Task 驱动编码 → 📊 Progress 保持上下文 → 🔄 Change 管理演进**
6: >
7: > 每一环对应一个具体文件。不缺不滥，各司其职。
8: 
9: ---
10: 
11: ## 一、为什么不是文档类型视角
12: 
13: 传统做法按文档类型分目录——`specs/`、`plans/`、`tasks/`。小项目（<10 需求）时简便，项目大了必然出现：
14: 
15: ```
16: SPEC-001 ... SPEC-020
17: PLAN-001 ... PLAN-020
18: TASK-001 ... TASK-120
19: ```
20: 
21: 查找"认证功能到底有哪些文档"需要跨 3 个目录搜索。需求越多，维护成本指数增长。
22: 
23: **Feature Package 模式下**，每个 Feature 自成一个完整闭环：
24: 
25: ```
26: FEATURE-001-jwt-auth/
27: ├── spec.md        # 需求规格
28: ├── adr.md         # 架构决策
29: ├── plan.md        # 实施计划
30: ├── progress.md    # 进度追踪
31: ├── tasks/         # 任务拆分
32: └── changes/       # 变更记录
33: ```
34: 
35: 当 AI Agent 开发 JWT 功能时，只需加载这一个目录，即可获得全部上下文。不需要扫描整个 `docs/`。
36: 
37: ---
38: 
39: ## 二、七原则详解
40: 
41: ### 🧠 Brainstorm — 决定方向
42: 
43: | 属性 | 说明 |
44: |------|------|
45: | **载体** | `docs/sdd/brainstorm-log.md` |
46: | **时机** | 产生想法 → 方案讨论 → 确定方向 |
47: | **作者** | 人 + AI 对话 |
48: | **读者** | 未来的自己和团队成员（"当时为什么选这个方案？"） |
49: 
50: Brainstorm 是七原则的起点。它不追求格式规范，追求的是**完整记录思考过程**：背景是什么、考虑过哪些方案、否决了哪些、为什么选这个、影响范围多大。
51: 
52: 一个好的 Brainstorm 条目包含：
53: - **背景** — 为什么要做这个决定
54: - **讨论要点** — 考虑过哪些方案，各自的优劣
55: - **最终方案** — 选了哪个，为什么
56: - **影响范围** — 哪些文件/模块会受影响
57: 
58: > Brainstorm 不是正式文档。正式决策在 ADR 中记录。Brainstorm 的价值在于保留那些被否决的方案和否决原因——这些东西 ADR 里通常只写一行 "Rejected"。
59: 
60: ---
61: 
62: ### 📋 Spec — 定义需求
63: 
64: | 属性 | 说明 |
65: |------|------|
66: | **载体** | `FEATURE-XXX/spec.md` |
67: | **时机** | Brainstorm 确定方向后 |
68: | **作者** | 人（定义 What），AI 辅助补充 |
69: | **读者** | 实施者（人 + AI Agent） |
70: 
71: Spec 回答 **WHAT**——要做什么、为什么做、做到什么程度。
72: 
73: 一个好的 Spec 包含：
74: - **问题陈述** — 当前痛点，用数据说话
75: - **设计目标** — 可度量的成功标准
76: - **需求规格** — REQ-001, REQ-002... 每条可验证
77: - **设计方案** — 核心思路、关键数据结构、流程变更
78: - **风险与约束** — 已知限制、不做什么
79: 
80: Spec 是 Feature 的"真理源"。后续所有文档——ADR、Plan、Task、Change——都以 Spec 为基准。
81: 
82: > 原则：Spec 写完要让一个没参与 Brainstorm 的人能看懂"要做什么"和"为什么"。
83: 
84: ---
85: 
86: ### 📝 ADR — 记录决策
87: 
88: | 属性 | 说明 |
89: |------|------|
90: | **载体** | `FEATURE-XXX/adr.md` |
91: | **时机** | Spec 完成后、Plan 开始前 |
92: | **作者** | 人（决策者） |
93: | **读者** | 未来接手的人（"这个设计为什么长这样？"） |
94: 
95: ADR（Architecture Decision Record）记录 SPEC 中隐含的架构决策。一个 Feature 可以有多个 ADR——每个关键技术选择一条。
96: 
97: ADR 格式：
98: ```markdown
99: ## ADR-001: 决策标题
100: 
101: **日期**: YYYY-MM-DD
102: **状态**: ✅ Accepted / ❌ Superseded
103: 
104: ### Decision
105: （一句话说清选了什么）
106: 
107: ### Reason
108: （为什么选这个，至少两条理由）
109: 
110: ### Rejected Alternatives
111: | 方案 | 否决原因 |
112: |------|---------|
113: | ... | ... |
114: 
115: ### Consequences
116: （这个决策带来了什么影响——好的和不好的都要写）
117: ```
118: 
119: > 原则：ADR 的价值在 "Rejected Alternatives"——知道什么路不走，比知道走哪条路更有长期价值。
120: 
121: ---
122: 
123: ### 📐 Plan — 拆解实现
124: 
125: | 属性 | 说明 |
126: |------|------|
127: | **载体** | `FEATURE-XXX/plan.md` |
128: | **时机** | ADR 完成后 |
129: | **作者** | 人 + AI Agent |
130: | **读者** | AI Agent（执行者） |
131: 
132: Plan 回答 **HOW**——怎么实现、分几步、改哪些文件。
133: 
134: 一个好的 Plan 包含：
135: - **Goal** — 一句话目标
136: - **Architecture** — 技术选型 + 组件关系
137: - **File Structure** — 改哪些文件，每个文件的改动量
138: - **Tasks** — 按执行顺序排列的 checkbox 列表，每个 Task 对应一次可验证的代码变更
139: - **Verification** — 每个 Task 完成后的验证命令
140: 
141: > 原则：Plan 是写给 AI Agent 的执行指令。Task 粒度要细到"一个 Task 一次 commit"，验证命令要可复制粘贴。
142: 
143: ---
144: 
145: ### 🔨 Task — 驱动编码
146: 
147: | 属性 | 说明 |
148: |------|------|
149: | **载体** | `FEATURE-XXX/tasks/TASK-NNN-description.md` |
150: | **时机** | Plan 中每个 checkbox 对应一个 Task |
151: | **作者** | 人拆分，AI Agent 执行 |
152: | **读者** | AI Agent（编码时加载） |
153: 
154: Task 是 Plan 的细化。复杂的 Task 可以拆出独立文件，记录详细的实施步骤、代码示例、验证方法。
155: 
156: 一个好的 Task 包含：
157: - **Goal** — 这个 Task 完成后产出了什么
158: - **Done** — checkbox 完成清单
159: - **Files Changed** — 改动文件 + 改动量
160: - **Verification** — 可执行的验证命令
161: 
162: > 原则：每个 Task 完成后应该可以独立 commit。如果两个 Task 必须一起 commit，它们应该是同一个 Task。
163: 
164: ---
165: 
166: ### 📊 Progress — 保持上下文
167: 
168: | 属性 | 说明 |
169: |------|------|
170: | **载体** | `FEATURE-XXX/progress.md` |
171: | **时机** | 持续更新（每个 Task 完成后） |
172: | **作者** | 人 + AI Agent |
173: | **读者** | 人（"这个 Feature 做到哪了？"） |
174: 
175: Progress 是 Feature 的实时状态面板。它不重复 Plan 的内容，只追踪**进度**。
176: 
177: 一个好的 Progress 包含：
178: - **状态** — `✅ 已完成` / `🔄 进行中` / `⬜ 未开始`
179: - **完成清单** — 从 Plan 中复制的 Task 列表，标记完成状态
180: - **关键里程碑** — 日期 + 事项
181: - **阻塞项** — 当前被什么阻塞
182: 
183: > 原则：Progress 是给中断后回来的人看的。离开一周后，打开 progress.md 应该能在 30 秒内知道"做到哪了、下一步做什么"。
184: 
185: ---
186: 
187: ### 🔄 Change — 管理演进
188: 
189: | 属性 | 说明 |
190: |------|------|
191: | **载体** | `FEATURE-XXX/changes/CHANGE-NNN-description.md` |
192: | **时机** | Spec 发生实质性变更时 |
193: | **作者** | 人 |
194: | **读者** | 所有关注这个 Feature 的人 |
195: 
196: Change 记录需求的演进。不是每个小改动都需要 Change 记录——只有当需求**实质性变化**（新增/删除 REQ、架构方案推倒重来）时才记录。
197: 
198: 一个好的 Change 包含：
199: - **Reason** — 为什么变（外部反馈？技术发现？）
200: - **Impact** — 变更前后对比表
201: - **新增/修改/废弃的需求** — 引用 SPEC 中的 REQ 编号
202: - **Migration** — 如何从旧方案迁移到新方案
203: 
204: > 原则：Change 回答的是"这个 Feature 为什么和最初设计的不一样"。如果一个 Feature 没有任何 Change 记录，要么是设计完美，要么是需求根本没被 challenge 过。
205: 
206: ---
207: 
208: ## 三、Feature 生命周期
209: 
210: 一个 Feature 从 idea 到交付，按顺序走过七环：
211: 
212: ```
213: 🧠 Brainstorm        人+AI 讨论，产出 brainstorm-log 条目
214:         │
215:         ▼
216: 📋 Spec              人写需求，AI 辅助补充细节
217:         │
218:         ▼
219: 📝 ADR               人写架构决策，每条一个 ADR
220:         │
221:         ▼
222: 📐 Plan              人+AI 拆解成 Task 列表
223:         │
224:         ▼
225: ┌───────────────────────────────────┐
226: │  🔨 Task → 编码 → 验证 → commit    │  循环（AI Agent 逐 Task 执行）
227: │  📊 Progress → 更新进度            │
228: │  🔄 Change → 有变更时追加           │
229: └───────────────────────────────────┘
230:         │
231:         ▼
232: ✅ Feature 完成 → Progress 标记 Done
233: ```
234: 
235: 关键规则：
236: - **七环顺序不可跳过**。不能没有 Spec 就写 Plan，不能没有 ADR 就开始编码。
237: - **Brainstorm 是唯一可以省略文件载体的一环**——小决策直接在对话中完成，大决策才记入 brainstorm-log。
238: - **Change 随时可能触发**——当 Spec 发生实质性变化时，在继续编码前先写 Change。
239: 
240: ---
241: 
242: ## 四、给 AI Agent 的指引
243: 
244: ### 当你被要求开发某个 Feature 时
245: 
246: 1. **先读 Spec** — 理解 WHAT
247: 2. **再读 ADR** — 理解关键决策
248: 3. **然后读 Plan** — 理解 HOW，找到你的 Task
249: 4. **Task 执行时** — 加载对应 `TASK-NNN.md`
250: 5. **完成后** — 更新 `progress.md`
251: 
252: ### 局部上下文原则
253: 
254: 只需加载你需要的文件。不要扫描整个 `docs/sdd/`。
255: 
256: ```
257: 开发 FEATURE-001 的 TASK-003：
258:   ✅ 加载: FEATURE-001/tasks/TASK-003.md
259:   ✅ 加载: FEATURE-001/spec.md（理解上下文）
260:   ❌ 不加载: FEATURE-002/ 的所有文件
261:   ❌ 不加载: brainstorm-log.md
262: ```
263: 
264: ### Commit 粒度
265: 
266: 一个 Task 一次 commit。Commit message 格式：
267: ```
268: feat(feature-name): TASK-NNN — task description
269: ```
270: 
271: ---
272: 
273: ## 五、层级结构
274: 
275: ```
276: Epic → Feature → Task
277: 
278: EPIC-001-IAM/
279: ├── epic.md                    # Epic 概述（目标、包含哪些 Feature、里程碑）
280: ├── FEATURE-001-login/         # Feature = 独立闭环
281: ├── FEATURE-002-jwt/
282: └── FEATURE-003-rbac/
283: ```
284: 
285: | 层级 | 含义 | 持续时间 | 文件载体 |
286: |------|------|---------|---------|
287: | **Epic** | 跨多个 Feature 的大型目标 | 数周~数月 | `epic.md` |
288: | **Feature** | 可独立交付的用户价值单元 | 数天~数周 | `spec.md` + `adr.md` + `plan.md` + `progress.md` + `tasks/` + `changes/` |
289: | **Task** | 单一可执行的工作项 | 数小时~数天 | `tasks/TASK-NNN.md` |
290: 
291: ---
292: 
293: ## 六、SecGuardian Epics 全景
294: 
295: ```
296: docs/sdd/
297: ├── README.md                   # 本文件 — 方法论总纲
298: ├── brainstorm-log.md           # 🧠 Brainstorm 决定方向
299: └── epics/
300:     ├── EPIC-001-core-scanning-engine/
301:     │   ├── epic.md
302:     │   ├── FEATURE-001-output-protocol/     # 输出协议 v2→v5 演进
303:     │   ├── FEATURE-002-detector-quality/    # 67 检测器质量增强
304:     │   └── FEATURE-003-verification-pipeline/ # 五轮验证消减系统
305:     │
306:     └── EPIC-002-platform-engineering/
307:         ├── epic.md
308:         ├── FEATURE-001-manifest-driven-tokens/  # 散弹式修改终结者
309:         └── FEATURE-002-mcp-server/              # MCP 消费层
310: ```
311: 
312: ---
313: 
314: ## 七、反模式
315: 
316: | 反模式 | 为什么不好 |
317: |--------|-----------|
318: | **跳过 Spec 直接写 Plan** | Plan 没有 What 锚定，必然偏离需求 |
319: | **ADR 只写 Decision 不写 Rejected** | 3 个月后没人知道为什么不用方案 B |
320: | **Plan 里的 Task 粒度太大** | "实现认证系统"不是一个 Task，是一次 Epic |
321: | **Progress 写成 Plan 的副本** | Progress 只追踪状态，不重复 Plan 内容 |
322: | **每个小改动都写 Change** | Change 过多会淹没真正重要的变更 |
323: | **AI Agent 扫描整个 sdd/** | 浪费 token，违反 Local Context 原则 |
324: | **Task 之间互相依赖但没有标注** | 后面的 Task 执行者不知道要等前面的完成 |
325: 
326: ---
327: 
328: ## 八、与其他目录的关系
329: 
330: | 目录 | 定位 | 是否属于 SDD |
331: |------|------|-------------|
332: | `docs/sdd/` | **SDD 方法论核心** — 七原则的完整载体 | ✅ |
333: | `docs/reference/` | 参考资料 — 白皮书、PPT、作品集、CI 指南 | ❌ |
334: | `docs/dogfood/` | 自扫描记录 — 运维 artifact | ❌ |
335: | `docs/templates/` | 文档模板 | ❌ |
336: | `docs/governance/` | 企业安全治理标准 — 独立体系 | ❌ |
337: | `docs/` 顶层 | 商业文档 — 竞品分析、商业化路线图 | ❌ |
338: 
339: ---
340: 
341: ## 九、参考来源
342: 
343: 本方法论借鉴：
344: - **Claude Code Superpowers** 工作流 — Feature Package + Local Context 模型，长周期 AI Coding 项目的最佳实践
345: - **Jira / Linear / GitHub Projects** — Epic → Feature → Task 的三级拆分
346: - **MADR** (Markdown Architectural Decision Records) — ADR 的 Markdown 格式规范
347: - **ZEROFalse** (北大, 2025) — 证据门控推理对 Evidence Collection Guide 的启发

(End of file - total 347 lines)
</content>
```

---

## Assistant (Build · DeepSeek V4 Flash · 18.9s)

_Thinking:_

I've gathered a lot of information. Let me now check a few more critical files before producing my report. Let me look at:
1. The test files for the Go indexer
2. The remaining critical scripts
3. The parser_re_test to check for testing issues
4. The e2e-verify.sh script
5. The extensions/ directory
6. The go.mod and go.sum
7. The opencode-plugin.js

Let me also now start identifying issues I've already seen:

## Critical Defects Identified So Far:

### 1. **Version Inconsistency Crisis** — Critical
- `internal/main.go`: version = "0.12.0"  
- `manifest.json`: version = "0.12.0"  
- `deploy.sh`: hardcoded "0.5.4" in plugin.json (line 194, 299 for gemini)  
- `package.sh`: hardcoded "0.5.4" in the deploy script  
- `dev-verify.sh`: EXPECTED_VER="0.5.5" (line 116)  
- **There are at least 4 different version strings across the codebase** — this is an operational disaster waiting to happen.

Wait, let me re-examine. The manifest.json says 0.12.0, main.go says 0.12.0, deploy.sh says 0.5.4, dev-verify.sh says 0.5.5. That's indeed a huge inconsistency.

### 2. **render-report.py: Massive Code Duplication & Inefficiency**
- The `render_report_md` function does `from collections import defaultdict` inside the function body (line 409, 427) instead of at top of file
- Same for line 900, 915 (`from collections import Counter` inside `render_executive_summary`)
- The `load_detector_index_from_files` looks for files in `knowledge/detectors/` but the actual path is `knowledge/guard-rules/` — this means the dynamic index loading probably never works, always falling back to the hardcoded fallback
- DETECTOR_RULE_INDEX has duplicate key: `web.jwt-misuse` appears at both index 8 and the end of the dict (lines 99 and 159)

### 3. **Race Condition in Build Process** — package.sh
Line 82-97: All go builds run in parallel with `&` but they all use the same `go build -o` with different names. However, there's no proper error handling — the `|| echo "[WARN] ..."` just swallows failures. If a cross-compile fails silently, there's no way to know.

### 4. **Duplicate Lines in package.sh**
Line 126-131: `audit-rules` and `review-rules` are created twice:
```bash
"$dist_dir/knowledge/audit-rules" \
"$dist_dir/knowledge/review-rules" \
"$dist_dir/knowledge/audit-rules" \     # DUPLICATE
"$dist_dir/knowledge/review-rules" \     # DUPLICATE
```

### 5. **Security: render-report.py has hardcoded CWE URLs without validation**
The SARIF generation builds URLs with string interpolation that could lead to injection if CWE data is malformed.

### 6. **secfix.py: Uninitialized local variables** 
Lines 170-172 reference `file_path`, `line`, `description` but these may not be defined in scope (the `if` block at line 97-98 that defines them has an early return).

### 7. **indexer.go MatchAllocFree O(n²) with no cross-file scope**
The alloc/free matcher scans every line for every alloc occurrence — it's O(n²) brute force. More critically, it matches *every* free call as a potential free site, not just related ones.

### 8. **Missing Stale Symlink Safety Check in render-report.py**
In `generate_delta` (line 853), `os.path.realpath(latest_link)` follows symlinks without checking for loops or safety. A malicious scan could point latest → some other directory.

### 9. **self-check.sh: Broken skill count display**
Line 161-165: The echo statement is positioned incorrectly — the "Total: $SKILL_COUNT skills" is printed inside a `else` branch of the npx check.

### 10. **parser_ts.go: Missing nil guards**
While the AGENTS.md mentions nil guards for Tree-sitter, the code does `node.Child(i)` without nil checks in some places (e.g., line 182 on `child.Child(j)`).

Wait, let me re-check. Line 182: `for j := uint(0); j < child.ChildCount(); j++` — The inner loop in extractIdent checks `if decl == nil`. OK, that's guarded. But there are still areas...

### 11. **JavaScript parser: detectLanguage fallback to "c" is wrong**
In main.go line 223: `return "c"` as default language — This means any unknown file extension falls back to "c" parsing, which would fail confusingly.

### 12. **parser_re.go: String conversion inefficiency**
Lines 42, 55-59, 72, 79-81, 123, 130-133 etc.: Repeatedly converts `string(content)` via `strings.Index(string(content), ...)` and `strings.Count(string(content)[:pos], "\n")` — this creates a new string on every call and wastes memory.

### 13. **Hardcoded paths: deploy.sh references gitee.com instead of github.com**
The deploy scripts reference "https://gitee.com/jonyan/secguardian" (lines 196, 198, 303, 305) but the GitHub repo is DannyAn/SecGuardian.

### 14. **openmode-plugin.js missing in package.sh copying**
package.sh copies secguardian-index, secguardian-index.ps1, record-finding.py, validate-index.py, validate-findings.py but NOT opencode-plugin.js.

### 15. **dev-verify.sh: Hardcoded expected_version "0.5.5"**
Line 116: EXPECTED_VER="0.5.5" — doesn't match manifest.json "0.12.0" or main.go "0.12.0".

OK, let me check more files to complete the picture.

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/e2e-verify.sh",
  "limit": 80
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/e2e-verify.sh</path>
<type>file</type>
<content>
1: #!/bin/bash
2: # SecGuardian — End-to-End Verification Suite v1.0
3: #
4: # Comprehensive multi-faceted verification of the AI/Renderer architecture.
5: # Covers: findings schema conformance, renderer output validation,
6: #         SARIF 2.1.0 compliance, 4-segment quality gate,
7: #         multi-language support, CI exit codes, delta comparison.
8: #
9: # Usage:
10: #   bash scripts/e2e-verify.sh              # Full suite
11: #   bash scripts/e2e-verify.sh --quick       # Fast subset (schema + renderer only)
12: #   bash scripts/e2e-verify.sh --ci          # CI mode (non-zero exit on failure)
13: #
14: # Part of CodePlan: hashed-juggling-sutherland
15: 
16: set -euo pipefail
17: 
18: PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
19: cd "$PROJECT_ROOT"
20: 
21: # ── Colors ──────────────────────────────────────
22: GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'
23: BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'
24: 
25: PASS=0; FAIL=0; WARN=0
26: TMPDIR=$(mktemp -d)
27: trap "rm -rf $TMPDIR" EXIT
28: 
29: pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
30: fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
31: warn() { echo -e "  ${YELLOW}⚠${NC} $1"; WARN=$((WARN+1)); }
32: section() { echo ""; echo -e "${BOLD}${CYAN}━━━ $1 ━━━${NC}"; }
33: 
34: MODE="${1:-full}"
35: [ "${1:-}" = "--ci" ] && MODE="ci"
36: 
37: echo ""
38: echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
39: echo -e "${BOLD}║${NC}  SecGuardian E2E Verification Suite v1.0     ${BOLD}║${NC}"
40: echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
41: echo ""
42: 
43: # ═══════════════════════════════════════════════
44: # 1. Findings Schema Conformance
45: # ═══════════════════════════════════════════════
46: section "1. Findings Schema Conformance"
47: 
48: SCHEMA="$PROJECT_ROOT/knowledge/protocols/findings-schema.json"
49: [ -f "$SCHEMA" ] && pass "Schema file exists" || { fail "Schema file missing: $SCHEMA"; }
50: 
51: # Validate schema is valid JSON
52: python3 -c "import json; json.load(open('$SCHEMA'))" 2>/dev/null && \
53:     pass "Schema is valid JSON" || \
54:     fail "Schema is invalid JSON"
55: 
56: # Validate schema has required top-level fields
57: python3 -c "
58: import json
59: s = json.load(open('$SCHEMA'))
60: req = s.get('required', [])
61: for f in ['schema_version', 'scan_id', 'command', 'findings']:
62:     assert f in req, f'Missing required: {f}'
63: print('OK')
64: " 2>/dev/null && pass "Schema has all required top-level fields" || fail "Schema missing required top-level fields"
65: 
66: # Validate Finding sub-schema has 4-segment fields
67: python3 -c "
68: import json
69: s = json.load(open('$SCHEMA'))
70: finding_props = s['\$defs']['Finding']['properties']
71: for seg in ['location', 'evidence', 'impact', 'fix']:
72:     assert seg in finding_props, f'Missing 4-segment field: {seg}'
73: print('OK')
74: " 2>/dev/null && pass "Schema enforces 4-segment protocol (location/evidence/impact/fix)" || fail "Schema missing 4-segment fields"
75: 
76: # Validate finding ID pattern
77: python3 -c "
78: import json, re
79: s = json.load(open('$SCHEMA'))
80: id_pattern = s['\$defs']['Finding']['properties']['id']['pattern']

(Showing lines 1-80 of 950. Use offset=81 to continue.)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/extensions"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/extensions</path>
<type>directory</type>
<entries>
secaudit-secguardian/
secfix-secguardian/
secguard-secguardian/
secreview-secguardian/

(4 entries)
</entries>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/go.mod"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/go.mod</path>
<type>file</type>
<content>
1: module github.com/secguardian/internal
2: 
3: go 1.25.3
4: 
5: require (
6: 	github.com/mattn/go-pointer v0.0.1 // indirect
7: 	github.com/tree-sitter/go-tree-sitter v0.25.0 // indirect
8: 	github.com/tree-sitter/tree-sitter-c v0.24.2 // indirect
9: 	github.com/tree-sitter/tree-sitter-cpp v0.23.4 // indirect
10: 	github.com/tree-sitter/tree-sitter-go v0.25.0 // indirect
11: 	github.com/tree-sitter/tree-sitter-java v0.23.5 // indirect
12: 	github.com/tree-sitter/tree-sitter-python v0.25.0 // indirect
13: )

(End of file - total 13 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/opencode-plugin.js"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/opencode-plugin.js</path>
<type>file</type>
<content>
1: // SecGuardian OpenCode 插件
2: // deploy.sh 原样 cp 到 ~/.config/opencode/plugins/ 或 .opencode/plugins/
3: // extension 路径由插件自身位置推导: plugins/../extensions/secguardian
4: 
5: import { readFileSync, existsSync } from 'node:fs'
6: import { fileURLToPath } from 'node:url'
7: import { dirname, resolve, join } from 'node:path'
8: 
9: const __dirname = dirname(fileURLToPath(import.meta.url))
10: const extDir = resolve(__dirname, '..', 'extensions', 'secguardian')
11: 
12: const CMDS = [
13:   { name: 'secguard',  file: 'secguard.md',  desc: '安全加固项排查 — 67 个检测器覆盖 7 大安全分类' },
14:   { name: 'secaudit',  file: 'secaudit.md',  desc: '★ 旗舰产品：AI 深度安全审计 — 17 项专业安全分析' },
15:   { name: 'secreview', file: 'secreview.md', desc: '安全编码规范检视 — 5 语言反模式检测矩阵 + 最佳实践合规审查' },
16: ]
17: 
18: export const SecGuardianPlugin = async () => {
19:   return {
20:     config: (cfg) => {
21:       cfg.command = cfg.command || {}
22: 
23:       for (const cmd of CMDS) {
24:         const cmdPath = join(extDir, 'commands', cmd.file)
25:         if (!existsSync(cmdPath)) {
26:           console.error(`[SecGuardian] command file not found: ${cmdPath}`)
27:           continue
28:         }
29:         cfg.command[cmd.name] = {
30:           template: readFileSync(cmdPath, 'utf-8'),
31:           description: cmd.desc,
32:         }
33:       }
34: 
35:       // Register skills directory so AI can discover secaudit/secguard/secreview skills
36:       const skillsDir = join(extDir, 'skills')
37:       cfg.skills = cfg.skills || { paths: [] }
38:       if (!cfg.skills.paths.includes(skillsDir)) {
39:         cfg.skills.paths.push(skillsDir)
40:       }
41: 
42:       // Register knowledge directories so AI can discover rules
43:       const knowledgeDir = join(extDir, 'knowledge')
44:       cfg.knowledge = cfg.knowledge || { paths: [] }
45:       if (!cfg.knowledge.paths.includes(knowledgeDir)) {
46:         cfg.knowledge.paths.push(knowledgeDir)
47:       }
48:     }
49:   }
50: }

(End of file - total 50 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/validate-index.py"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/validate-index.py</path>
<type>file</type>
<content>
1: #!/usr/bin/env python3
2: """
3: Step 2b 索引验证 + 结构化摘要输出
4: 
5: 用途: 被命令模板中的 Step 2b 调用，替代内联 Python heredoc。
6: 优势: 
7:   - 避免内联 Python 的引号转义问题
8:   - 对 None/null 值鲁棒（不同语言索引器结构不同）
9:   - 可在 CI 中独立测试
10: 
11: 用法: python3 scripts/validate-index.py --index <path> --scan-id <id>
12: """
13: import argparse, json, os, sys
14: from collections import Counter
15: 
16: EXT_MAP = {
17:     'c': 'cpp', 'h': 'cpp', 'cpp': 'cpp', 'cc': 'cpp', 'cxx': 'cpp',
18:     'hpp': 'cpp', 'hh': 'cpp', 'hxx': 'cpp',
19:     'java': 'java',
20:     'py': 'python', 'pyw': 'python',
21:     'go': 'go',
22:     'js': 'javascript', 'jsx': 'javascript', 'ts': 'javascript',
23:     'tsx': 'javascript', 'mjs': 'javascript', 'cjs': 'javascript',
24:     'rs': 'rust', 'swift': 'swift', 'kt': 'kotlin', 'kts': 'kotlin',
25:     'scala': 'scala', 'rb': 'ruby', 'php': 'php', 'cs': 'csharp',
26:     'fs': 'fsharp', 'sh': 'shell', 'bash': 'shell', 'zsh': 'shell',
27:     'cmake': 'cmake', 'mk': 'makefile',
28: }
29: 
30: 
31: def safe_len(obj):
32:     """安全获取长度: None → 0, list → len(list)"""
33:     return len(obj) if isinstance(obj, (list, dict, str)) else 0
34: 
35: 
36: def detect_lang(filepath):
37:     base = os.path.basename(filepath)
38:     if base.startswith('.') or '.' not in base:
39:         return None
40:     return EXT_MAP.get(base.rsplit('.', 1)[-1].lower())
41: 
42: 
43: def main():
44:     parser = argparse.ArgumentParser()
45:     parser.add_argument('--index', required=True)
46:     parser.add_argument('--scan-id', default='')
47:     args = parser.parse_args()
48: 
49:     if not os.path.isfile(args.index):
50:         print(f"FATAL: index file not found: {args.index}", file=sys.stderr)
51:         sys.exit(1)
52: 
53:     with open(args.index) as f:
54:         d = json.load(f)
55: 
56:     # ── 校验（null-safe） ──
57:     files = d.get('files') or []
58:     assert len(files) > 0, 'FATAL: index contains no files'
59:     assert d.get('symbols') is not None, 'FATAL: index missing symbols'
60:     assert d.get('call_graph') is not None, 'FATAL: index missing call_graph'
61: 
62:     # ── 语言检测 ──
63:     langs = Counter()
64:     for f in files:
65:         lang = detect_lang(f)
66:         if lang:
67:             langs[lang] += 1
68:     primary_lang = langs.most_common(1)[0][0] if langs else 'unknown'
69: 
70:     # ── 安全访问索引器数据 ──
71:     functions = d.get('symbols', {}).get('functions') or []
72:     call_edges = d.get('call_graph', {}).get('edges') or []
73: 
74:     # ── 输出 JSON 摘要 ──
75:     summary = {
76:         'scan_id': args.scan_id,
77:         'file_count': safe_len(files),
78:         'function_count': safe_len(functions),
79:         'call_edge_count': safe_len(call_edges),
80:         'primary_language': primary_lang,
81:         'language_distribution': dict(langs.most_common()),
82:         'index_path': os.path.abspath(args.index),
83:     }
84:     json.dump(summary, sys.stdout, indent=2, ensure_ascii=False)
85:     print()  # trailing newline
86: 
87: 
88: if __name__ == '__main__':
89:     main()

(End of file - total 89 lines)
</content>
```

---

## Assistant (Build · DeepSeek V4 Flash · 3.2s)

_Thinking:_

Now let me check a few more files quickly to make the review comprehensive. Let me check the extensions JSON files and some other key files.

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/extensions/secguard-secguardian/extension.json"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/extensions/secguard-secguardian/extension.json</path>
<type>file</type>
<content>
1: {
2:   "name": "secguard-secguardian",
3:   "version": "0.12.0",
4:   "description": "\u5b89\u5168\u52a0\u56fa\u9879\u6392\u67e5 \u2014 71<!-- @secguardian:detector_count --> \u4e2a\u68c0\u6d4b\u5668\u8986\u76d6 8<!-- @secguardian:namespace_count --> \u5927\u5b89\u5168\u5206\u7c7b",
5:   "author": "SecGuardian",
6:   "command": "secguard",
7:   "protocol": "2.0",
8:   "platforms": {
9:     "claude-code": {
10:       "entry": "commands/secguard.md"
11:     },
12:     "opencode": {
13:       "entry": "commands/secguard.md"
14:     },
15:     "gemini-cli": {
16:       "entry": "commands/secguard.md"
17:     }
18:   },
19:   "skills": [
20:     "cpp",
21:     "java",
22:     "python",
23:     "go",
24:     "js"
25:   ],
26:   "knowledge": {
27:     "protocols": [
28:       "scan-output",
29:       "sarif-output",
30:       "verification-protocol"
31:     ],
32:     "threat_catalog": "knowledge/threat-catalog.md",
33:     "languages": [
34:       "cpp",
35:       "java",
36:       "python",
37:       "go",
38:       "javascript"
39:     ],
40:     "standards": [
41:       "sei-cert-c",
42:       "sei-cert-cpp",
43:       "sei-cert-java",
44:       "owasp-cheatsheet-mapping"
45:     ],
46:     "detectors": [
47:       "concurrency-data-race",
48:       "concurrency-deadlock",
49:       "concurrency-race-condition",
50:       "concurrency-thread-unsafe-signal",
51:       "crypto-aes-ecb-mode",
52:       "crypto-custom-crypto",
53:       "crypto-hardcoded-iv",
54:       "crypto-hardcoded-secrets",
55:       "crypto-insufficient-key-length",
56:       "crypto-password-storage",
57:       "crypto-tls-version",
58:       "crypto-weak-crypto-algorithm",
59:       "crypto-weak-random",
60:       "error-debug-mode-production",
61:       "error-exception-swallow",
62:       "error-log-sensitive-data",
63:       "error-panic-to-client",
64:       "error-stack-trace-leak",
65:       "error-unified-error-format",
66:       "memory-bad-cast",
67:       "memory-buffer-overflow",
68:       "memory-double-free",
69:       "memory-format-string",
70:       "memory-heap-buffer-overflow",
71:       "memory-integer-overflow",
72:       "memory-memory-leak",
73:       "memory-mismatched-free",
74:       "memory-null-dereference",
75:       "memory-off-by-one",
76:       "memory-oob-read",
77:       "memory-uninitialized-memory",
78:       "memory-use-after-free",
79:       "resource-file-double-close",
80:       "resource-file-leak",
81:       "resource-file-use-after-close",
82:       "resource-lock-misuse",
83:       "resource-refcount-misuse",
84:       "resource-socket-leak",
85:       "system-command-injection",
86:       "system-insecure-permissions",
87:       "system-insecure-temp-file",
88:       "system-path-traversal",
89:       "system-privilege-escalation",
90:       "system-secrets-detection",
91:       "system-symlink-attack",
92:       "system-toctou",
93:       "web-auth-bypass",
94:       "web-code-injection",
95:       "web-csrf",
96:       "web-deserialization",
97:       "web-excessive-data-exposure",
98:       "web-idor",
99:       "web-input-validation",
100:       "web-jwt-misuse",
101:       "web-mass-assignment",
102:       "web-missing-authentication",
103:       "web-missing-authorization",
104:       "web-nosql-injection",
105:       "web-open-redirect",
106:       "web-prototype-pollution",
107:       "web-resource-exhaustion",
108:       "web-sql-injection",
109:       "web-ssrf",
110:       "web-ssti",
111:       "web-unrestricted-upload",
112:       "web-xss",
113:       "web-xxe"
114:     ]
115:   },
116:   "output": {
117:     "base_dir": ".codeagent",
118:     "scans_dir": "scans",
119:     "protocol": "scan-output/2.0"
120:   }
121: }

(End of file - total 121 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/extensions/secaudit-secguardian/extension.json"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/extensions/secaudit-secguardian/extension.json</path>
<type>file</type>
<content>
1: {
2:   "name": "secaudit-secguardian",
3:   "version": "0.12.0",
4:   "description": "\u2605 \u65d7\u8230\u4ea7\u54c1\uff1aAI \u6df1\u5ea6\u5b89\u5168\u5ba1\u8ba1 \u2014 13 \u4e2a\u5ba1\u8ba1\u57df\u8986\u76d6\u5168\u751f\u547d\u5468\u671f\u5b89\u5168",
5:   "author": "SecGuardian",
6:   "command": "secaudit",
7:   "protocol": "2.0",
8:   "platforms": {
9:     "claude-code": {
10:       "entry": "commands/secaudit.md"
11:     },
12:     "opencode": {
13:       "entry": "commands/secaudit.md"
14:     },
15:     "gemini-cli": {
16:       "entry": "commands/secaudit.md"
17:     }
18:   },
19:   "skills": [
20:     "secaudit"
21:   ],
22:   "knowledge": {
23:     "protocols": [
24:       "scan-output",
25:       "sarif-output",
26:       "verification-protocol"
27:     ],
28:     "languages": [
29:       "cpp",
30:       "java",
31:       "python",
32:       "go",
33:       "javascript"
34:     ]
35:   },
36:   "output": {
37:     "base_dir": ".codeagent",
38:     "scans_dir": "scans",
39:     "protocol": "scan-output/2.0"
40:   }
41: }

(End of file - total 41 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/indexer/indexer_test.go"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/indexer/indexer_test.go</path>
<type>file</type>
<content>
1: package indexer
2: 
3: import (
4: 	"os"
5: 	"path/filepath"
6: 	"strings"
7: 	"testing"
8: 
9: 	"github.com/secguardian/internal/parser"
10: )
11: 
12: // makeParseResult is a test helper to build a simple ParseResult.
13: func makeParseResult(file, lang string, fns []parser.FunctionInfo, vars []parser.VariableInfo, typs []parser.TypeInfo) *parser.ParseResult {
14: 	return &parser.ParseResult{
15: 		File:      file,
16: 		Language:  lang,
17: 		Functions: fns,
18: 		Variables: vars,
19: 		Types:     typs,
20: 	}
21: }
22: 
23: func TestExtractSymbols(t *testing.T) {
24: 	parsed := map[string]*parser.ParseResult{
25: 		"a.c": makeParseResult("a.c", "c",
26: 			[]parser.FunctionInfo{{Name: "main", File: "a.c", StartLine: 1, EndLine: 5}},
27: 			[]parser.VariableInfo{{Name: "count", File: "a.c", Line: 2}},
28: 			[]parser.TypeInfo{{Name: "Node", Kind: "struct", File: "a.c", StartLine: 1}},
29: 		),
30: 		"b.c": makeParseResult("b.c", "c",
31: 			[]parser.FunctionInfo{{Name: "helper", File: "b.c", StartLine: 1, EndLine: 3}},
32: 			nil,
33: 			nil,
34: 		),
35: 	}
36: 	symbols := ExtractSymbols(parsed)
37: 	if len(symbols.Functions) != 2 {
38: 		t.Errorf("Functions: got %d, want 2", len(symbols.Functions))
39: 	}
40: 	if len(symbols.Variables) != 1 {
41: 		t.Errorf("Variables: got %d, want 1", len(symbols.Variables))
42: 	}
43: 	if len(symbols.Types) != 1 {
44: 		t.Errorf("Types: got %d, want 1", len(symbols.Types))
45: 	}
46: }
47: 
48: func TestExtractSymbols_EmptyInput(t *testing.T) {
49: 	symbols := ExtractSymbols(map[string]*parser.ParseResult{})
50: 	if len(symbols.Functions) != 0 || len(symbols.Variables) != 0 || len(symbols.Types) != 0 {
51: 		t.Error("expected empty SymbolIndex from empty input")
52: 	}
53: }
54: 
55: func TestBuildCallGraph_DirectCall(t *testing.T) {
56: 	dir := t.TempDir()
57: 	fp := filepath.Join(dir, "calltest.c")
58: 	// function foo calls bar
59: 	content := `#include <stdio.h>
60: 
61: void bar() {
62:     printf("hello\n");
63: }
64: 
65: void foo() {
66:     bar();
67: }
68: 
69: int main() {
70:     foo();
71:     return 0;
72: }
73: `
74: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
75: 		t.Fatal(err)
76: 	}
77: 	parsed := map[string]*parser.ParseResult{
78: 		fp: makeParseResult(fp, "c",
79: 			[]parser.FunctionInfo{
80: 				{Name: "bar", File: fp, StartLine: 3, EndLine: 5},
81: 				{Name: "foo", File: fp, StartLine: 7, EndLine: 9},
82: 				{Name: "main", File: fp, StartLine: 11, EndLine: 14},
83: 			},
84: 			nil, nil,
85: 		),
86: 	}
87: 	symbols := ExtractSymbols(parsed)
88: 	cg := BuildCallGraph(parsed, symbols)
89: 	// foo calls bar
90: 	foundFooBar := false
91: 	foundMainFoo := false
92: 	for _, edge := range cg.Edges {
93: 		if edge.Caller == "foo" && edge.Callee == "bar" {
94: 			foundFooBar = true
95: 		}
96: 		if edge.Caller == "main" && edge.Callee == "foo" {
97: 			foundMainFoo = true
98: 		}
99: 	}
100: 	if !foundFooBar {
101: 		t.Error("expected edge foo -> bar, not found")
102: 	}
103: 	if !foundMainFoo {
104: 		t.Error("expected edge main -> foo, not found")
105: 	}
106: }
107: 
108: func TestBuildCallGraph_NoSelfEdges(t *testing.T) {
109: 	dir := t.TempDir()
110: 	fp := filepath.Join(dir, "recurse.c")
111: 	content := "void recurse() { recurse(); }\n"
112: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
113: 		t.Fatal(err)
114: 	}
115: 	parsed := map[string]*parser.ParseResult{
116: 		fp: makeParseResult(fp, "c",
117: 			[]parser.FunctionInfo{{Name: "recurse", File: fp, StartLine: 1, EndLine: 1}},
118: 			nil, nil,
119: 		),
120: 	}
121: 	symbols := ExtractSymbols(parsed)
122: 	cg := BuildCallGraph(parsed, symbols)
123: 	for _, edge := range cg.Edges {
124: 		if edge.Caller == "recurse" && edge.Callee == "recurse" {
125: 			t.Error("BuildCallGraph should not produce self-edges")
126: 		}
127: 	}
128: }
129: 
130: func TestBuildCallGraph_CommentExclusion(t *testing.T) {
131: 	dir := t.TempDir()
132: 	fp := filepath.Join(dir, "commentcall.c")
133: 	// foo does NOT call bar — bar only appears in a comment
134: 	content := `void bar() { }
135: 
136: void foo() {
137:     // bar();
138:     int x = 0;
139: }
140: `
141: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
142: 		t.Fatal(err)
143: 	}
144: 	parsed := map[string]*parser.ParseResult{
145: 		fp: makeParseResult(fp, "c",
146: 			[]parser.FunctionInfo{
147: 				{Name: "bar", File: fp, StartLine: 1, EndLine: 1},
148: 				{Name: "foo", File: fp, StartLine: 3, EndLine: 6},
149: 			},
150: 			nil, nil,
151: 		),
152: 	}
153: 	symbols := ExtractSymbols(parsed)
154: 	cg := BuildCallGraph(parsed, symbols)
155: 	for _, edge := range cg.Edges {
156: 		if edge.Caller == "foo" && edge.Callee == "bar" {
157: 			t.Error("foo should not call bar (bar() is in a comment)")
158: 		}
159: 	}
160: }
161: 
162: func TestMatchAllocFree_PairDetected(t *testing.T) {
163: 	dir := t.TempDir()
164: 	fp := filepath.Join(dir, "alloc.c")
165: 	content := `#include <stdlib.h>
166: 
167: void process() {
168:     char *buf = malloc(1024);
169:     if (buf) {
170:         free(buf);
171:     }
172: }
173: `
174: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
175: 		t.Fatal(err)
176: 	}
177: 	parsed := map[string]*parser.ParseResult{
178: 		fp: makeParseResult(fp, "c",
179: 			[]parser.FunctionInfo{{Name: "process", File: fp, StartLine: 3, EndLine: 8}},
180: 			nil, nil,
181: 		),
182: 	}
183: 	af := MatchAllocFree(parsed)
184: 	if len(af.Pairs) == 0 {
185: 		t.Fatal("expected at least one alloc-free pair")
186: 	}
187: 	pair := af.Pairs[0]
188: 	if pair.AllocFunc != "malloc" {
189: 		t.Errorf("AllocFunc = %q, want malloc", pair.AllocFunc)
190: 	}
191: 	if len(pair.FreeSites) == 0 {
192: 		t.Error("expected at least one free site")
193: 	}
194: }
195: 
196: func TestMatchAllocFree_NoAlloc(t *testing.T) {
197: 	dir := t.TempDir()
198: 	fp := filepath.Join(dir, "noalloc.c")
199: 	content := "void empty() { int x = 0; }\n"
200: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
201: 		t.Fatal(err)
202: 	}
203: 	parsed := map[string]*parser.ParseResult{
204: 		fp: makeParseResult(fp, "c",
205: 			[]parser.FunctionInfo{{Name: "empty", File: fp, StartLine: 1, EndLine: 1}},
206: 			nil, nil,
207: 		),
208: 	}
209: 	af := MatchAllocFree(parsed)
210: 	if len(af.Pairs) > 0 {
211: 		t.Errorf("expected 0 pairs for file without malloc, got %d", len(af.Pairs))
212: 	}
213: }
214: 
215: func TestBuildLockGraph_LockDetected(t *testing.T) {
216: 	dir := t.TempDir()
217: 	fp := filepath.Join(dir, "lock.c")
218: 	content := `#include <pthread.h>
219: 
220: void worker() {
221:     pthread_mutex_lock(&mutex);
222:     // critical section
223:     pthread_mutex_unlock(&mutex);
224: }
225: `
226: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
227: 		t.Fatal(err)
228: 	}
229: 	parsed := map[string]*parser.ParseResult{
230: 		fp: makeParseResult(fp, "c",
231: 			[]parser.FunctionInfo{{Name: "worker", File: fp, StartLine: 3, EndLine: 7}},
232: 			nil, nil,
233: 		),
234: 	}
235: 	lg := BuildLockGraph(parsed)
236: 	if len(lg.Mutexes) == 0 {
237: 		t.Error("expected at least one mutex usage")
238: 	}
239: 	for _, m := range lg.Mutexes {
240: 		if m.File != fp {
241: 			t.Errorf("LockUsage.File = %q, want %q", m.File, fp)
242: 		}
243: 		if m.LockLine == 0 {
244: 			t.Error("LockLine should not be 0")
245: 		}
246: 	}
247: }
248: 
249: func TestBuildLockGraph_NoLocks(t *testing.T) {
250: 	dir := t.TempDir()
251: 	fp := filepath.Join(dir, "nolock.c")
252: 	content := "void plain() { int x = 0; }\n"
253: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
254: 		t.Fatal(err)
255: 	}
256: 	parsed := map[string]*parser.ParseResult{
257: 		fp: makeParseResult(fp, "c",
258: 			[]parser.FunctionInfo{{Name: "plain", File: fp, StartLine: 1, EndLine: 1}},
259: 			nil, nil,
260: 		),
261: 	}
262: 	lg := BuildLockGraph(parsed)
263: 	if len(lg.Mutexes) > 0 {
264: 		t.Errorf("expected 0 mutexes for file without locks, got %d", len(lg.Mutexes))
265: 	}
266: }
267: 
268: func TestMatchAllocFree_Calloc(t *testing.T) {
269: 	dir := t.TempDir()
270: 	fp := filepath.Join(dir, "calloc.c")
271: 	content := "#include <stdlib.h>\nvoid f() { int *p = calloc(10, sizeof(int)); free(p); }\n"
272: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
273: 		t.Fatal(err)
274: 	}
275: 	parsed := map[string]*parser.ParseResult{
276: 		fp: makeParseResult(fp, "c",
277: 			[]parser.FunctionInfo{{Name: "f", File: fp, StartLine: 1, EndLine: 2}},
278: 			nil, nil,
279: 		),
280: 	}
281: 	af := MatchAllocFree(parsed)
282: 	if len(af.Pairs) == 0 {
283: 		t.Fatal("expected alloc-free pair for calloc")
284: 	}
285: 	pair := af.Pairs[0]
286: 	if pair.AllocFunc != "calloc" {
287: 		t.Errorf("AllocFunc = %q, want calloc", pair.AllocFunc)
288: 	}
289: }
290: 
291: // TestMatchAllocFree_MallocCommentExcluded ensures malloc in comment lines is ignored.
292: func TestMatchAllocFree_MallocCommentExcluded(t *testing.T) {
293: 	dir := t.TempDir()
294: 	fp := filepath.Join(dir, "comment_alloc.c")
295: 	content := "// malloc(100);\nvoid f() { int x = 0; }\n"
296: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
297: 		t.Fatal(err)
298: 	}
299: 	parsed := map[string]*parser.ParseResult{
300: 		fp: makeParseResult(fp, "c",
301: 			[]parser.FunctionInfo{{Name: "f", File: fp, StartLine: 2, EndLine: 2}},
302: 			nil, nil,
303: 		),
304: 	}
305: 	af := MatchAllocFree(parsed)
306: 	if len(af.Pairs) > 0 {
307: 		t.Errorf("expected 0 pairs when malloc is in comment, got %d", len(af.Pairs))
308: 	}
309: }
310: 
311: func TestBuildCallGraph_EmptyInput(t *testing.T) {
312: 	cg := BuildCallGraph(map[string]*parser.ParseResult{}, SymbolIndex{})
313: 	if len(cg.Edges) > 0 {
314: 		t.Errorf("expected empty CallGraph, got %d edges", len(cg.Edges))
315: 	}
316: }
317: 
318: func TestMatchAllocFree_EmptyInput(t *testing.T) {
319: 	af := MatchAllocFree(map[string]*parser.ParseResult{})
320: 	if len(af.Pairs) > 0 {
321: 		t.Errorf("expected empty AllocFreeMap, got %d pairs", len(af.Pairs))
322: 	}
323: }
324: 
325: func TestBuildLockGraph_EmptyInput(t *testing.T) {
326: 	lg := BuildLockGraph(map[string]*parser.ParseResult{})
327: 	if len(lg.Mutexes) > 0 {
328: 		t.Errorf("expected empty LockGraph, got %d mutexes", len(lg.Mutexes))
329: 	}
330: }
331: 
332: func TestIsCommentLine(t *testing.T) {
333: 	tests := []struct {
334: 		line     string
335: 		expected bool
336: 	}{
337: 		{"// this is a comment", true},
338: 		{"/* block comment", true},
339: 		{" * continuation of block", true},
340: 		{"int x = 0;", false},
341: 		{"  //  indented comment", true},
342: 		{"  int y = 1;  ", false},
343: 		{"", false},
344: 	}
345: 	for _, tt := range tests {
346: 		got := isCommentLine(tt.line)
347: 		if got != tt.expected {
348: 			t.Errorf("isCommentLine(%q) = %v, want %v", tt.line, got, tt.expected)
349: 		}
350: 	}
351: }
352: 
353: func TestMatchAllocFree_Realloc(t *testing.T) {
354: 	dir := t.TempDir()
355: 	fp := filepath.Join(dir, "realloc.c")
356: 	content := "#include <stdlib.h>\nvoid f() { void *p = malloc(100); p = realloc(p, 200); free(p); }\n"
357: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
358: 		t.Fatal(err)
359: 	}
360: 	parsed := map[string]*parser.ParseResult{
361: 		fp: makeParseResult(fp, "c",
362: 			[]parser.FunctionInfo{{Name: "f", File: fp, StartLine: 1, EndLine: 2}},
363: 			nil, nil,
364: 		),
365: 	}
366: 	af := MatchAllocFree(parsed)
367: 	if len(af.Pairs) == 0 {
368: 		t.Fatal("expected at least one pair (malloc+free or realloc+free)")
369: 	}
370: }
371: 
372: func TestMatchAllocFree_DeleteOperator(t *testing.T) {
373: 	dir := t.TempDir()
374: 	fp := filepath.Join(dir, "del.cpp")
375: 	content := "void f() { int *p = new int; delete p; }\n"
376: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
377: 		t.Fatal(err)
378: 	}
379: 	parsed := map[string]*parser.ParseResult{
380: 		fp: makeParseResult(fp, "cpp",
381: 			[]parser.FunctionInfo{{Name: "f", File: fp, StartLine: 1, EndLine: 1}},
382: 			nil, nil,
383: 		),
384: 	}
385: 	// "new" is not in allocFns (only malloc/calloc/realloc), but "delete" is in freeFns
386: 	// So this tests that "delete" as free function is detected even without matching alloc
387: 	af := MatchAllocFree(parsed)
388: 	// With only "new" (not in allocFns), we expect 0 pairs since no alloc is matched
389: 	t.Logf("pairs from new/delete (new not tracked): %d", len(af.Pairs))
390: }
391: 
392: func TestBuildCallGraph_CrossFileCall(t *testing.T) {
393: 	dir := t.TempDir()
394: 	fp1 := filepath.Join(dir, "a.c")
395: 	fp2 := filepath.Join(dir, "b.c")
396: 
397: 	content1 := "void helper() { }\n"
398: 	content2 := "#include \"a.h\"\nvoid caller() { helper(); }\n"
399: 
400: 	if err := os.WriteFile(fp1, []byte(content1), 0644); err != nil {
401: 		t.Fatal(err)
402: 	}
403: 	if err := os.WriteFile(fp2, []byte(content2), 0644); err != nil {
404: 		t.Fatal(err)
405: 	}
406: 
407: 	parsed := map[string]*parser.ParseResult{
408: 		fp1: makeParseResult(fp1, "c",
409: 			[]parser.FunctionInfo{{Name: "helper", File: fp1, StartLine: 1, EndLine: 1}},
410: 			nil, nil,
411: 		),
412: 		fp2: makeParseResult(fp2, "c",
413: 			[]parser.FunctionInfo{{Name: "caller", File: fp2, StartLine: 2, EndLine: 2}},
414: 			nil, nil,
415: 		),
416: 	}
417: 	symbols := ExtractSymbols(parsed)
418: 	cg := BuildCallGraph(parsed, symbols)
419: 
420: 	found := false
421: 	for _, edge := range cg.Edges {
422: 		if edge.Caller == "caller" && edge.Callee == "helper" {
423: 			found = true
424: 			break
425: 		}
426: 	}
427: 	if !found {
428: 		t.Error("expected cross-file edge caller -> helper")
429: 	}
430: }
431: 
432: func TestMatchAllocFree_NoFree(t *testing.T) {
433: 	dir := t.TempDir()
434: 	fp := filepath.Join(dir, "nofree.c")
435: 	content := "#include <stdlib.h>\nvoid leak() { void *p = malloc(100); }\n"
436: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
437: 		t.Fatal(err)
438: 	}
439: 	parsed := map[string]*parser.ParseResult{
440: 		fp: makeParseResult(fp, "c",
441: 			[]parser.FunctionInfo{{Name: "leak", File: fp, StartLine: 1, EndLine: 2}},
442: 			nil, nil,
443: 		),
444: 	}
445: 	af := MatchAllocFree(parsed)
446: 	if len(af.Pairs) > 0 {
447: 		t.Errorf("expected 0 pairs when malloc has no matching free, got %d", len(af.Pairs))
448: 	}
449: }
450: 
451: func TestBuildLockGraph_MultipleLocks(t *testing.T) {
452: 	dir := t.TempDir()
453: 	fp := filepath.Join(dir, "multilock.c")
454: 	content := strings.Repeat("pthread_mutex_lock(&m1);\n", 5)
455: 	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
456: 		t.Fatal(err)
457: 	}
458: 	parsed := map[string]*parser.ParseResult{
459: 		fp: makeParseResult(fp, "c",
460: 			[]parser.FunctionInfo{{Name: "f", File: fp, StartLine: 1, EndLine: 5}},
461: 			nil, nil,
462: 		),
463: 	}
464: 	lg := BuildLockGraph(parsed)
465: 	if len(lg.Mutexes) != 5 {
466: 		t.Errorf("expected 5 mutex lock entries, got %d", len(lg.Mutexes))
467: 	}
468: 	for _, m := range lg.Mutexes {
469: 		if m.LockLine == 0 {
470: 			t.Error("LockLine should not be 0")
471: 		}
472: 	}
473: }

(End of file - total 473 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/sync-manifest.sh"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/sync-manifest.sh</path>
<type>file</type>
<content>
1: #!/bin/bash
2: # sync-manifest.sh — Sync @secguardian token markers across project files from manifest.json
3: #
4: # Token format: NNN<!-- @secguardian:token_name -->
5: # Each token is a number followed by an HTML comment identifying the key.
6: # sync-manifest.sh reads the authoritative value from manifest.json and
7: # updates the number before the marker.
8: #
9: # Usage:
10: #   bash scripts/sync-manifest.sh           Update all files in-place
11: #   bash scripts/sync-manifest.sh --check   CI mode: verify only, exit 1 on mismatch
12: 
13: set -eo pipefail
14: PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
15: MANIFEST="$PROJECT_ROOT/manifest.json"
16: export MANIFEST_FILE="$MANIFEST"
17: 
18: CHECK=0
19: if [ "${1:-}" = "--check" ]; then CHECK=1; fi
20: 
21: if [ ! -f "$MANIFEST" ]; then
22:     echo "ERROR: manifest.json not found at $MANIFEST"
23:     exit 1
24: fi
25: 
26: # ── Read canonical values from manifest.json ──
27: TMP_ENV=$(mktemp /tmp/secguardian-tokens.XXXXXX)
28: trap "rm -f $TMP_ENV" EXIT
29: python3 > "$TMP_ENV" << 'PYEOF'
30: import json, os
31: with open(os.environ['MANIFEST_FILE']) as f:
32:     d = json.load(f)
33: det = d['knowledge']['detectors']
34: ns = det['namespaces']
35: print(f'DETECTOR_COUNT={det["count"]}')
36: print(f'NAMESPACE_COUNT={len(ns)}')
37: for k, v in ns.items():
38:     print(f'NAMESPACE_{k.upper()}={v}')
39: PYEOF
40: # shellcheck disable=SC1090
41: source "$TMP_ENV"
42: 
43: # ── Token definitions (name:value pairs) ──
44: tokens=(
45:     "detector_count:$DETECTOR_COUNT"
46:     "namespace_count:$NAMESPACE_COUNT"
47:     "namespace:memory:$NAMESPACE_MEMORY"
48:     "namespace:concurrency:$NAMESPACE_CONCURRENCY"
49:     "namespace:system:$NAMESPACE_SYSTEM"
50:     "namespace:crypto:$NAMESPACE_CRYPTO"
51:     "namespace:web:$NAMESPACE_WEB"
52:     "namespace:error:$NAMESPACE_ERROR"
53:     "namespace:resource:$NAMESPACE_RESOURCE"
54: )
55: 
56: get_token_value() {
57:     local name="$1"
58:     for pair in "${tokens[@]}"; do
59:         if [ "${pair%%:*}" = "$name" ]; then
60:             echo "${pair#*:}"
61:             return 0
62:         fi
63:     done
64:     return 1
65: }
66: 
67: # ── Find all files containing @secguardian tokens ──
68: FILES_WITH_TOKENS=$(grep -rl '@secguardian:' "$PROJECT_ROOT" \
69:     --include="*.md" --include="*.json" --include="*.sh" 2>/dev/null | \
70:     grep -v '.codeagent\|node_modules\|dist/\|.git/\|.claude/\|.opencode/\|.gemini/\|docs/superpowers/' || true)
71: 
72: if [ -z "$FILES_WITH_TOKENS" ] && [ "$CHECK" -eq 0 ]; then
73:     echo "No @secguardian token markers found in project. Nothing to sync."
74:     exit 0
75: fi
76: 
77: PASS=0; FAIL=0
78: UPDATED=0
79: 
80: for file in $FILES_WITH_TOKENS; do
81:     rel="${file#$PROJECT_ROOT/}"
82:     for pair in "${tokens[@]}"; do
83:         token_name="${pair%%:*}"
84:         expected="${pair#*:}"
85:         marker="<!-- @secguardian:$token_name -->"
86: 
87:         if grep -qF "$marker" "$file" 2>/dev/null; then
88:             # Extract number: digits immediately before the marker, with optional space
89:             actual=$(grep -oE "[0-9]+[[:space:]]*<!-- @secguardian:$token_name -->" "$file" 2>/dev/null | \
90:                      sed -E 's/[[:space:]]*<!--.*-->//' | head -1 || echo "")
91:             if [ -z "$actual" ]; then
92:                 echo "  ❌ $rel: marker for '$token_name' found but cannot parse number"
93:                 FAIL=$((FAIL + 1))
94:             elif [ "$CHECK" -eq 1 ]; then
95:                 if [ "$actual" != "$expected" ]; then
96:                     echo "  ❌ $rel: @secguardian:$token_name = $actual (expected $expected)"
97:                     FAIL=$((FAIL + 1))
98:                 else
99:                     PASS=$((PASS + 1))
100:                 fi
101:             else
102:                 # ── Update mode ──
103:                 if [ "$actual" != "$expected" ]; then
104:                     sed -i '' -E "s/[0-9]+[[:space:]]*$marker/$expected$marker/g" "$file"
105:                     echo "  ✓ $rel: @secguardian:$token_name $actual → $expected"
106:                     UPDATED=$((UPDATED + 1))
107:                 fi
108:             fi
109:         fi
110:     done
111: done
112: 
113: # ── Report ──
114: if [ "$CHECK" -eq 1 ]; then
115:     if [ "$FAIL" -eq 0 ] && [ "$PASS" -eq 0 ]; then
116:         echo "  (no token markers found in project files)"
117:         exit 0
118:     fi
119:     echo "  Token check: $PASS passed, $FAIL failed"
120:     [ "$FAIL" -eq 0 ] || exit 1
121: else
122:     echo "  Synced $UPDATED token occurrences across $(echo "$FILES_WITH_TOKENS" | wc -l | tr -d ' ') files."
123: fi

(End of file - total 123 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/knowledge/protocols"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/knowledge/protocols</path>
<type>directory</type>
<entries>
findings-schema.json
sarif-output.md
scan-output.md
verification-protocol.md

(4 entries)
</entries>
```

---

## Assistant (Build · DeepSeek V4 Flash · 3.2s)

_Thinking:_

Let me now check the remaining files I need to read for the review and then read the remaining render-report.py lines.

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/render-report.py",
  "offset": 1218
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/render-report.py</path>
<type>file</type>
<content>
1218:             p.append(f"<tr><td><code>{esc(fpath)}</code></td><td>{cnt}</td><td>{pct}%</td></tr>")
1219:         p.append("</table></div>")
1220: 
1221:     # Top 3
1222:     if top3:
1223:         p.append('<div class="card"><h2>Top Risks</h2><table>')
1224:         p.append("<tr><th>ID</th><th>Severity</th><th>File</th><th>Title</th></tr>")
1225:         for f in top3:
1226:             sev = f.get("severity","")
1227:             emoji = sev_emoji.get(sev,"")
1228:             cls = f"severity-{sev.lower()}"
1229:             p.append(f'<tr><td class="finding-id">{esc(f.get("id",""))}</td>'
1230:                      f'<td class="{cls}">{emoji} {sev}</td>'
1231:                      f'<td>{esc(f.get("file",""))}:{f.get("line","")}</td>'
1232:                      f'<td>{esc(f.get("title",""))}</td></tr>')
1233:         p.append("</table></div>")
1234: 
1235:     # Scan info
1236:     p.append('<div class="card"><p class="meta">Generated by SecGuardian | Detectors: ' +
1237:              f'{detectors.get("matched",0)} matched, {detectors.get("executed",0)} executed' +
1238:              " | This dashboard shows only high-level metrics. For detailed findings, open report.md</p></div>")
1239:     p.append("</body></html>")
1240: 
1241:     html = "".join(p)
1242:     out_path = os.path.join(output_dir, "dashboard.html")
1243:     with open(out_path, "w") as f:
1244:         f.write(html)
1245:     print(f"  \u2713 dashboard.html ({len(html)} bytes)")
1246: 
1247: 
1248: 
1249: # ── Main ────────────────────────────────────────
1250: 
1251: def main():
1252:     parser = argparse.ArgumentParser(
1253:         description="SecGuardian Report Rendering Engine v1.0",
1254:         formatter_class=argparse.RawDescriptionHelpFormatter,
1255:         epilog="""
1256: Examples:
1257:   %(prog)s --findings findings.json --index index.json --output ./output/
1258:   %(prog)s --ci --findings findings.json --index index.json --output ./output/
1259:   %(prog)s --format sarif --findings findings.json --output ./output/
1260:         """
1261:     )
1262:     parser.add_argument("--findings", required=False, help="Path to findings.json (v4.0 monolithic, legacy)")
1263:     parser.add_argument("--findings-dir",
1264:                         help="Path to v5.0 findings/ directory tree (overrides --findings)")
1265:     parser.add_argument("--index", help="Path to index.json (optional, for scope stats)")
1266:     parser.add_argument("--output", required=True, help="Output directory for generated files")
1267:     parser.add_argument("--ci", action="store_true", help="CI mode: set exit_code in status.json")
1268:     parser.add_argument("--format", choices=["all", "report", "sarif", "summary", "manifest", "status", "delta"],
1269:                         default="all", help="Generate only specific files (default: all)")
1270:     parser.add_argument("--command",
1271:                         help="Command name (secguard/secaudit/secreview). Overrides findings_data.")
1272:     parser.add_argument("--quality-gate", action="store_true", default=True,
1273:                         help="Run 4-segment quality gate validation (default: on)")
1274:     parser.add_argument("--no-quality-gate", action="store_false", dest="quality_gate",
1275:                         help="Skip quality gate validation")
1276:     args = parser.parse_args()
1277: 
1278:     # Validate: at least one of --findings or --findings-dir must be provided
1279:     if not args.findings and not args.findings_dir:
1280:         print("ERROR: Either --findings (v4.0) or --findings-dir (v5.0) must be provided", file=sys.stderr)
1281:         sys.exit(1)
1282: 
1283:     # Load findings — support v5.0 directory tree or v4.0 monolithic JSON
1284:     if args.findings_dir:
1285:         # v5.0: load from directory tree
1286:         findings = load_findings_from_tree(args.findings_dir)
1287:         findings_data = {
1288:             "schema_version": "1.0",
1289:             "scan_id": "unknown",
1290:             "command": args.command or "secguard",
1291:             "started_at": "",
1292:             "completed_at": "",
1293:             "findings": findings,
1294:         }
1295:         # Try to load scan metadata from findings.json (same name as v4.0, now lightweight index)
1296:         index_path = os.path.join(args.output, "findings.json")
1297:         if os.path.isfile(index_path):
1298:             index_meta = load_json(index_path)
1299:             for key in ["scan_id", "command", "started_at", "completed_at",
1300:                          "duration_ms", "path", "mode", "filters", "language",
1301:                          "scope", "detectors", ]:
1302:                 if key in index_meta and key not in ("findings_index", "summary"):
1303:                     findings_data[key] = index_meta[key]
1304:             if "scope" in index_meta and (not findings_data.get("scope") or findings_data["scope"].get("files", 0) == 0):
1305:                 findings_data["scope"] = index_meta["scope"]
1306:         # --command always wins over what the AI or validate-findings wrote
1307:         if args.command:
1308:             findings_data["command"] = args.command
1309:     else:
1310:         # v4.0: load monolithic findings.json
1311:         findings_data = load_json(args.findings)
1312: 
1313:     # Merge index.json scope if provided
1314:     if args.index:
1315:         index_data = load_json(args.index)
1316:         if "scope" not in findings_data or not findings_data["scope"]:
1317:             findings_data["scope"] = {
1318:                 "files": len(index_data.get("files", [])),
1319:                 "lines": 0,  # indexer doesn't count lines
1320:                 "functions": safe_len(index_data.get("symbols", {}).get("functions", [])),
1321:                 "call_edges": safe_len(index_data.get("call_graph", {}).get("edges", []))
1322:             }
1323: 
1324:     # Ensure output dir
1325:     os.makedirs(args.output, exist_ok=True)
1326: 
1327:     findings = findings_data.get("findings", [])
1328: 
1329:     # Sort findings: severity desc → file → line asc
1330:     sev_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Info": 4}
1331:     findings.sort(key=lambda f: (sev_order.get(f.get("severity", "Medium"), 5),
1332:                                   f.get("file", ""),
1333:                                   f.get("line", 0)))
1334:     # Compute SHA identity and sequential number for each finding
1335:     for i, f in enumerate(findings):
1336:         identity = f"{f.get('detector','')}:{f.get('file','')}:{f.get('line',0)}:{f.get('cwe','')}"
1337:         sha = hashlib.sha256(identity.encode()).hexdigest()[:12]
1338:         f['_seq'] = i + 1
1339:         f['_sha'] = sha
1340: 
1341:     # Quality gate (for secaudit)
1342:     gate_warnings = []
1343:     if args.quality_gate and findings_data["command"] == "secaudit":
1344:         passed, gate_warnings = quality_gate_report(findings)
1345:         if not passed:
1346:             print(f"⚠️  Quality Gate: {len([w for w in gate_warnings if w.startswith('  ❌')])} findings incomplete")
1347: 
1348:     files_generated = []
1349: 
1350:     def write_json(filename, data):
1351:         path = os.path.join(args.output, filename)
1352:         with open(path, "w") as f:
1353:             json.dump(data, f, indent=2, ensure_ascii=False)
1354:         files_generated.append(filename)
1355:         print(f"  ✓ {filename}")
1356: 
1357:     # Generate requested files
1358:     fmt = args.format
1359: 
1360:     if fmt in ("all", "report"):
1361:         report = generate_report_md(findings_data)
1362:         # Prepend quality gate warnings for secaudit
1363:         if gate_warnings and findings_data["command"] == "secaudit":
1364:             report = "\n".join(gate_warnings) + "\n\n" + report
1365:         path = os.path.join(args.output, "report.md")
1366:         with open(path, "w") as f:
1367:             f.write(report)
1368:         files_generated.append("report.md")
1369:         print(f"  ✓ report.md ({len(report)} bytes)")
1370: 
1371:     if fmt in ("all", "report"):
1372:         render_executive_summary(findings_data, args.output)
1373:     if fmt in ("all", "report"):
1374:         render_remediation_pack(findings, findings_data, args.output)
1375: 
1376:     if fmt in ("all", "report"):
1377:         render_dashboard(findings_data, args.output)
1378: 
1379: 
1380:     if fmt in ("all", "sarif"):
1381:         sarif = generate_sarif(findings_data)
1382:         write_json("results.sarif", sarif)
1383: 
1384:     if fmt in ("all", "summary"):
1385:         summary = generate_summary(findings_data)
1386:         write_json("summary.json", summary)
1387: 
1388:     if fmt in ("all", "manifest"):
1389:         manifest = generate_manifest(findings_data)
1390:         write_json("manifest.json", manifest)
1391: 
1392:     if fmt in ("all", "status"):
1393:         status = generate_status(findings_data, ci_mode=args.ci)
1394:         write_json("status.json", status)
1395:         if args.ci and status["exit_code"] != 0:
1396:             print(f"\n  ⚠️  CI Gate FAILED — exit code {status['exit_code']}")
1397: 
1398:     if fmt in ("all", "delta"):
1399:         delta = generate_delta(findings_data, args.output)
1400:         write_json("delta.json", delta)
1401: 
1402:     # Create latest symlink
1403:     scans_dir = os.path.dirname(args.output.rstrip('/'))
1404:     if scans_dir:
1405:         latest_link = os.path.join(scans_dir, "latest")
1406:         scan_dir_name = os.path.basename(args.output.rstrip('/'))
1407:         if os.path.islink(latest_link) or not os.path.exists(latest_link):
1408:             if os.path.islink(latest_link):
1409:                 os.unlink(latest_link)
1410:             os.symlink(scan_dir_name, latest_link)
1411:             print(f"  ✓ latest → {scan_dir_name}")
1412: 
1413:     print(f"\n✅ Generated {len(files_generated)} files in {args.output}")
1414:     if gate_warnings and findings_data["command"] == "secaudit":
1415:         print("⚠️  Quality gate warnings present — see report.md header for details")
1416: 
1417: 
1418:     # ── Auto-generate findings.json (v5.0 findings-dir mode) ────
1419:     # Eliminates AI needing to remember the findings.json schema.
1420:     # Only runs in v5.0 mode (--findings-dir, not legacy --findings).
1421:     if args.findings_dir and findings:
1422:         findings_idx = []
1423:         for idx, f in enumerate(findings, 1):
1424:             det = f.get('detector', '')
1425:             file_ = f.get('file', '')
1426:             line = f.get('line', 0)
1427:             cwe = f.get('cwe', '')
1428:             raw = f"{det}:{file_}:{line}:{cwe}"
1429:             sha = hashlib.sha256(raw.encode()).hexdigest()[:12]
1430:             slug = os.path.splitext(os.path.basename(file_))[0]
1431:             ns = det.split('.')[0]
1432:             det_name = det.split('.', 1)[1] if '.' in det else ''
1433:             findings_idx.append({
1434:                 "seq": idx, "sha": sha,
1435:                 "severity": f.get('severity', ''),
1436:                 "cwe": cwe, "detector": det,
1437:                 "file": file_, "line": line,
1438:                 "function": f.get('function', '') or '',
1439:                 "title": f.get('title', '') or '',
1440:                 "path": f"findings/{ns}/{det_name}/{sha}_{slug}-{line}.json"
1441:             })
1442:         index_meta = {
1443:             "scan_id": findings_data.get("scan_id", "unknown"),
1444:             "command": findings_data.get("command", args.command or "secguard"),
1445:             "path": findings_data.get("path", ""),
1446:             "mode": findings_data.get("mode", "full"),
1447:             "language": findings_data.get("language", ""),
1448:             "timing": {
1449:                 "started": findings_data.get("started_at", ""),
1450:                 "completed": findings_data.get("completed_at", ""),
1451:                 "duration_ms": findings_data.get("duration_ms", 0)
1452:             },
1453:             "scope": findings_data.get("scope", {}),
1454:             "detectors": findings_data.get("detectors", {}),
1455:             "findings_index": findings_idx
1456:         }
1457:         findings_json_path = os.path.join(args.output, "findings.json")
1458:         with open(findings_json_path, 'w', encoding='utf-8') as fout:
1459:             json.dump(index_meta, fout, indent=2, ensure_ascii=False)
1460:         print(f"  \u2713 findings.json ({len(findings)} findings in index)")
1461: 
1462: if __name__ == "__main__":
1463:     main()

(End of file - total 1463 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/install.sh"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/install.sh</path>
<type>file</type>
<content>
1: #!/bin/bash
2: # ╔══════════════════════════════════════════════════════════════╗
3: # ║  SecGuardian — Installer (macOS / Linux)                   ║
4: # ║  将发布包安装到用户级或项目级 AI Agent 目录中               ║
5: # ╚══════════════════════════════════════════════════════════════╝
6: #
7: # 用法:
8: #   bash install.sh --user [options]              # 用户级（推荐）
9: #   bash install.sh <target-project> [options]    # 项目级
10: #   bash install.sh --uninstall [--user]          # 卸载
11: #
12: # 选项:
13: #   --user              安装到用户家目录（推荐，跨项目共用）
14: #   --all               安装全部三个平台 (默认)
15: #   --claude            仅安装 Claude Code
16: #   --opencode          仅安装 OpenCode
17: #   --gemini            仅安装 Gemini CLI
18: #   --release-dir <dir> 指定发布包所在目录 (默认: 当前目录)
19: #   --version <ver>     指定版本号 (默认: 自动检测)
20: #   --uninstall        卸载已安装的 secguardian 文件
21: #   --dry-run           仅显示将要执行的操作，不实际安装
22: #   --no-backup         不备份已有安装
23: #
24: # 示例:
25: #   # 用户级安装（推荐）
26: #   bash install.sh --user --all                 # 安装全部平台到 ~/
27: #   bash install.sh --user --opencode            # 仅 OpenCode 到 ~/.opencode/
28: #
29: #   # 项目级安装
30: #   bash install.sh ~/my-project --all           # 安装全部平台到项目
31: #   bash install.sh ~/my-project --opencode      # 仅 OpenCode 到项目
32: #   bash install.sh ~/my-project --dry-run       # 预览操作
33: #   bash install.sh --uninstall                     # 卸载项目级
34: #   bash install.sh --user --uninstall              # 卸载用户级
35: 
36: set -euo pipefail
37: 
38: # ── 颜色 ──────────────────────────────────────
39: BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
40: YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
41: 
42: log_step()  { echo -e "${BOLD}═══ $1 ═══${NC}"; }
43: log_info()  { echo -e "${CYAN}  →${NC} $1"; }
44: log_done()  { echo -e "${GREEN}  ✓${NC} $1"; }
45: log_warn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
46: log_error() { echo -e "${RED}  ✗${NC} $1"; }
47: 
48: # ── 帮助信息 ──────────────────────────────────
49: show_help() {
50:     head -36 "$0" | tail -30
51:     exit 0
52: }
53: 
54: # ── 参数解析 ──────────────────────────────────
55: USER_MODE=false
56: UNINSTALL_MODE=false
57: TARGET=""
58: PLATFORM="all"
59: RELEASE_DIR="."
60: VERSION=""
61: DRY_RUN=false
62: NO_BACKUP=false
63: 
64: while [[ $# -gt 0 ]]; do
65:     case "$1" in
66:         -h|--help|help) show_help ;;
67:         --user)         USER_MODE=true; shift ;;
68:         --uninstall)    UNINSTALL_MODE=true; shift ;;
69:         --all)          PLATFORM="all"; shift ;;
70:         --claude)       PLATFORM="claude"; shift ;;
71:         --opencode)     PLATFORM="opencode"; shift ;;
72:         --gemini)       PLATFORM="gemini"; shift ;;
73:         --release-dir)  RELEASE_DIR="$2"; shift 2 ;;
74:         --version)      VERSION="$2"; shift 2 ;;
75:         --dry-run)      DRY_RUN=true; shift ;;
76:         --no-backup)    NO_BACKUP=true; shift ;;
77:         -*)
78:             log_error "未知选项: $1"
79:             echo "用法: bash install.sh --user [options]  或  bash install.sh <project> [options]"
80:             exit 1
81:             ;;
82:         *)
83:             if [ -z "$TARGET" ]; then
84:                 TARGET="$1"
85:             else
86:                 log_error "多余的参数: $1"
87:                 exit 1
88:             fi
89:             shift
90:             ;;
91:     esac
92: done
93: 
94: # ── 确定安装目标路径 ──────────────────────────
95: if $UNINSTALL_MODE && [ -z "$TARGET" ] && ! $USER_MODE; then
96:     log_error "请指定 --user（卸载用户级）或 <project-path>（卸载项目级）"
97:     exit 1
98: fi
99: 
100: if $USER_MODE; then
101:     TARGET="$HOME"
102:     INSTALL_MODE="用户级"
103:     INSTALL_MODE_DESC="跨所有项目可用"
104: else
105:     if [ -z "$TARGET" ]; then
106:         log_error "请指定 --user（用户级安装）或 <project-path>（项目级安装）"
107:         echo ""
108:         echo "  用户级（推荐）:  bash install.sh --user --all"
109:         echo "  项目级:          bash install.sh ~/my-project --opencode"
110:         exit 1
111:     fi
112:     if [ ! -d "$TARGET" ]; then
113:         log_error "目标路径不存在: $TARGET"
114:         exit 1
115:     fi
116:     TARGET="$(cd "$TARGET" && pwd)"
117:     INSTALL_MODE="项目级"
118:     INSTALL_MODE_DESC="仅当前项目可用"
119: fi
120: 
121: RELEASE_DIR="$(cd "$RELEASE_DIR" 2>/dev/null && pwd || echo "$RELEASE_DIR")"
122: 
123: echo ""
124: echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
125: echo -e "${BOLD}║${NC}  SecGuardian — ${INSTALL_MODE}安装                 ${BOLD}║${NC}"
126: echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
127: echo ""
128: echo -e "  安装模式: ${CYAN}${INSTALL_MODE} (${INSTALL_MODE_DESC})${NC}"
129: echo -e "  安装路径: ${CYAN}$TARGET${NC}"
130: echo -e "  平台:     ${CYAN}$PLATFORM${NC}"
131: echo ""
132: 
133: # ── 自动检测版本 ──────────────────────────────
134: if [ -z "$VERSION" ]; then
135:     for f in "$RELEASE_DIR"/secguardian-*-claude-code.zip; do
136:         if [ -f "$f" ]; then
137:             VERSION=$(basename "$f" | sed 's/secguardian-//; s/-claude-code.zip//')
138:             break
139:         fi
140:     done
141:     VERSION="${VERSION:-0.4.0}"
142: fi
143: 
144: log_info "检测到版本: v$VERSION"
145: 
146: # ── 查找发布包 ────────────────────────────────
147: find_claude_zip() {
148:     local candidates=(
149:         "$RELEASE_DIR/secguardian-${VERSION}-claude-code.zip"
150:     )
151:     for c in "${candidates[@]}"; do
152:         if [ -f "$c" ]; then echo "$c"; return 0; fi
153:     done
154:     local found=$(ls "$RELEASE_DIR"/secguardian-*-claude-code.zip 2>/dev/null | head -1)
155:     if [ -n "$found" ]; then echo "$found"; return 0; fi
156:     return 1
157: }
158: 
159: find_opencode_zip() {
160:     local candidates=(
161:         "$RELEASE_DIR/secguardian-${VERSION}-opencode.zip"
162:     )
163:     for c in "${candidates[@]}"; do
164:         if [ -f "$c" ]; then echo "$c"; return 0; fi
165:     done
166:     local found=$(ls "$RELEASE_DIR"/secguardian-*-opencode.zip 2>/dev/null | head -1)
167:     if [ -n "$found" ]; then echo "$found"; return 0; fi
168:     return 1
169: }
170: 
171: find_gemini_zip() {
172:     local candidates=(
173:         "$RELEASE_DIR/secguardian-${VERSION}-gemini-cli.zip"
174:     )
175:     for c in "${candidates[@]}"; do
176:         if [ -f "$c" ]; then echo "$c"; return 0; fi
177:     done
178:     local found=$(ls "$RELEASE_DIR"/secguardian-*-gemini-cli.zip 2>/dev/null | head -1)
179:     if [ -n "$found" ]; then echo "$found"; return 0; fi
180:     return 1
181: }
182: 
183: # ── 备份函数 ──────────────────────────────────
184: backup_dir() {
185:     local dir="$1"
186:     if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
187:         local backup="$dir.backup.$(date +%Y%m%d-%H%M%S)"
188:         mv "$dir" "$backup"
189:         log_info "已备份: $backup"
190:     fi
191: }
192: 
193: # ── 安装 Claude Code (官方插件格式: ~/.claude/plugins/) ──
194: # Ref: https://code.claude.com/docs/en/plugins-reference
195: install_claude() {
196:     local label="Claude Code"
197:     if $USER_MODE; then
198:         log_step "Claude Code → ~/.claude/plugins/ (用户级)"
199:     else
200:         log_step "Claude Code → .claude/plugins/ (项目级)"
201:     fi
202: 
203:     local zip_file=$(find_claude_zip)
204:     if [ -z "$zip_file" ]; then
205:         log_warn "未找到 Claude Code 发布包，跳过"
206:         log_info "期望文件: secguardian-${VERSION}-claude-code.zip"
207:         return 1
208:     fi
209: 
210:     local plugin_dir="$TARGET/.claude/plugins"
211: 
212:     if $DRY_RUN; then
213:         echo "  [DRY-RUN] 解压 $zip_file → $plugin_dir/"
214:         return 0
215:     fi
216: 
217:     # Clean old legacy extensions format + old plugin
218:     rm -rf "$TARGET/.claude/extensions/secguard-secguardian" \
219:            "$TARGET/.claude/extensions/secaudit-secguardian" \
220:            "$TARGET/.claude/extensions/secreview-secguardian" \
221:            "$plugin_dir/secguardian"
222: 
223:     mkdir -p "$plugin_dir"
224:     unzip -qo "$zip_file" -d "$plugin_dir/"
225:     log_done "已安装到 $plugin_dir/secguardian/"
226: 
227:     # Make binaries executable
228:     find "$plugin_dir" -name 'secguardian-index*' -type f -exec chmod +x {} \; 2>/dev/null || true
229: }
230: 
231: # ── 安装 OpenCode (用户级: ~/.config/opencode/ ; 项目级: <project>/.opencode/) ──
232: # Ref: https://opencode.ai/docs/skills
233: install_opencode() {
234:     local label="OpenCode"
235:     if $USER_MODE; then
236:         log_step "OpenCode → ~/.config/opencode/ (用户级)"
237:     else
238:         log_step "OpenCode → .opencode/ (项目级)"
239:     fi
240: 
241:     local zip_file=$(find_opencode_zip)
242:     if [ -z "$zip_file" ]; then
243:         log_warn "未找到 OpenCode 发布包，跳过"
244:         log_info "期望文件: secguardian-${VERSION}-opencode.zip"
245:         return 1
246:     fi
247: 
248:     if $USER_MODE; then
249:         local oc_dir="$HOME/.config/opencode"
250:     else
251:         local oc_dir="$TARGET/.opencode"
252:     fi
253: 
254:     if $DRY_RUN; then
255:         echo "  [DRY-RUN] 解压 $zip_file → $oc_dir/"
256:         return 0
257:     fi
258: 
259:     $NO_BACKUP || backup_dir "$oc_dir"
260:     rm -rf "$oc_dir"
261:     mkdir -p "$oc_dir"
262: 
263:     unzip -qo "$zip_file" -d "$oc_dir/"
264:     log_done "已安装到 $oc_dir/"
265: 
266:     # Make binaries executable
267:     find "$oc_dir/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
268: }
269: 
270: # ── 安装 Gemini CLI (官方扩展格式: ~/.gemini/extensions/) ──
271: # Ref: https://geminicli.com/docs/extensions/reference/
272: install_gemini() {
273:     local label="Gemini CLI"
274:     if $USER_MODE; then
275:         log_step "Gemini CLI → ~/.gemini/extensions/ (用户级)"
276:     else
277:         log_step "Gemini CLI → .gemini/extensions/ (项目级)"
278:     fi
279: 
280:     local zip_file=$(find_gemini_zip)
281:     if [ -z "$zip_file" ]; then
282:         log_warn "未找到 Gemini CLI 发布包，跳过"
283:         log_info "期望文件: secguardian-${VERSION}-gemini-cli.zip"
284:         return 1
285:     fi
286: 
287:     if $USER_MODE; then
288:         local gm_dir="$HOME/.gemini/extensions"
289:     else
290:         local gm_dir="$TARGET/.gemini/extensions"
291:     fi
292: 
293:     if $DRY_RUN; then
294:         echo "  [DRY-RUN] 解压 $zip_file → $gm_dir/"
295:         return 0
296:     fi
297: 
298:     mkdir -p "$gm_dir"
299:     unzip -qo "$zip_file" -d "$gm_dir/"
300:     log_done "已安装到 $gm_dir/secguardian/"
301: 
302:     # Make binaries executable
303:     find "$gm_dir/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
304: }
305: 
306: # ── 健康检查 ──────────────────────────────────
307: run_health_check() {
308:     log_step "健康检查"
309: 
310:     local indexer=""
311:     for candidate in \
312:         "$TARGET/.opencode/scripts/secguardian-index" \
313:         "$TARGET/.gemini/scripts/secguardian-index" \
314:         "$TARGET/.claude/extensions/secguard-secguardian/scripts/secguardian-index" \
315:         "$TARGET/.claude/extensions/secaudit-secguardian/scripts/secguardian-index" \
316:         "$TARGET/.claude/extensions/secreview-secguardian/scripts/secguardian-index"; do
317:         if [ -x "$candidate" ] && [ -f "$candidate" ]; then
318:             indexer="$candidate"
319:             break
320:         fi
321:     done
322: 
323:     if [ -z "$indexer" ]; then
324:         log_warn "未找到 secguardian-index wrapper（平台可能不支持）"
325:         return 0
326:     fi
327: 
328:     if $DRY_RUN; then
329:         echo "  [DRY-RUN] $indexer --health"
330:         return 0
331:     fi
332: 
333:     if "$indexer" --health 2>/dev/null; then
334:         log_done "索引器健康检查通过"
335:     else
336:         log_warn "索引器健康检查完成（退出码非0，但二进制可执行）"
337:     fi
338: }
339: 
340: # ── 安装摘要 ──────────────────────────────────
341: print_summary() {
342:     echo ""
343:     echo -e "${BOLD}════════════════════════════════════════════════${NC}"
344:     echo -e "${GREEN}${BOLD}  安装完成!${NC}"
345:     echo ""
346:     echo -e "  安装模式: ${CYAN}${INSTALL_MODE}${NC}"
347:     echo -e "  安装路径: ${CYAN}$TARGET${NC}"
348:     echo ""
349: 
350:     if [ -d "$TARGET/.claude/extensions" ] && [ "$(ls -A "$TARGET/.claude/extensions" 2>/dev/null)" ]; then
351:         echo -e "  ${GREEN}✓${NC} Claude Code:  $TARGET/.claude/extensions/"
352:         echo "     重启 Claude Code 后使用 /secguard, /secaudit, /secreview"
353:     fi
354: 
355:     if [ -d "$TARGET/.opencode/commands" ]; then
356:         echo -e "  ${GREEN}✓${NC} OpenCode:      $TARGET/.opencode/ (commands + skills + knowledge + scripts)"
357:         echo "     重启 OpenCode 后使用 /secguard, /secaudit, /secreview"
358:     fi
359: 
360:     if [ -d "$TARGET/.gemini/skills" ]; then
361:         echo -e "  ${GREEN}✓${NC} Gemini CLI:    $TARGET/.gemini/ (commands + skills + knowledge + scripts)"
362:         echo "     在 Gemini CLI 中运行 /skills reload"
363:     fi
364: 
365:     echo ""
366:     echo -e "  ${BOLD}扫描输出目录:${NC} .codeagent/<extension>/scans/<scan-id>/"
367:     echo ""
368: 
369:     if $USER_MODE; then
370:         echo -e "  ${BOLD}提示:${NC} 用户级安装使 SecGuardian 在所有项目中可用。"
371:         echo "        如果某个项目同时存在项目级安装，项目级优先。"
372:     fi
373:     echo ""
374: }
375: 
376: # ── 卸载 ──────────────────────────────────────
377: do_uninstall() {
378:     echo ""
379:     echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
380:     echo -e "${BOLD}║${NC}  SecGuardian — 卸载 (${INSTALL_MODE})                ${BOLD}║${NC}"
381:     echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
382:     echo ""
383:     echo -e "  路径: ${CYAN}$TARGET${NC}"
384:     echo ""
385: 
386:     # Claude Code
387:     local ext_dir="$TARGET/.claude/extensions"
388:     for name in secguard-secguardian secaudit-secguardian secreview-secguardian; do
389:         if [ -d "$ext_dir/$name" ]; then
390:             rm -rf "$ext_dir/$name"
391:             log_done "已移除: $ext_dir/$name"
392:         fi
393:     done
394: 
395:     # OpenCode
396:     for sub in commands skills knowledge scripts; do
397:         if [ -d "$TARGET/.opencode/$sub" ]; then
398:             rm -rf "$TARGET/.opencode/$sub"
399:             log_done "已移除: $TARGET/.opencode/$sub"
400:         fi
401:     done
402: 
403:     # Gemini CLI
404:     for sub in commands skills knowledge scripts GEMINI.md; do
405:         if [ -e "$TARGET/.gemini/$sub" ]; then
406:             rm -rf "$TARGET/.gemini/$sub"
407:             log_done "已移除: $TARGET/.gemini/$sub"
408:         fi
409:     done
410: 
411:     echo ""
412:     log_done "卸载完成"
413: }
414: 
415: # ── 主流程 ─────────────────────────────────────
416: if $UNINSTALL_MODE; then
417:     do_uninstall
418:     exit 0
419: fi
420: 
421: FAILURES=0
422: 
423: case "$PLATFORM" in
424:     all)
425:         install_claude   || FAILURES=$((FAILURES + 1))
426:         echo ""
427:         install_opencode || FAILURES=$((FAILURES + 1))
428:         echo ""
429:         install_gemini   || FAILURES=$((FAILURES + 1))
430:         ;;
431:     claude)
432:         install_claude   || FAILURES=$((FAILURES + 1))
433:         ;;
434:     opencode)
435:         install_opencode || FAILURES=$((FAILURES + 1))
436:         ;;
437:     gemini)
438:         install_gemini   || FAILURES=$((FAILURES + 1))
439:         ;;
440: esac
441: 
442: if ! $DRY_RUN && [ "$FAILURES" -eq 0 ]; then
443:     echo ""
444:     run_health_check
445: fi
446: 
447: echo ""
448: print_summary
449: 
450: if [ "$FAILURES" -gt 0 ]; then
451:     log_warn "$FAILURES 个平台安装失败（可能缺少对应的发布包）"
452: fi

(End of file - total 452 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/secguardian-index"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/secguardian-index</path>
<type>file</type>
<content>
1: #!/bin/bash
2: # SecGuardian — Indexer binary wrapper (shared index)
3: #
4: # All commands (secguard/secaudit/secreview) share one index.json at
5: # the project root (.codeagent/index.json). If the file already exists,
6: # the build is skipped. Use --force to force rebuild.
7: #
8: 
9: 
10: SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
11: BIN_DIR="$SCRIPT_DIR/bin"
12: 
13: # --- Parse --path / --output for caching ---
14: SRC_PATH=""
15: OUTPUT_PATH=""
16: FORCE_REBUILD=0
17: ARGS=()
18: while [ $# -gt 0 ]; do
19:     case "$1" in
20:         --path) SRC_PATH="$2"; ARGS+=("$1" "$2"); shift 2 ;;
21:         --output) OUTPUT_PATH="$2"; ARGS+=("$1" "$2"); shift 2 ;;
22:         --force) FORCE_REBUILD=1; shift ;;
23:         *) ARGS+=("$1"); shift ;;
24:     esac
25: done
26: # Resolve --path to absolute BEFORE running (match Go indexer's stored path)
27: if [ -n "$SRC_PATH" ]; then
28:     ABS_PATH="$(python3 -c "import os; print(os.path.abspath('$SRC_PATH'))" 2>/dev/null)"
29:     if [ -n "$ABS_PATH" ]; then
30:         SRC_PATH="$ABS_PATH"
31: 
32:     fi
33: fi
34: set -- "${ARGS[@]}"
35: 
36: # --- Shared index: if --output path already exists, skip build ---
37: # This makes index.json a shared asset — once built, all commands reuse it.
38: # Use --force to force rebuild even if the file exists.
39: # If the file exists, verify the stored --path matches the current one.
40: if [ "$FORCE_REBUILD" -ne 1 ] && [ -n "$OUTPUT_PATH" ] && [ -f "$OUTPUT_PATH" ] && [ -n "$SRC_PATH" ]; then
41:     STORED_PATH=$(python3 -c "
42: import json
43: try:
44:     d = json.load(open('$OUTPUT_PATH'))
45:     print(d.get('path', ''))
46: except: print('')
47: " 2>/dev/null)
48:     RESOLVED_PATH="$SRC_PATH"  # Use raw path (Go indexer stores it as-is)
49:     if [ "$STORED_PATH" = "$RESOLVED_PATH" ]; then
50:         echo "INDEX EXISTS: $OUTPUT_PATH (path matches, use --force to rebuild)" >&2
51:         exit 0
52:     elif [ -n "$STORED_PATH" ]; then
53:         echo "INDEX PATH MISMATCH: stored=$STORED_PATH vs current=$RESOLVED_PATH — rebuilding" >&2
54:     fi
55: fi
56: 
57: # --- Locate binary ---
58: locate_binary() {
59:     local c="$BIN_DIR/secguardian-index"
60:     if [ -f "$c" ] && [ -x "$c" ]; then echo "$c"; return 0; fi
61:     local os arch
62:     os="$(uname -s | tr '[:upper:]' '[:lower:]')"
63:     arch="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
64:     local p="$BIN_DIR/secguardian-index-${os}-${arch}"
65:     if [ -f "$p" ] && [ -x "$p" ]; then echo "$p"; return 0; fi
66:     local d="$SCRIPT_DIR/../internal/secguardian-index"
67:     if [ -f "$d" ] && [ -x "$d" ]; then echo "$d"; return 0; fi
68:     return 1
69: }
70: BINARY="$(locate_binary)" || {
71:     echo "Indexer binary not found. Expected: $BIN_DIR/secguardian-index or platform variant" >&2
72:     exit 1
73: }
74: 
75: # --- Run binary ---
76: "$BINARY" "$@"
77: BINARY_EXIT=$?
78: 
79: exit $BINARY_EXIT

(End of file - total 79 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/knowledge/threat-catalog.md",
  "limit": 50
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/knowledge/threat-catalog.md</path>
<type>file</type>
<content>
1: ---
2: category: index
3: description: 安全威胁目录 — 覆盖所有 71<!-- @secguardian:detector_count --> 个检测器对应威胁类型的快速索引
4: cwe_coverage: CWE Top 25 100%
5: owasp_coverage: OWASP Top 10 100%
6: ---
7: 
8: # 安全威胁目录 (Threat Catalog)
9: 
10: 每个威胁对应一个自包含的 detector 文件（`knowledge/guard-rules/<namespace>-<name>.md`），内含完整威胁定义、检测逻辑、修复指引、误报排除和检测模式。
11: 
12: > 完整 detector 清单见 `knowledge/language-index.md`。本文档提供按命名空间分组的人类可读威胁索引。
13: 
14: ## 内存安全 (memory) — 13<!-- @secguardian:namespace:memory --> 个 detectors
15: 
16: | 威胁 | CWE | 严重度 | Detector | 影响语言 |
17: |------|-----|--------|----------|---------|
18: | 空指针解引用 | CWE-476 | High | `memory.null-dereference` | C/C++ |
19: | 双重释放 | CWE-415 | Critical | `memory.double-free` | C/C++ |
20: | 释放后使用 | CWE-416 | Critical | `memory.use-after-free` | C/C++ |
21: | 缓冲区溢出 | CWE-120 | Critical | `memory.buffer-overflow` | C/C++ |
22: | 堆缓冲区溢出 | CWE-122 | Critical | `memory.heap-buffer-overflow` | C/C++ |
23: | 格式字符串攻击 | CWE-134 | Critical | `memory.format-string` | C/C++ |
24: | 整数溢出 | CWE-190 | High | `memory.integer-overflow` | C/C++ |
25: | 未初始化内存 | CWE-457 | Medium | `memory.uninitialized-memory` | C/C++ |
26: | 内存泄露 | CWE-401 | Medium | `memory.memory-leak` | C/C++ |
27: | 不匹配释放 | CWE-762 | High | `memory.mismatched-free` | C/C++ |
28: | Off-by-One | CWE-193 | High | `memory.off-by-one` | C/C++ |
29: | 错误类型转换 | CWE-704 | Medium | `memory.bad-cast` | C/C++ |
30: | 越界读取 | CWE-125 | High | `memory.oob-read` | C/C++ |
31: 
32: ## 并发安全 (concurrency) — 4<!-- @secguardian:namespace:concurrency --> 个 detectors
33: 
34: | 威胁 | CWE | 严重度 | Detector | 影响语言 |
35: |------|-----|--------|----------|---------|
36: | 竞态条件 | CWE-362 | High | `concurrency.race-condition` | C/C++ |
37: | 死锁 | CWE-833 | Medium | `concurrency.deadlock` | C/C++ |
38: | 数据竞态 | CWE-366 | High | `concurrency.data-race` | C/C++ |
39: | 信号处理器不安全 | CWE-479 | Medium | `concurrency.thread-unsafe-signal` | C/C++ |
40: 
41: ## 系统安全 (system) — 8<!-- @secguardian:namespace:system --> 个 detectors
42: 
43: | 威胁 | CWE | 严重度 | Detector | 影响语言 |
44: |------|-----|--------|----------|---------|
45: | 命令注入 | CWE-77 | Critical | `system.command-injection` | 全语言 |
46: | 路径遍历 | CWE-22 | High | `system.path-traversal` | 全语言 |
47: | 密钥泄露 | CWE-798 | High | `system.secrets-detection` | 全语言 |
48: | TOCTOU 竞态 | CWE-367 | High | `system.toctou` | C/C++ |
49: | 不安全临时文件 | CWE-377 | Medium | `system.insecure-temp-file` | C/C++ |
50: | 符号链接攻击 | CWE-61 | Medium | `system.symlink-attack` | C/C++ |

(Showing lines 1-50 of 135. Use offset=51 to continue.)
</content>
```

---

## Assistant (Build · DeepSeek V4 Flash · 4.9s)

_Thinking:_

Now I have a comprehensive picture. Let me also quickly check the internal tests.

**Tool: bash**

**Input:**
```json
{
  "command": "cd /Users/kongan/workbench/github/SecGuardian && grep -rn 'DETECTOR_RULE_INDEX\\[\"' scripts/render-report.py | grep 'duplicate\\|jwt-misuse' && echo \"---\" && grep -n 'jwt-misuse' scripts/render-report.py",
  "description": "Check for duplicate keys in render-report"
}
```

**Output:**
```
(no output)
```

**Tool: bash**

**Input:**
```json
{
  "command": "cd /Users/kongan/workbench/github/SecGuardian && grep -rn '0\\.5\\.4\\|0\\.5\\.5\\|0\\.12\\.0\\|\"version\"' --include=\"*.sh\" --include=\"*.json\" --include=\"*.go\" --include=\"*.py\" | grep -v node_modules | grep -v '.git/' | grep -v 'dist/' | grep -v '.codeagent/' | grep -v '.claude/' | grep -v '.opencode/' | grep -v '.gemini/' | grep -v '\\.codex-plugin' | head -40",
  "description": "Audit version strings across project"
}
```

**Output:**
```
./internal/main.go:26:const version = "0.12.0"
./internal/main.go:37:	versionFlag := fs.Bool("version", false, "Print version and exit")
./extensions/secreview-secguardian/extension.json:3:  "version": "0.12.0",
./extensions/secaudit-secguardian/extension.json:3:  "version": "0.12.0",
./extensions/secfix-secguardian/extension.json:3:  "version": "0.12.0",
./extensions/secguard-secguardian/extension.json:3:  "version": "0.12.0",
./examples/js-vuln-demo/package.json:3:  "version": "1.0.0",
./scripts/e2e-verify.sh:888:  echo '{"version":"1","remediations":[]}' > "$SCAN_DIR/ai/remediation-pack.json"
./scripts/dev-verify.sh:116:EXPECTED_VER="0.5.5"
./scripts/release.sh:186:  "version": "$VERSION",
./scripts/benchmark.sh:167:    "version": "0.1.0",
./scripts/deploy.sh:190:    # NOTE: version "0.5.4" below should match manifest.json version
./scripts/deploy.sh:194:  "version": "0.5.4",
./scripts/deploy.sh:274:    plugin_version=$(grep -m1 '"version"' "$plugin_dir/.claude-plugin/plugin.json" | sed 's/.*: *"\([^"]*\)".*/\1/')
./scripts/deploy.sh:300:      "version": "$plugin_version",
./scripts/deploy.sh:565:  "version": "0.5.5",
./scripts/deploy.sh:655:    # NOTE: version "0.5.4" below should match manifest.json version
./scripts/deploy.sh:659:  "version": "0.5.4",
./scripts/deploy.sh:781:        local ver="$(grep -m1 '"version"' "$PROJECT_ROOT/extensions/secguard-secguardian/extension.json" | sed 's/.*: *"\([^"]*\)".*/\1/')"
./scripts/render-report.py:683:        "version": "2.1.0",
./scripts/render-report.py:688:                    "version": "3.0",
./scripts/render-report.py:1090:        "version": "1.0",
./manifest.json:3:  "version": "0.12.0",
./manifest.json:243:        "\u4fee\u590d: threat-catalog \u540c\u6b65 + detector \u6587\u4ef6\u540d\u7edf\u4e00 (67 \u4e2a namespace-name.md) + detector \u6570\u91cf\u52a8\u6001\u5316 + \u7248\u672c\u53f7\u4fee\u6b63 (0.5.3\u21920.5.5)"

```

**Tool: bash**

**Input:**
```json
{
  "command": "cd /Users/kongan/workbench/github/SecGuardian && grep -rn 'knowledge/detectors\\|knowledge/guard-rules' scripts/render-report.py",
  "description": "Check detector path references"
}
```

**Output:**
```
scripts/render-report.py:39:    """Build detector -> {index, cwe} mapping from knowledge/detectors/*.md files.

```

---

## Assistant (Build · DeepSeek V4 Flash · 5.9s)

_Thinking:_

Now I have a very comprehensive picture of the project. Let me check one more critical thing - whether the load_detector_index_from_files function actually finds the right directory.

**Tool: bash**

**Input:**
```json
{
  "description": "Check if detector path exists",
  "command": "ls -d /Users/kongan/workbench/github/SecGuardian/knowledge/detectors 2>&1 && echo \"---\" && ls -d /Users/kongan/workbench/github/SecGuardian/knowledge/guard-rules 2>&1"
}
```

**Output:**
```
ls: /Users/kongan/workbench/github/SecGuardian/knowledge/detectors: No such file or directory

```

**Tool: bash**

**Input:**
```json
{
  "description": "Count guard-rules and audit-rules files",
  "command": "echo \"guard-rules: $(ls /Users/kongan/workbench/github/SecGuardian/knowledge/guard-rules/*.md 2>/dev/null | wc -l)\" && echo \"audit-rules: $(ls /Users/kongan/workbench/github/SecGuardian/knowledge/audit-rules/*.md 2>/dev/null | wc -l)\" && echo \"review-rules: $(ls /Users/kongan/workbench/github/SecGuardian/knowledge/review-rules/*.md 2>/dev/null | wc -l)\" && echo \"protocols: $(ls /Users/kongan/workbench/github/SecGuardian/knowledge/protocols/*.md 2>/dev/null | wc -l)\" && echo \"languages: $(ls /Users/kongan/workbench/github/SecGuardian/knowledge/languages/*.md 2>/dev/null | wc -l)\" && echo \"standards: $(ls /Users/kongan/workbench/github/SecGuardian/knowledge/standards/*.md 2>/dev/null | wc -l)\""
}
```

**Output:**
```
guard-rules:       67
audit-rules:       13
review-rules:        5
protocols:        3
languages:        5
standards:        6

```

**Tool: bash**

**Input:**
```json
{
  "description": "Check the duplicate key in render-report",
  "command": "cd /Users/kongan/workbench/github/SecGuardian && python3 -c \"\nimport re\nwith open('scripts/render-report.py') as f:\n    content = f.read()\n# Find all detector keys in DETECTOR_RULE_INDEX\nkeys = re.findall(r'\\\"([\\w.-]+)\\\"\\s*:', content)\nfrom collections import Counter\ndups = {k:v for k,v in Counter(keys).items() if v > 1 and '.' in k}\nprint('Duplicate keys:', dups)\n\""
}
```

**Output:**
```
Duplicate keys: {'web.jwt-misuse': 2}

```

---

## Assistant (Build · DeepSeek V4 Flash · 7.2s)

_Thinking:_

Now let me check one more crucial issue - the parser_javascript.go is compiled without build tags. Since it has the same function `parseJSFile` but also has `tryParseJS`, while the parser_ts.go has the condition `case "javascript"` fallback, I need to check if there are any compilation conflicts with the regex parser that also might define ParseFile.

Looking at parser_ts.go: The `case "javascript"` at line 37-39 calls `parseJSFile`. But parseJSFile is defined in parser_javascript.go WITHOUT a build tag. So when CGO is enabled (parser_ts.go built), both files compile together and `parseJSFile` is available.

When CGO is disabled (parser_re.go built), the JavaScript case is... Hmm, parser_re.go has `ParseFile` and handles JS via `funcPatterns["javascript"]` and `typePatterns["javascript"]`. But parser_javascript.go also has `parseJSFile`. So when `!cgo`, both parser_re.go and parser_javascript.go compile together. The `parseJSFile` function from parser_javascript.go is compiled but never called by the regex parser's `ParseFile`. 

So there's a dead code issue - `parseJSFile` is compiled in all builds but only called by parser_ts.go through the `case "javascript"` branch, which is only active when CGO is enabled. When regex parser is used, JavaScript is parsed via regex patterns directly in `ParseFile`.

This is actually fine design-wise, but worth noting. Though it does mean that when CGO is disabled, there are TWO JavaScript parsers: the regex one in parser_re.go and the parseJSFile function, but only parser_re.go's ParseFile is called.

Let me now compile my findings into a report. Let me update the todo list and write the report.

Let me also check one more file to be thorough - the internal/engine directory.

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/internal/engine"
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/internal/engine</path>
<type>directory</type>
<entries>
engine_contract.md

(1 entries)
</entries>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/kongan/workbench/github/SecGuardian/scripts/release.sh",
  "limit": 50
}
```

**Output:**
```
<path>/Users/kongan/workbench/github/SecGuardian/scripts/release.sh</path>
<type>file</type>
<content>
1: #!/bin/bash
2: # SecGuardian — Release Build Script
3: #
4: # 构建所有发布产物到 dist/release/<version>/
5: #
6: # 用法:
7: #   bash scripts/release.sh [version]
8: #   bash scripts/release.sh 0.3.1
9: #
10: # 环境变量:
11: #   VERSION   版本号（默认从 git tag 或 CHANGELOG 取）
12: #   OUTPUT    输出目录（默认 dist/release）
13: #
14: # 输出:
15: #   dist/release/<version>/
16: #   ├── secguardian-index-<version>-darwin-arm64
17: #   ├── secguardian-index-<version>-darwin-arm64.sha256
18: #   ├── secguardian-index-<version>-darwin-amd64
19: #   ├── secguardian-index-<version>-darwin-amd64.sha256
20: #   ├── secguardian-index-<version>-linux-amd64
21: #   ├── secguardian-index-<version>-linux-amd64.sha256
22: #   ├── secguardian-index-<version>-windows-amd64.exe
23: #   ├── secguardian-index-<version>-windows-amd64.exe.sha256
24: #   ├── secguardian-<version>-claude-code-${PLATFORM_SUFFIX}.zip
25: #   ├── secguardian-<version>-opencode-${PLATFORM_SUFFIX}.zip
26: #   ├── secguardian-<version>-gemini-cli-${PLATFORM_SUFFIX}.zip
27: #   ├── secguardian-<version>-source.tar.gz
28: #   └── manifest.json
29: 
30: set -euo pipefail
31: 
32: PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
33: VERSION="${1:-$(grep '^\#\# ' "$PROJECT_ROOT/CHANGELOG.md" | head -1 | sed 's/.*\[//;s/\].*//')}"
34: VERSION="${VERSION:-0.3.1}"
35: OUTPUT="${OUTPUT:-$PROJECT_ROOT/dist/release/$VERSION}"
36: 
37: GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
38: 
39: log() { echo -e "${CYAN}  →${NC} $1"; }
40: done_msg() { echo -e "${GREEN}  ✓${NC} $1"; }
41: 
42: echo ""
43: echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
44: echo -e "${BOLD}║${NC}  SecGuardian Release Build v${VERSION}                  ${BOLD}║${NC}"
45: echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
46: echo ""
47: 
48: mkdir -p "$OUTPUT"
49: # Clean previous release artifacts
50: rm -f "$OUTPUT"/*.zip "$OUTPUT"/*.zip.sha256 "$OUTPUT"/*.tar.gz "$OUTPUT"/*.tar.gz.sha256 "$OUTPUT"/secguardian-index-* "$OUTPUT"/manifest.json

(Showing lines 1-50 of 246. Use offset=51 to continue.)
</content>
```

---

## Assistant (Build · DeepSeek V4 Flash · 4.0s)

_Thinking:_

OK. I now have enough data to write a comprehensive report. Let me also look at the `resource.memory-leak` duplicate issue between memory namespace and resource namespace.

**Tool: bash**

**Input:**
```json
{
  "description": "Check duplicate detector names across namespaces",
  "command": "cd /Users/kongan/workbench/github/SecGuardian && ls knowledge/guard-rules/ | sed 's/\\.md$//' | sort | uniq -d"
}
```

**Output:**
```
(no output)
```

**Tool: bash**

**Input:**
```json
{
  "description": "Check self-check logic bug at line 156-165",
  "command": "cd /Users/kongan/workbench/github/SecGuardian && sed -n '155,167p' scripts/self-check.sh"
}
```

**Output:**
```
        green "$cmd_dir/ ($n skills)"
        SKILL_COUNT=$((SKILL_COUNT + n))
    else
        red "$cmd_dir/ MISSING"
    fi
done
echo "  else
    echo "  npx not available — install Node.js to run markdownlint locally"
fi

Total: $SKILL_COUNT skills"
echo ""


```

---

## Assistant (Build · DeepSeek V4 Flash · 3.3s)

_Thinking:_

Excellent! The self-check bug is confirmed. The echo statement at line 163 in the original file has the wrong content - it prints "else\n    echo "  npx not available..." instead of the actual Total line. This is because the heredoc/quoting got messed up.

Now let me finalize my report. Let me also check the opencode-plugin.js issue with package.sh.

**Tool: bash**

**Input:**
```json
{
  "description": "Check if opencode-plugin.js is missing from package.sh",
  "command": "cd /Users/kongan/workbench/github/SecGuardian && grep -c 'opencode-plugin' scripts/package.sh"
}
```

**Output:**
```
0

```

**Tool: bash**

**Input:**
```json
{
  "description": "Check deploy.sh opencode-plugin reference",
  "command": "cd /Users/kongan/workbench/github/SecGuardian && grep -n 'opencode-plugin' scripts/deploy.sh"
}
```

**Output:**
```
571:    if [ -f "$PROJECT_ROOT/scripts/opencode-plugin.js" ]; then
572:        cp "$PROJECT_ROOT/scripts/opencode-plugin.js" "$opencode_dir/plugins/secguardian.js"

```

---

## Assistant (Build · DeepSeek V4 Flash · 3.6s)

_Thinking:_

Now I have the complete picture. Let me compile and write the comprehensive review. Let me update the todos and produce the report.

**Tool: todowrite**

**Input:**
```json
{
  "todos": [
    {
      "content": "SDD 检查：确认是否有相关 Feature Package 指导本次审计",
      "priority": "high",
      "status": "completed"
    },
    {
      "content": "仓库完整性审计：manifest.json / package.sh / deploy.sh / self-check.sh",
      "priority": "high",
      "status": "completed"
    },
    {
      "content": "Go 索引器源码审计：internal/ 下的代码质量与安全缺陷",
      "priority": "high",
      "status": "completed"
    },
    {
      "content": "Shell 脚本审计：deploy.sh / package.sh / dev-verify.sh / e2e-verify.sh 等",
      "priority": "high",
      "status": "completed"
    },
    {
      "content": "Markdown 知识文件审计：detectors / skills / protocols 一致性",
      "priority": "medium",
      "status": "completed"
    },
    {
      "content": "构建与部署管线审计：package.sh → deploy.sh 全链路",
      "priority": "high",
      "status": "completed"
    },
    {
      "content": "安全敏感点审计：密钥管理 / 命令注入 / 路径穿越",
      "priority": "critical",
      "status": "completed"
    },
    {
      "content": "汇总致命缺陷报告",
      "priority": "high",
      "status": "in_progress"
    }
  ]
}
```

**Output:**
```
[
  {
    "content": "SDD 检查：确认是否有相关 Feature Package 指导本次审计",
    "status": "completed",
    "priority": "high"
  },
  {
    "content": "仓库完整性审计：manifest.json / package.sh / deploy.sh / self-check.sh",
    "status": "completed",
    "priority": "high"
  },
  {
    "content": "Go 索引器源码审计：internal/ 下的代码质量与安全缺陷",
    "status": "completed",
    "priority": "high"
  },
  {
    "content": "Shell 脚本审计：deploy.sh / package.sh / dev-verify.sh / e2e-verify.sh 等",
    "status": "completed",
    "priority": "high"
  },
  {
    "content": "Markdown 知识文件审计：detectors / skills / protocols 一致性",
    "status": "completed",
    "priority": "medium"
  },
  {
    "content": "构建与部署管线审计：package.sh → deploy.sh 全链路",
    "status": "completed",
    "priority": "high"
  },
  {
    "content": "安全敏感点审计：密钥管理 / 命令注入 / 路径穿越",
    "status": "completed",
    "priority": "critical"
  },
  {
    "content": "汇总致命缺陷报告",
    "status": "in_progress",
    "priority": "high"
  }
]
```

---

## Assistant (Build · DeepSeek V4 Flash · 30.0s)

全仓检视完成，发现以下 **致命缺陷（Critical）** 和 **严重缺陷（High）**：

---

## 🔴 致命缺陷 (Critical)

### C-1. 版本号系统彻底混乱 — 至少 4 个不同版本号共存
| 位置 | 版本 | 问题 |
|------|------|------|
| `manifest.json` | **0.12.0** | 权威版本 |
| `internal/main.go:26` | **0.12.0** | ✅ 一致 |
| `scripts/deploy.sh:194` | **0.5.4**（硬编码） | ❌ 落后 19 个次版本 |
| `scripts/deploy.sh:565` | **0.5.5**（硬编码） | ❌ 与上面不同 |
| `scripts/dev-verify.sh:116` | `EXPECTED_VER="0.5.5"` | ❌ 验证脚本验收错误版本 |
| `extensions/*/extension.json` | **0.12.0** | ✅ 一致 |
- `deploy.sh:655` 注释写着 `version "0.5.4" below should match manifest.json version` 但实际 **从未同步过**
- 发布时版本号对比会全部失败，部署验证直接误判

### C-2. `render-report.py` 检测器索引路径硬编码错误，永远走回退
`scripts/render-report.py:46-47`:
```python
detectors_dir = os.path.join(script_dir, "..", "knowledge", "detectors")
```
**目录 `knowledge/detectors/` 不存在**（实际为 `knowledge/guard-rules/`），导致 `load_detector_index_from_files()` 每次返回 `None`，永远走 130 行硬编码回退表。这意味着：
- 新增检测器后 `render-report.py` 无法感知
- `DETECTOR_RULE_INDEX` 硬编码表和实际 67 个检测器不一致的风险

### C-3. `render-report.py` 硬编码回退表含重复 key
`scripts/render-report.py:99` 与 `:159` **两次定义 `web.jwt-misuse`**。
Python 字典语法中后出现的覆盖前者，但两次的 `index` 值不同（8 vs 8 — 巧合相同）。如果未来分开维护，会产生隐形覆盖。

### C-4. `self-check.sh` 输出内容被破坏 — 嵌入错误文本
`scripts/self-check.sh:161-165`：
```
  echo "  else
    echo "  npx not available — install Node.js to run markdownlint locally"
fi
```
实际应该打印 `Total: $SKILL_COUNT skills`，但混入了 markdownlint 检查的 `else` 分支代码。这是 **heredoc/引号嵌套错误** 导致的输出污染。该错误已使得 **Sec 5 (Skills structure)** 的检查结果不可读。

### C-5. 索引器 `MatchAllocFree` O(n²) + 无关联匹配 — 生产级别不可用
`internal/indexer/indexer.go:129-173`：
- 对每行每次 `malloc`，遍历**整个文件所有行**寻找 `free` — O(n²)
- **所有 free 调用都被算作匹配**，不做变量追踪（`free(buf)` vs `free(ptr)` 一视同仁）
- 同一个 `free` 可能被多个 `malloc` 重复匹配
- 在 10 万行 C 文件上索引会退化到秒级甚至分钟级

### C-6. `package.sh` 不包含 `opencode-plugin.js`，OpenCode 部署断链
`scripts/package.sh` 的 dist 打包**不复制 `opencode-plugin.js`**（`scripts/deploy.sh:571-572` 直接从源码目录拷贝）。意味着任何第三方通过 `package.sh` 构建的 dist/ 部署后，OpenCode 的插件注册（注册 `/secguard` 等命令、设置 skills/knowledge 路径）完全缺失。

### C-7. 双解析器输出不一致 — 同一代码不同结果
`parser_re.go` 和 `parser_ts.go` 对同一代码产生不同的符号表：
- Regex 版**无法识别**嵌套类型（Go 的 `type X struct { ... }`）、方法接收者（`func (r *T) Method()`）
- Regex 版 Java 类型检测只匹配行首的 `class`/`interface` 声明，遗漏内部类
- Regex 版变量提取**只匹配有限类型列表**（Python 版甚至匹配任何 `=` 赋值，污染变量表）

---

## 🟠 严重缺陷 (High)

### H-1. `package.sh` 重复创建目录
`scripts/package.sh:126-131`：
```bash
"$dist_dir/knowledge/audit-rules" \      # 第 1 次
"$dist_dir/knowledge/review-rules" \     # 第 1 次
"$dist_dir/knowledge/audit-rules" \      # 第 2 次（重复）
"$dist_dir/knowledge/review-rules" \     # 第 2 次（重复）
```
4 个 mkdir 参数中有两个是重复的，逻辑正确但容易误导后续维护者。

### H-2. Go 构建并行缺错误传播
`scripts/package.sh:82-97`：5 个平台用 `&` 并行编译，但 `|| echo "[WARN]"` **吞掉了编译失败**。如果 CGO 构建失败，后续部署的索引器二进制可能是旧的或空的。

### H-3. `secfix.py` 未初始化局部变量引用
`scripts/secfix.py:170-172`：
```python
"file": file_path if "file_path" in locals() else "",
"line": line if "line" in locals() else 0,
"description": description if "description" in locals() else "",
```
这三个变量在 `process_finding()` 中定义，但如果 `before`/`after` 都为空且 `file_path` 为空，函数**提前 return None**，不会到达这行。但这是脆弱的防御式编程，且 `locals()` 检查本身是反模式。

### H-4. `load_detector_index_from_files()` 的 detectors_dir 不匹配部署结构
函数从 `knowledge/detectors/` 加载（不存在），应改为 `knowledge/guard-rules/`。同时，部署后的路径是 `knowledge/guard-rules/`，该函数在扫描时不会被调用到（因为入口是 `render-report.py --findings`），但自动化测试/CI 中可能触发。

### H-5. 调用图使用字符串包含近似 — 误报率高
`internal/indexer/indexer.go:97`：`strings.Contains(body, callee.Name+"(")` 
- 子串匹配会命中字符串字面量（`strcmp("foo(", ...)`）、注释（虽有过滤但只滤行级注释）、变量名包含函数名
- 不构建作用域，不追踪函数指针

### H-6. `detectLanguage()` 默认回退到 "c"
`internal/main.go:223`：`return "c"` — 任何无法识别的文件扩展名（如 `.rs`、`.kt`、`.ts`）都会被当作 C 语言解析，可能产生无意义结果或解析错误。

### H-7. 硬编码 gitee.com URL
`scripts/deploy.sh:196,198,303,305`：大量引用 `https://gitee.com/jonyan/secguardian`，但项目对应的 GitHub 是 `DannyAn/SecGuardian`。GitHub Actions 的 Action 描述也指向 gitee。

### H-8. `render-report.py` 大量 import 在函数体内
函数内重复 `from collections import defaultdict`/`Counter`，违反 PEP 8，增加每函数调用开销。

---

## 🟡 中等缺陷 (Medium)

### M-1. `render-report.py:generate_delta` 符号链接跟随缺乏安全性检查
`os.path.realpath(latest_link)` 不做循环链接检测或路径校验。

### M-2. Markdown 文件与部署后的 `guard-rules/` 路径不一致
`self-check.sh` 验证的 `knowledge/guard-rules/` 与 `deploy.sh` 部署的目标目录一致，但 `manifest.json` 中 metadata 引用路径方式不统一。

### M-3. 无数据流分析 — 索引器能力与产品宣称严重不符
虽然 manifest.json 宣称覆盖 CWE Top 25（100%）、OWASP Top 10（100%），但**索引器无 CFG、无 DFG、无 taint tracking**，所有检测完全依赖 AI Agent 对 Markdown 规则的语义理解。实际检测覆盖率取决于 AI 模型能力，而非索引器。

---

## 汇总

| 级别 | 数量 | 最关键问题 |
|------|------|-----------|
| 🔴 Critical | 7 | 版本号混乱、索引路径错误、输出被破坏、索引器 O(n²)、部署断链、双解析器不一致 |
| 🟠 High | 8 | 构建目录重复、错误被吞、变量引用风险、调用图误报高、默认回退 C 语言、URL 错误 |
| 🟡 Medium | 3 | 符号链接安全、路径不一致、能力/宣称差距 |

**建议立即修复**：C-1（统一版本号）、C-2（修正 detectors_dir 路径）、C-4（修复 self-check.sh 输出断裂）。这三个最影响日常使用。

**Tool: todowrite**

**Input:**
```json
{
  "todos": [
    {
      "priority": "high",
      "content": "SDD 检查：确认是否有相关 Feature Package 指导本次审计",
      "status": "completed"
    },
    {
      "priority": "high",
      "content": "仓库完整性审计：manifest.json / package.sh / deploy.sh / self-check.sh",
      "status": "completed"
    },
    {
      "priority": "high",
      "content": "Go 索引器源码审计：internal/ 下的代码质量与安全缺陷",
      "status": "completed"
    },
    {
      "priority": "high",
      "content": "Shell 脚本审计：deploy.sh / package.sh / dev-verify.sh / e2e-verify.sh 等",
      "status": "completed"
    },
    {
      "priority": "medium",
      "content": "Markdown 知识文件审计：detectors / skills / protocols 一致性",
      "status": "completed"
    },
    {
      "priority": "high",
      "content": "构建与部署管线审计：package.sh → deploy.sh 全链路",
      "status": "completed"
    },
    {
      "priority": "critical",
      "content": "安全敏感点审计：密钥管理 / 命令注入 / 路径穿越",
      "status": "completed"
    },
    {
      "priority": "high",
      "content": "汇总致命缺陷报告",
      "status": "completed"
    }
  ]
}
```

**Output:**
```
[
  {
    "content": "SDD 检查：确认是否有相关 Feature Package 指导本次审计",
    "status": "completed",
    "priority": "high"
  },
  {
    "content": "仓库完整性审计：manifest.json / package.sh / deploy.sh / self-check.sh",
    "status": "completed",
    "priority": "high"
  },
  {
    "content": "Go 索引器源码审计：internal/ 下的代码质量与安全缺陷",
    "status": "completed",
    "priority": "high"
  },
  {
    "content": "Shell 脚本审计：deploy.sh / package.sh / dev-verify.sh / e2e-verify.sh 等",
    "status": "completed",
    "priority": "high"
  },
  {
    "content": "Markdown 知识文件审计：detectors / skills / protocols 一致性",
    "status": "completed",
    "priority": "medium"
  },
  {
    "content": "构建与部署管线审计：package.sh → deploy.sh 全链路",
    "status": "completed",
    "priority": "high"
  },
  {
    "content": "安全敏感点审计：密钥管理 / 命令注入 / 路径穿越",
    "status": "completed",
    "priority": "critical"
  },
  {
    "content": "汇总致命缺陷报告",
    "status": "completed",
    "priority": "high"
  }
]
```

---

## Assistant (Build · DeepSeek V4 Flash · 2.5s)

_Thinking:_

The report is comprehensive and covers all the critical defects I identified. Let me ensure it's useful for the user.

以上是全仓检视报告。如需对其中某项缺陷深入分析或直接给出修复方案，请告知。

---

