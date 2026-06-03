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

遵循 [Scan Output Protocol 2.0](../knowledge/protocols/scan-output.md)。人读/机读分离。

```
.codeagent/secaudit-secguardian/scans/<scan-id>/
├── report.md               # ★ 人读审计报告 (Markdown)
├── results.sarif            # 机读: SARIF 2.1.0 (CI/CD)
├── summary.json             # 仪表盘统计
├── manifest.json            # 审计元数据 + 发现索引
├── status.json              # CI 门禁
└── delta.json               # 增量对比 (vs 上次扫描)
```

**执行完毕后必须输出审计摘要：**

```
## secaudit 审计完成 — taint-analysis

Scan ID: sec-20260523-143000-b3c4
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

输出目录: .codeagent/secaudit-secguardian/scans/sec-20260523-143000-b3c4/
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

## 派发规则与执行步骤

> **隔离约束**: 本命令只能加载 `skills/` 扩展下的 `secaudit-*` 前缀 skill，禁止加载 `secguard-*` 或 `secreview-*` 前缀的任何文件。审计技能仅从 `skills/secaudit/{name}/SKILL.md` 路由。

你（AI Agent）在接收到 `/secaudit` 命令后，必须按以下步骤执行来构建索引并进行安全审计。

### 前置检查（Pre-flight Checklist）

在执行任何审计步骤之前，必须逐项确认以下所有条件。**任一项未通过，审计不得开始，向用户报告具体错误。**

- [ ] 定位索引器 wrapper：检查 `.opencode/plugins/secguardian/scripts/secguardian-index`、`.gemini/extensions/secguardian/scripts/secguardian-index`、`.claude/plugins/secguardian/scripts/secguardian-index`、`.claude/extensions/*/scripts/secguardian-index`，或 `scripts/secguardian-index`（至少一个存在且可执行）
- [ ] 执行 `{indexer} --health` 通过（输出必须包含 `HEALTH:OK` 或 `HEALTH:WARN`，不接受 `HEALTH:FAIL`）
- [ ] 目标路径 `<path>` 存在且包含至少一个源码文件

> 若未通过，报告具体哪一项失败并终止。不要降级为手工逐文件审计。

---

### Step 1: 建立输出目录

- 生成 `scan_id`（格式: `sec-YYYYMMDD-HHMMSS-xxxx`，其中 `xxxx` 为随机4位字符）。
- 创建输出目录: `.codeagent/secaudit-secguardian/scans/<scan_id>/findings/`。
- 记录审计开始时间戳，用于 Step 4 计算 `duration_ms`。

### Step 2: 构建语义索引（必须执行，不可跳过）

> ⚠️ 这是审计的**核心前置步骤**。索引器提供符号表、调用图、数据流路径，是后续深度审计的结构化上下文。**不执行此步骤将导致审计质量严重下降。**

**2a. 执行索引器（阻塞等待完成）：**

```bash
# 定位 wrapper（按优先级尝试）
INDEXER=""
for candidate in \
    .opencode/plugins/secguardian/scripts/secguardian-index \
    .gemini/extensions/secguardian/scripts/secguardian-index \
	    .claude/plugins/secguardian/scripts/secguardian-index \
    .claude/extensions/secaudit-secguardian/scripts/secguardian-index \
    .claude/extensions/secguard-secguardian/scripts/secguardian-index \
    .claude/extensions/secreview-secguardian/scripts/secguardian-index \
    scripts/secguardian-index \
    internal/secguardian-index; do
    if [ -x "$candidate" ] && [ -f "$candidate" ]; then
        INDEXER="$candidate"
        break
    fi
done

if [ -z "$INDEXER" ]; then
    echo "FATAL: secguardian-index not found" && exit 1
fi

$INDEXER --path <path> --output .codeagent/secaudit-secguardian/scans/<scan_id>/index.json
```

**2b. 验证索引完整性（必须通过）：**

```bash
python3 -c "
import json, sys
d = json.load(open('.codeagent/secaudit-secguardian/scans/<scan_id>/index.json'))
assert len(d.get('files',[])) > 0, 'FATAL: index contains no files'
assert 'symbols' in d, 'FATAL: index missing symbols'
print(f'Index OK: {len(d[\"files\"])} files, {len(d.get(\"symbols\",{}).get(\"functions\",[]))} functions, {len(d.get(\"call_graph\",{}).get(\"edges\",[]))} call edges')
"
```

若验证失败（返回非 0），**立即终止审计**并向用户报告索引生成出错。

**2c. 将 index.json 加载为上下文：**

读取生成的 `index.json`，理解以下结构化信息并在后续所有审计步骤中使用：
- `symbols.functions` — 函数名→文件:行号映射（定位审计目标）
- `call_graph.edges` — caller→callee 关系（追踪污点传播和数据流路径）
- `alloc_free.pairs` — 资源分配/释放配对（生命周期分析）
- `files` — 源码文件清单（确定审计范围）

### Step 3: 路由并应用 Audit Skill

- 如果用户未指定 skill-name，或输入为 `analysis` / `domain` / `list`，列出对应的 skills 列表。
- 如果指定了具体的 skill-name，精确加载 `../skills/secaudit/{skill-name}/SKILL.md`。
- 根据 `index.json` 提供的符号表和调用图、`SKILL.md` 的审计规范以及 `../knowledge/detectors/` 中相关检测器的威胁定义进行深度推理审计。


### Step 4: 保存检出并输出摘要

- 按照 `knowledge/protocols/scan-output.md` (v2.0) 写入 `report.md`（人读）+ `results.sarif`（机读）+ `manifest.json` + `summary.json` + `status.json`。
- `manifest.json` 中的 `duration_ms` 必须使用 **实际 wall-clock 耗时**（结束时间戳 − 开始时间戳），不得编造。
- 向用户展示审计发现和审计摘要。
