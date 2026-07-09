# EPIC-009 — Implementation Plan

> **目标**: v0.19.0 — 从 Read-Driven 改造为 Protocol-Driven 检测引擎
> **方法**: TDD，每个 Task 先写测试后实现
> **依赖**: EPIC-007 (Signal Matrix) — call_sites/declarations 数据结构就位

---

## Phase 1: 索引器预筛器 (v0.19.0)

### 架构概览

```
main.go Phase 2.5 (新增):
  call_sites, declarations, ... → prescreener.Filter() → filtered_call_sites
                                                           ↓
                                                     index.json 只含 suspect+unknown
                                                     prescreener_audit 单独输出（可选）
```

### 接口设计

```go
// internal/indexer/prescreener.go

package indexer

// PrescreenVerdict 预筛裁定
type PrescreenVerdict int
const (
    VerdictUnknown PrescreenVerdict = iota  // 无法确定性判断，保留给 LLM
    VerdictSafe                              // 有足够证据安全，从 LLM 输入移除
)

type PrescreenResult struct {
    Callee  string          // 函数名
    File    string          // 源码文件
    Line    uint            // 行号
    Verdict PrescreenVerdict
    Reason  string          // 判定理由（如 "sizeof(dst)=64 matches char dst[64]"）
}

type PrescreenAudit struct {
    TotalSignals    int
    SafeCount       int
    UnknownCount    int
    SafeDetails     []PrescreenResult  // 每条 safe 信号的详情（用于--prescreen-audit输出）
    UnknownDetails  []PrescreenResult  // 每条 unknown 信号的详情
}

// PrescreenCallSites 对调用点列表执行预筛。
// 返回过滤后的调用点列表（仅 suspect+unknown）和审计信息。
// 入参 allSites 不会被修改。
func PrescreenCallSites(allSites []parser.CallSite, decls map[string]parser.Declaration) (filtered []parser.CallSite, audit PrescreenAudit)
```

### 实现路径

```
实现步骤（按文件）:
1. internal/indexer/prescreener_test.go  → TDD 测试（所有边界情况）
2. internal/indexer/prescreener.go       → prescreener 实现
3. internal/main.go                      → Phase 2.5 集成
4. internal/indexer/indexer.go           → 导出 PrescreenCallSites
```

---

### Task P1-T1: 预筛器测试（先写测试，后实现）

**文件**: `internal/indexer/prescreener_test.go`

测试用例矩阵（buffer_overflow 预筛规则）：

| # | 场景 | 输入特征 | 预期 | 说明 |
|---|------|---------|------|------|
| T1 | strcpy_s 正确 sizeof | `strcpy_s(dst, sizeof(dst), src)`, `char dst[64]` | VerdictSafe | 核心正向用例 |
| T2 | strcpy_s sizeof 不匹配 | `strcpy_s(dst, sizeof(dst), src)`, `char dst[128]` | VerdictUnknown | 大小不匹配 |
| T3 | strcpy_s 目标不在声明表 | `strcpy_s(ptr, size, src)` — ptr 是指针参数 | VerdictUnknown | 无法验证 |
| T4 | strcpy（unsafe 变体） | `strcpy(dst, src)`, `char dst[64]` | VerdictUnknown | unsafe 变体不放行 |
| T5 | strcpy_s 动态源 | `strcpy_s(dst, sizeof(dst), malloc(100))` | VerdictUnknown | 源是动态分配 |
| T6 | snprintf 正确 sizeof | `snprintf(buf, sizeof(buf), "%s", val)`, `char buf[256]` | VerdictSafe | 扩展规则 |
| T7 | memcpy_s 正确 sizeof | `memcpy_s(dst, sizeof(dst), src, n)`, `char dst[64]` | VerdictSafe | 类似安全变体 |
| T8 | memcpy 动态源大小 | `memcpy(dst, src, n)` | VerdictUnknown | unsafe 变体 |
| T9 | 空信号列表 | 空 `[]CallSite` | 空结果 | 边界 |
| T10 | 无声明 | 只有 CallSite，decls map 空 | 全 VerdictUnknown | 无声明可查 |
| T11 | gets_s 正确 sizeof | `gets_s(buf, sizeof(buf))`, `char buf[128]` | VerdictSafe | 安全变体 |
| T12 | 多信号混合 | 3 safe + 2 unknown | safe_count=3, len(filtered)=2 | 混合场景 |

**TDD 方式**：
1. 先写全部测试用例（预期全部失败/编译不过）
2. 实现 prescreener.go 到测试通过
3. 验证所有测试通过

**验证命令**：
```bash
cd internal && CGO_ENABLED=1 go test ./indexer/... -run TestPrescreen -v
```

---

### Task P1-T2: 预筛器实现

**文件**: `internal/indexer/prescreener.go`

**核心逻辑**：

```go
func PrescreenCallSites(allSites []parser.CallSite, symbols SymbolIndex) ([]parser.CallSite, PrescreenAudit) {
    // Step 1: 建立 declaration 查找映射（按函数+名字）
    // Step 2: 对每个 call_site 安全检查：
    //   2a 如果是 safe_variant (strcpy_s/strcat_s/...)
    //   2b 检查第一个参数是否为栈数组
    //   2c 检查 sizeof 参数是否等于 ArraySize
    //   2d 检查源是否为动态分配
    // Step 3: safe → 保留到 audit （从结果中移除）
    // Step 4: suspect/unknown → 保留在 filtered 列表中
}
```

在 prescreener_audit 输出模式下，还会打印：
```
PRESCREEN: safe 863/866 (99.6%), unknown 3/866 — 3 signals passed to LLM
PRESCREEN SAFE: strcpy_s(dst,sizeof(dst),src) at main.c:142 — char dst[64]
PRESCREEN SAFE: strcpy_s(buf,sizeof(buf),val) at net.c:55 — char buf[256]
PRESCREEN UNKNOWN: strcpy_s(ptr,size,src) at parser.c:88 — ptr not in declarations
...
```

**集成**：在 `main.go` 的 Phase 2.5 中外挂 prescreener：

```go
// Phase 2.5: Run prescreener
filtered, audit := indexer.PrescreenCallSites(allCallSites, symbols)
if audit.SafeCount > 0 {
    fmt.Printf("  Prescreener: %d safe filtered, %d remaining for LLM\n",
        audit.SafeCount, len(filtered))
}
allCallSites = filtered  // 只送筛选后的信号给 LLM
```

---

### Task P1-T3: demo 项目转换为 no-answers 格式

**涉及文件**: `examples/cpp-vuln-demo/src/`, `examples/java-vuln-demo/src/`, `examples/python-vuln-demo/src/`, `examples/go-vuln-demo/src/`, `examples/js-vuln-demo/src/`

逐一检查每个 demo 源文件，删除以下模式的注释行：
- `// VULNERABILITY [CWE-xxx]` / `# VULNERABILITY [CWE-xxx]`
- `// BAD:` / `# BAD:`
- `// TP-xx:` / `# TP-xx:` / `// P0-xx:` / `// P1-xx:`
- `// CWE-xxx: title`
- `// ← Detector 标记` / `// ← CWE-xxx`
- `// 真漏洞:` / `# 真漏洞:`

**不做**：不修改代码逻辑、不修改答案卡 JSON 文件（如果有）、不修改 README。

**验证**：
```bash
grep -rn "VULNERABILITY\|// BAD:\|# BAD:\|// TP-\|// P0-|// P1-\|真漏洞" examples/ | grep -v -f <(cat <<'EOF' 
\.json$
\.md$
EOF
)
# 期望: 0 匹配
```

---

### Task P1-T4: 删除 strip-answer-cards.py

**涉及文件**: 
- 删除 `scripts/strip-answer-cards.py`
- 从 `scripts/deploy.sh` 中移除其部署

**验证**：
```bash
ls scripts/strip-answer-cards.py 2>&1  # 期望: No such file or directory
```

---

### Task P1-T5: 协议中删除 stripped 引用（三命令）

**涉及文件**:
- `commands/opencode/secguard.md`
- `commands/claude/secguard.md`
- `commands/gemini/secguard.toml`
- 同上三个命令的 secaudit.md / secreview.md

**改动**:
1. 删除 Phase 1 中 strip-answer-cards.py 调用步骤
2. 删除 `$STRIPPED_DIR` / `$STRIPPED_ROOT` 变量
3. 删除 Worker 中从 stripped 目录读源码的约束
4. Worker 源码读取从 `$STRIPPED_DIR/src/file` 改为 `$SOURCE_ROOT/src/file`

**验证**：
```bash
grep -rn "stripped\|STRIPPED\|strip-answer-cards" commands/
# 期望: 0 匹配
```

---

### Task P1-T6: per_signal_analysis 协议注入

**涉及文件**:
- `commands/opencode/secguard.md` — 追加到 §5.3 blindspot schema
- `commands/claude/secguard.md` — 同
- `commands/gemini/secguard.toml` — 同

**内容**:
1. blindspot.json schema 新增 `per_signal_analysis` 数组
2. 追加约束："信号数 > 0 的 Batch 必须输出 per_signal_analysis，长度必须等于信号数"
3. Aggregator 协议新增：检查 per_signal_analysis 完整性
4. 追加 PB-04（禁止批量抑制）和 AC-03（判定矩阵为终止条件）到 Worker 执行协议

---

## Phase 2: 扩展预筛 + 架构约束 (v0.19.x)

### Task P2-T1: null_dereference prescreening（测试驱动）

**文件**: `internal/indexer/prescreener.go`（追加函数）

测试用例：

| # | 场景 | 特征 | 预期 |
|---|------|------|------|
| T1 | malloc + if(!ptr) return | `ptr=malloc(n); if(!ptr)return; ptr->f=1;` | VerdictSafe |
| T2 | malloc + if(ptr==NULL) return | 同上，不同写法 | VerdictSafe |
| T3 | malloc + assert(ptr) | `ptr=malloc(n); assert(ptr); ptr->f=1;` | VerdictUnknown (assert 不可靠) |
| T4 | malloc + 延迟检查 | `ptr=malloc(n); ptr->f=1; if(!ptr)return;` | VerdictUnknown |
| T5 | malloc + goto cleanup | `ptr=malloc(n); if(!ptr) goto cleanup;` | VerdictSafe |
| T6 | malloc 无检查 | `ptr=malloc(n); ptr->f=1;` | VerdictUnknown |

### Task P2-T2: double_free prescreening（测试驱动）

**文件**: `internal/indexer/prescreener.go`

测试用例：

| # | 场景 | 特征 | 预期 |
|---|------|------|------|
| T1 | free 后置 NULL | `free(ptr); ptr=NULL; free(ptr)` | VerdictSafe |
| T2 | free 后无置 NULL | `free(ptr); free(ptr)` | VerdictUnknown |
| T3 | free 后重新赋值 | `free(ptr); ptr=malloc(n); free(ptr)` | VerdictSafe |
| T4 | 不同变量 | `free(a); free(b)` | 不匹配此规则 |

### Task P2-T3: 架构约束文档 + AGENTS.md 注入

**文件**: `AGENTS.md`（追加 §架构约束 + §禁止行为）

### Task P2-T4: command_injection 0 信号调查与修复

调查 secfwd 源码中 system/exec/popen 的使用模式，修复 knownLibFuncs 匹配。

---

## 验证计划

### Phase 1 验证

```bash
# V-01: 预筛器单元测试
cd internal && CGO_ENABLED=1 go test ./indexer/... -run TestPrescreen -v

# V-02: 索引器编译
cd internal && CGO_ENABLED=1 go build -o /tmp/prescreen-test .

# V-03: 端到端预筛效果（demo 项目）
/tmp/prescreen-test --path ../examples/cpp-vuln-demo/src --output /tmp/cpp-prescreen.json
python3 -c "import json; d=json.load(open('/tmp/cpp-prescreen.json')); print(f'calls: {len(d.get(\"call_sites\",[]))}')"
# 期望: call_sites 数量少于原始（部分被预筛过滤）
# 请注意：cpp-vuln-demo 用的都是 unsafe 变体（strcpy/gets/malloc 无检查），
# 所以预筛可能很少过滤。这是正常的——demo 本身就是故意含漏洞的。
# 真正的验证在生产项目 secfwd。

# V-04: 生产项目验证
/tmp/prescreen-test --path /path/to/secfwd/src --output /tmp/secfwd-prescreen.json
python3 -c "
import json
d=json.load(open('/tmp/secfwd-prescreen.json'))
sites=d.get('call_sites',[])
cats={}
for s in sites:
    cats[s['callee']]=cats.get(s['callee'],0)+1
print(f'Total call_sites after prescreen: {len(sites)}')
for k,v in sorted(cats.items(),key=lambda x:-x[1])[:10]:
    print(f'  {k}: {v}')
"
# 期望: call_sites 从 866 大幅下降到 ~100

# V-05: demo 项目无答案卡
grep -rn "VULNERABILITY\|// BAD:\|# BAD:\|// TP-\|// P0-\|// P1-\|真漏洞" examples/ | grep -v '\.json' | grep -v '\.md'
# 期望: 0 匹配

# V-06: stripped 已删除
ls scripts/strip-answer-cards.py 2>&1 && echo "FAIL" || echo "OK"
grep -rn "stripped\|STRIPPED" commands/ && echo "FAIL" || echo "OK"

# V-07: 端到端 secguard 扫描
cd /path/to/cpp-vuln-demo
# 运行 secguard（模拟，需要实际 AI agent 执行）
# 验证：能检出漏洞（demo 的 unsafe 模式不受预筛影响）
```

### Phase 2 验证

```bash
# V-08: 预筛器扩展测试
cd internal && CGO_ENABLED=1 go test ./indexer/... -run TestPrescreen -v
# 覆盖 null_dereference + double_free 测试用例
```

---

## 任务执行顺序

```
P1-T1 (test) ──→ P1-T2 (impl) ──→ P1-T3 (demo) ──→ P1-T4 (delete)
                                                       │
                                                       ▼
                                              P1-T5 (protocol)
                                                       │
                                                       ▼
                                              P1-T6 (per_signal)
                                                       │
                                                       ▼
                                              Phase 1 验证

P2-T1 ──→ P2-T2 ──→ P2-T3 ──→ P2-T4 ──→ Phase 2 验证
```

依赖关系：
- P1-T2 阻塞在 P1-T1（TDD：先测试后实现）
- P1-T5/T6 阻塞在 P1-T4（删除 stripped 后才能清理协议）
- P2-T1/T2 阻塞在 P1-T2（预筛器框架就位后加新规则）
