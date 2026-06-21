# Detector Quality Enhancement — 实施计划

> **Feature**: FEATURE-002-detector-quality
> **Epic**: EPIC-001-core-scanning-engine
> **状态**: ✅ 已完成


**Goal:** Upgrade all 67 detectors in `knowledge/guard-rules/` to unified template with precision+confidence metadata, MUST/SHOULD/MAY evidence collection guides, FP exclusion tables with evidence binding, and MATCH/EXCLUDE pattern separation.

**Architecture:** 5 phases — schema update first (findings-schema.json), then 4 detector batches by quality/completeness (P0: 6 missing FP + evidence from scratch → P1: 13 content-light detectors <90 lines → P2: 28 medium quality → P3: 20 already well-formed requiring metadata upgrade only), with verification scans after each batch.

**Tech Stack:** Markdown (detector content) + JSON Schema (findings-schema.json) + Bash (verification scans)

---

## File Structure

```
knowledge/
├── protocols/
│   └── findings-schema.json          ← MODIFY: add call_stack, variable_state, sanitizer_analysis
└── detectors/
    ├── resource-socket-leak.md        ← P0: COMPLETE REWRITE
    ├── resource-lock-misuse.md        ← P0: COMPLETE REWRITE
    ├── resource-file-double-close.md  ← P0: COMPLETE REWRITE
    ├── resource-file-use-after-close.md ← P0: COMPLETE REWRITE
    ├── resource-refcount-misuse.md    ← P0: COMPLETE REWRITE
    ├── system-secrets-detection.md    ← P0: COMPLETE REWRITE
    ├── {13 P1 detectors}              ← P1: ENRICH (FP + evidence + patterns)
    ├── {28 P2 detectors}              ← P2: STANDARDIZE format + add evidence + FP binding
    └── {20 P3 detectors}              ← P3: METADATA UPGRADE only (precision + confidence)
examples/
    ├── cpp-vuln-demo/src/             ← VERIFICATION TARGET
    ├── python-vuln-demo/src/          ← VERIFICATION TARGET
    ├── java-vuln-demo/src/            ← VERIFICATION TARGET
    ├── go-vuln-demo/src/              ← VERIFICATION TARGET
    └── js-vuln-demo/src/              ← VERIFICATION TARGET
```

---

### Task 0: Update findings-schema.json with 3 new evidence sub-fields

**Files:**
- Modify: `knowledge/protocols/findings-schema.json:287` (after `data_flow_path` closing `}`)

**Purpose:** Add `call_stack`, `variable_state`, `sanitizer_analysis` to the `evidence` object so findings output can carry forensic evidence per the new template. Required BEFORE detector updates because detectors reference these schema fields.

- [ ] **Step 1: Add 3 new properties to evidence object**

Insert after line 287 (the closing `}` of `data_flow_path` property):

```json
,
            "call_stack": {
              "type": "array",
              "description": "📋 Evidence: Call chain from entry function to vulnerability location — for cross-function tracing",
              "items": {
                "type": "object",
                "required": ["function", "file", "line"],
                "properties": {
                  "function": {"type": "string", "description": "Function name"},
                  "file": {"type": "string", "description": "File path"},
                  "line": {"type": "integer", "description": "Line number in this function"},
                  "depth": {"type": "integer", "description": "Call depth (0 = entry point)"}
                }
              }
            },
            "variable_state": {
              "type": "object",
              "description": "📋 Evidence: Variable/value snapshot at vulnerability trigger point — for exploitability assessment",
              "properties": {
                "variable_name": {"type": "string", "description": "Variable name"},
                "inferred_value": {"type": "string", "description": "Inferred/possible value at trigger point"},
                "type": {"type": "string", "description": "Variable type"},
                "constraints": {"type": "string", "description": "Known constraints on the value"}
              }
            },
            "sanitizer_analysis": {
              "type": "object",
              "description": "📋 Evidence: Sanitizer presence and adequacy analysis — for FP elimination gate",
              "required": ["sanitizer_present", "verdict"],
              "properties": {
                "sanitizer_present": {"type": "boolean", "description": "Whether any sanitizer/validator exists on the data path"},
                "sanitizer_name": {"type": "string", "description": "Name of sanitizer function if present"},
                "bypass_reason": {"type": "string", "description": "Why the sanitizer is insufficient or can be bypassed"},
                "verdict": {
                  "type": "string",
                  "enum": ["no_sanitizer", "sanitizer_bypassed", "sanitizer_insufficient", "sanitizer_adequate"],
                  "description": "Final verdict on sanitizer adequacy"
                }
              }
            }
```

- [ ] **Step 2: Validate JSON schema**

```bash
python3 -c "import json; json.load(open('knowledge/protocols/findings-schema.json')); print('VALID JSON')"
```
Expected: `VALID JSON`

- [ ] **Step 3: Commit**

```bash
git add knowledge/protocols/findings-schema.json
git commit -m "feat(schema): add call_stack, variable_state, sanitizer_analysis to evidence

Add 3 new forensic evidence sub-fields to Finding.evidence:
- call_stack: cross-function call chain with depth tracking
- variable_state: variable value/type/constraint snapshot at trigger point
- sanitizer_analysis: sanitizer presence + bypass/adequacy verdict

Part of detector FP elimination + evidence enhancement (Phase 0).

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 1: P0 Batch — Complete Rebuild (6 detectors)

**Files:**
- Rewrite: `knowledge/guard-rules/resource-socket-leak.md`
- Rewrite: `knowledge/guard-rules/resource-lock-misuse.md`
- Rewrite: `knowledge/guard-rules/resource-file-double-close.md`
- Rewrite: `knowledge/guard-rules/resource-file-use-after-close.md`
- Rewrite: `knowledge/guard-rules/resource-refcount-misuse.md`
- Rewrite: `knowledge/guard-rules/system-secrets-detection.md`

**Purpose:** These 6 detectors completely lack FP exclusion sections and evidence collection. Rebuild from current content into full unified template.

**Template reference:** `resource-socket-leak.md` already designed and approved in spec (see design doc Appendix for full before/after).

**Each detector must satisfy these exit criteria:**

| Criterion | Threshold |
|-----------|-----------|
| 7 standard chapters present | All: 威胁定义 + 检测逻辑 + 证据收集指引 + 误报排除 + 修复指引 + 检测模式汇总 |
| MUST evidence items | ≥2 |
| SHOULD evidence items | ≥2 |
| FP exclusion rows | ≥3 |
| MATCH patterns with evidence anchors | ≥1 |
| EXCLUDE patterns | ≥2 |
| precision metadata | Assigned per vulnerability class |
| confidence metadata | `dynamic` |

**Evidence collection section template (insert after 检测逻辑, before 误报排除):**

```markdown
## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：[具体说明要截取的代码范围]
      → findings.evidence.code_context
- [ ] **judgment_rationale**：[具体说明判定依据需包含什么关键信息]
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：[适用的数据流追踪范围，若单点漏洞标注 'N/A']
      → findings.evidence.data_flow_path
- [ ] **call_stack**：[跨函数追踪范围]
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：[关键变量及状态]
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：[消毒/防护机制存在性分析]
      → findings.evidence.sanitizer_analysis
```

**FP exclusion table format (insert after 证据收集指引, before 修复指引):**

```markdown
## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
```

**Detection pattern format (final chapter):**

```markdown
## 检测模式汇总 (Detection Pattern Summary)

# === MATCH (触发检测) ===
<pattern>                        # → MUST: <evidence item>
                                 # → SHOULD: <evidence item>

# === EXCLUDE (不报告) ===
→ <condition>                    # <排除依据简述>
```

- [ ] **Step 1: Rebuild resource-socket-leak.md**

Read current `knowledge/guard-rules/resource-socket-leak.md`, transform to unified template with:
- precision: `high`
- confidence: `dynamic`
- MUST evidence: code_context (完整函数体 + 退出路径标注), judgment_rationale (具体缺失 close 的路径)
- SHOULD evidence: data_flow_path (fd 创建→使用→退出), call_stack (跨函数 fd 传递)
- MAY evidence: variable_state (fd 值), 进程生命周期分析
- FP exclusions: ≥7 items (所有权移交, 资源池, goto cleanup, fd<0, 短生命周期, 宏内 close, stdin/stdout/stderr)
- MATCH: socket(), accept()
- EXCLUDE: close() 所有路径覆盖, return fd, 全局存储+释放函数, fd<0, 测试文件, 短生命周期

```bash
# After writing, verify chapter count:
grep -c "^## " knowledge/guard-rules/resource-socket-leak.md
# Expected: ≥6
```

- [ ] **Step 2: Rebuild resource-lock-misuse.md**

Current: 52 lines, 5 sections, no FP exclusion. Precision: `high`. CWE-667.

MUST evidence: code_context (lock/unlock 配对 + 所有退出路径), judgment_rationale (具体哪条路径缺少 unlock)
SHOULD evidence: data_flow_path (mutex 获取→使用→释放), call_stack (若锁跨函数传递)
FP exclusions: ≥4 items (goto cleanup 统一释放, RAII lock_guard, 递归锁, trylock 非阻塞模式)
MATCH: pthread_mutex_lock 后无对应 unlock, 连续两次 lock
EXCLUDE: 所有路径都有 unlock, RAII scope guard, recursive mutex, test files

- [ ] **Step 3: Rebuild resource-file-double-close.md**

Current: 49 lines, 5 sections, no FP exclusion. Precision: `high`. CWE-675.

MUST evidence: code_context (fd 变量 + 两次 close 的位置), judgment_rationale (两次 close 的行号与 fd 值)
SHOULD evidence: data_flow_path (fd 创建→第一次 close→第二次 close), call_stack (若跨函数)
FP exclusions: ≥3 items (fd 重新赋值不同值, close 后立即设 -1, 不同分支分别 close 不同 fd)
MATCH: 同一 fd 变量出现两次 close()
EXCLUDE: fd=-1 检查后再 close, 不同分支不同 fd, test files

- [ ] **Step 4: Rebuild resource-file-use-after-close.md**

Current: 45 lines, 5 sections, no FP exclusion. Precision: `very-high`. CWE-672.

MUST evidence: code_context (close(fd) 位置 + 之后使用 fd 的位置), judgment_rationale (操作类型：read/write/ioctl after close)
SHOULD evidence: data_flow_path (fd→close→use 全路径)
FP exclusions: ≥3 items (dup 后的新 fd, close 后立即 return, fd 重新 open 新值)
MATCH: close(fd) 之后出现 read/write/ioctl/... 同 fd
EXCLUDE: close 后 fd 重新赋值, dup fd 使用新变量, fd 仅在 close 后用于 NULL 检查, test files

- [ ] **Step 5: Rebuild resource-refcount-misuse.md**

Current: 62 lines, 5 sections, no FP exclusion. Precision: `medium`. CWE-911.

MUST evidence: code_context (refcount inc/dec 配对 + 所有路径), judgment_rationale (哪条路径 inc 但未 dec，或 dec 未 inc)
SHOULD evidence: data_flow_path (refcount 操作序列)
FP exclusions: ≥3 items (RAII ref-counted pointer, 单线程无并发 refcount, 初始化 refcount=1 后仅 dec)
MATCH: inc/dec 配对不完整, dec 多于 inc
EXCLUDE: RAII wrapper, atomic refcount, test files

- [ ] **Step 6: Rebuild system-secrets-detection.md**

Current: 74 lines, 3 sections, no FP exclusion. Precision: `low` (高熵检测天然高误报). CWE-798.

This detector is special — it's primarily regex-based high-entropy scanning, not semantic analysis. Evidence should focus on regex match context and exclusion justification.

MUST evidence: code_context (匹配行 + 前后 3 行上下文), judgment_rationale (匹配的正则模式 + 密钥类型)
SHOULD evidence: sanitizer_analysis (是否为模板变量、配置文件模板、测试数据)
FP exclusions: ≥5 items (public certificate PEM, base64 image/font, template variable, test prefix, 全零占位符, .gitignore listed file, <32 char entropy)
MATCH: high-entropy strings (Base64≥40, Hex≥32, known key prefixes), connection strings
EXCLUDE: BEGIN CERTIFICATE/PUBLIC KEY, base64 image, template ${}, test/mock paths, .gitignore covered

- [ ] **Step 7: Verify P0 batch — scan example code**

```bash
# Verify the 6 updated detectors exist and have required chapters
for f in resource-socket-leak resource-lock-misuse resource-file-double-close resource-file-use-after-close resource-refcount-misuse system-secrets-detection; do
  echo "=== $f ==="
  echo "Sections: $(grep -c '^## ' knowledge/guard-rules/$f.md)"
  echo "FP table: $(grep -c '| 场景 | 排除依据 | 证据要求 |' knowledge/guard-rules/$f.md)"
  echo "MUST evidence: $(grep -c '必须收集' knowledge/guard-rules/$f.md)"
  echo "MATCH: $(grep -c 'MATCH' knowledge/guard-rules/$f.md)"
  echo "EXCLUDE: $(grep -c 'EXCLUDE' knowledge/guard-rules/$f.md)"
  echo ""
done
```

Expected all 6: sections≥6, FP≥1, MUST≥1, MATCH≥1, EXCLUDE≥1

- [ ] **Step 8: Commit P0 batch**

```bash
git add knowledge/guard-rules/resource-socket-leak.md \
        knowledge/guard-rules/resource-lock-misuse.md \
        knowledge/guard-rules/resource-file-double-close.md \
        knowledge/guard-rules/resource-file-use-after-close.md \
        knowledge/guard-rules/resource-refcount-misuse.md \
        knowledge/guard-rules/system-secrets-detection.md
git commit -m "feat(detectors): P0 — complete rebuild of 6 detectors with FP + evidence

Rebuilt from scratch per unified template:
- resource-socket-leak (48→~120 lines)
- resource-lock-misuse (52→~110 lines)
- resource-file-double-close (49→~100 lines)
- resource-file-use-after-close (45→~100 lines)
- resource-refcount-misuse (62→~105 lines)
- system-secrets-detection (74→~130 lines)

Each now includes:
- precision + confidence metadata
- MUST/SHOULD/MAY 3-tier evidence collection guide
- FP exclusion table with evidence requirements (3-7 items each)
- MATCH/EXCLUDE pattern separation with evidence anchors

Part of detector FP elimination + evidence enhancement (Phase P0).

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: P1 Batch — Enrich Content-Light Detectors (13 detectors)

**Files (modify):**

| # | File | Lines | Current Gap |
|---|------|-------|-------------|
| 1 | `concurrency-thread-unsafe-signal.md` | 73 | Thin detection logic, FP table minimal |
| 2 | `system-toctou.md` | 73 | Thin detection logic |
| 3 | `concurrency-deadlock.md` | 84 | Thin FP table |
| 4 | `memory-uninitialized-memory.md` | 84 | No code examples beyond BAD |
| 5 | `error-unified-error-format.md` | 86 | Thin detection logic |
| 6 | `memory-bad-cast.md` | 86 | Thin detection patterns |
| 7 | `web-open-redirect.md` | 87 | Thin FP table |
| 8 | `system-insecure-temp-file.md` | 88 | Thin FP table |
| 9 | `web-idor.md` | 88 | Thin detection patterns |
| 10 | `web-auth-bypass.md` | 92 | Thin FP table |
| 11 | `crypto-weak-crypto-algorithm.md` | 93 | FP table missing evidence column |
| 12 | `memory-off-by-one.md` | 93 | Thin FP table |
| 13 | `system-command-injection.md` | 93 | FP table missing evidence column |

**Purpose:** These detectors exist but are thin (<94 lines). Enrich with:
1. FP exclusion table → 3-column format with evidence requirement binding
2. Evidence collection guide (MUST/SHOULD/MAY)
3. Detection patterns → MATCH/EXCLUDE separation
4. Add `precision` + `confidence: dynamic` to frontmatter

**Per-file transformation script (apply to each):**

```markdown
## Step pattern for each P1 detector:

1. READ current content
2. Add precision + confidence to frontmatter:
   precision: <assigned per vulnerability class>
   confidence: dynamic
3. If Indexer Input section exists → REMOVE (not part of standard template)
4. If FP section exists → convert to 3-column format (场景|排除依据|证据要求)
   If FP section missing → create with ≥3 rows
5. INSERT 取证证据收集指引 chapter after 检测逻辑, before 误报排除
   - MUST: code_context + judgment_rationale (per-detector specifics)
   - SHOULD: data_flow_path + call_stack (per-detector scope)
   - MAY: variable_state + sanitizer_analysis (per-detector specifics)
6. Transform 检测模式汇总 to MATCH/EXCLUDE format
7. Unify all chapter headers to bilingual format
```

**precision assignments for P1:**

| Detector | precision | Rationale |
|----------|-----------|-----------|
| concurrency-thread-unsafe-signal | medium | Async-signal-safe rules are context-dependent |
| system-toctou | medium | Time-of-check races require runtime behavior |
| concurrency-deadlock | medium | Lock-ordering analysis needs call graph |
| memory-uninitialized-memory | high | Clear pattern, well-defined |
| error-unified-error-format | very-high | Pattern-based, highly specific |
| memory-bad-cast | high | Type-based pattern, specific |
| web-open-redirect | medium | Needs URL parsing context |
| system-insecure-temp-file | high | Well-defined patterns (mktemp, tmpnam) |
| web-idor | low | Requires business logic understanding |
| web-auth-bypass | medium | Context-dependent auth logic |
| crypto-weak-crypto-algorithm | very-high | Well-known algorithm names, specific |
| memory-off-by-one | high | Clear boundary-check pattern |
| system-command-injection | very-high | Well-defined dangerous functions |

- [ ] **Step 1-13: Process each P1 detector (one commit per 3-4 detectors)**

```bash
# After each sub-group of 3-4, verify and commit:
git add knowledge/guard-rules/<updated-files>
git commit -m "feat(detectors): P1 — enrich <detector-names> with FP evidence binding"
```

- [ ] **Step 14: Verify P1 batch**

```bash
for f in concurrency-thread-unsafe-signal system-toctou concurrency-deadlock memory-uninitialized-memory error-unified-error-format memory-bad-cast web-open-redirect system-insecure-temp-file web-idor web-auth-bypass crypto-weak-crypto-algorithm memory-off-by-one system-command-injection; do
  echo "=== $f ==="
  echo "Sections: $(grep -c '^## ' knowledge/guard-rules/$f.md)"
  echo "precision: $(grep 'precision:' knowledge/guard-rules/$f.md)"
  echo "FP evidence col: $(grep -c '证据要求' knowledge/guard-rules/$f.md)"
  echo "MUST evidence: $(grep -c '必须收集' knowledge/guard-rules/$f.md)"
  echo "MATCH/EXCLUDE: $(grep -c 'MATCH\|EXCLUDE' knowledge/guard-rules/$f.md)"
  echo ""
done
```

- [ ] **Step 15: Commit P1 batch completion**

```bash
git commit -m "feat(detectors): P1 complete — enrich 13 content-light detectors

Added to all 13:
- precision metadata + confidence: dynamic
- MUST/SHOULD/MAY evidence collection guide
- 3-column FP exclusion table with evidence requirement binding
- MATCH/EXCLUDE pattern separation
- Unified bilingual chapter headers

Part of detector FP elimination + evidence enhancement (Phase P1).

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: P2 Batch — Format Standardization (28 detectors)

**Files (modify):** All detectors in 94–138 line range:

```
crypto-insufficient-key-length (94), web-csrf (96), web-xxe (96),
concurrency-data-race (99), crypto-weak-random (99), web-jwt-misuse (101),
memory-heap-buffer-overflow (103), web-code-injection (103), web-ssrf (104),
web-deserialization (106), web-xss (106), memory-format-string (111),
memory-mismatched-free (112), memory-integer-overflow (113),
memory-memory-leak (117), web-unrestricted-upload (117),
memory-null-dereference (119), memory-oob-read (120),
system-insecure-permissions (121), web-missing-authorization (123),
web-input-validation (124), error-panic-to-client (126),
memory-use-after-free (130), memory-buffer-overflow (130),
web-missing-authentication (131), concurrency-race-condition (133),
memory-double-free (136), web-resource-exhaustion (138)
```

**Purpose:** These detectors have decent content but need:
1. Frontmatter: add `precision` + `confidence: dynamic`
2. FP table: convert existing table to 3-column format (add `证据要求` column)
3. Evidence collection guide: insert new chapter (MUST/SHOULD/MAY)
4. Detection patterns: add MATCH/EXCLUDE labels
5. Chapter headers: ensure bilingual format

**Standard bulk operations per file:**

```markdown
For each P2 detector:
1. Add to frontmatter (after tags line):
   precision: <assigned>
   confidence: dynamic
2. Convert FP table:
   OLD: | 场景 | 原因 |
   NEW: | 场景 | 排除依据 | 证据要求 |
   Add evidence requirement to each existing row
3. Insert evidence collection chapter between 检测逻辑 and 误报排除
4. Add MATCH/EXCLUDE labels to 检测模式汇总
5. Verify all 7 chapters present
```

**precision assignments for P2 (by namespace pattern):**

| Namespace | Typical precision | Rationale |
|-----------|-----------------|-----------|
| memory/* | high or very-high | Well-defined patterns (CWE mapped tightly) |
| web/* | medium or high | Depends on whether context-dependent |
| system/* | high | Well-defined APIs/patterns |
| error/* | very-high | Highly specific patterns |
| crypto/* | very-high or high | Well-known algorithms |
| concurrency/* | medium | Needs runtime/call-graph context |

- [ ] **Step 1-28: Process each P2 detector (batch in groups of 5-6)**

Process in sub-groups for manageable commits:
- Group A: crypto-insufficient-key-length, web-csrf, web-xxe, concurrency-data-race, crypto-weak-random
- Group B: web-jwt-misuse, memory-heap-buffer-overflow, web-code-injection, web-ssrf, web-deserialization
- Group C: web-xss, memory-format-string, memory-mismatched-free, memory-integer-overflow, memory-memory-leak
- Group D: web-unrestricted-upload, memory-null-dereference, memory-oob-read, system-insecure-permissions, web-missing-authorization
- Group E: web-input-validation, error-panic-to-client, memory-use-after-free, memory-buffer-overflow
- Group F: web-missing-authentication, concurrency-race-condition, memory-double-free, web-resource-exhaustion

- [ ] **Step 29: Verify P2 batch**

```bash
for f in crypto-insufficient-key-length web-csrf web-xxe concurrency-data-race crypto-weak-random web-jwt-misuse memory-heap-buffer-overflow web-code-injection web-ssrf web-deserialization web-xss memory-format-string memory-mismatched-free memory-integer-overflow memory-memory-leak web-unrestricted-upload memory-null-dereference memory-oob-read system-insecure-permissions web-missing-authorization web-input-validation error-panic-to-client memory-use-after-free memory-buffer-overflow web-missing-authentication concurrency-race-condition memory-double-free web-resource-exhaustion; do
  echo "=== $f ==="
  echo "precision: $(grep -c 'precision:' knowledge/guard-rules/$f.md)"
  echo "confidence: $(grep -c 'confidence: dynamic' knowledge/guard-rules/$f.md)"
  echo "FP 3-col: $(grep -c '排除依据.*证据要求' knowledge/guard-rules/$f.md)"
  echo "Evidence ch: $(grep -c '取证证据收集指引' knowledge/guard-rules/$f.md)"
  echo ""
done
# Expected: all 28 show 1 for each check
```

- [ ] **Step 30: Commit P2 batch**

```bash
git add knowledge/guard-rules/
git commit -m "feat(detectors): P2 — standardize 28 medium-quality detectors

Added to all 28:
- precision + confidence: dynamic frontmatter
- 3-column FP exclusion table (场景|排除依据|证据要求)
- MUST/SHOULD/MAY evidence collection guide
- MATCH/EXCLUDE pattern separation
- Unified bilingual chapter headers

Coverage: crypto(2), web(12), memory(8), system(1), error(1), concurrency(2).

Part of detector FP elimination + evidence enhancement (Phase P2).

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: P3 Batch — Metadata Upgrade (20 detectors)

**Files (modify):** Well-formed detectors ≥140 lines:

```
crypto-hardcoded-secrets (141), crypto-hardcoded-iv (142),
crypto-aes-ecb-mode (150), web-prototype-pollution (151),
crypto-custom-crypto (153), web-nosql-injection (157),
crypto-tls-version (167), crypto-password-storage (172),
error-exception-swallow (177), web-ssti (182),
error-log-sensitive-data (188), web-excessive-data-exposure (190),
error-debug-mode-production (191), web-mass-assignment (196),
error-stack-trace-leak (201), web-sql-injection (278),
system-path-traversal (83), system-privilege-escalation (82),
system-symlink-attack (82), resource-file-leak (71)
```

**Purpose:** These already have comprehensive detection logic, FP tables, and patterns. Minimal changes:
1. Add `precision` + `confidence: dynamic` to frontmatter
2. If FP table is 2-column → convert to 3-column (add `证据要求` column)
3. If 检测模式汇总 lacks MATCH/EXCLUDE labels → add them
4. If chapter headers aren't bilingual → standardize

**No new evidence chapter insertion needed for most** — these are already content-rich; adding evidence would be nice-to-have but risks bloating an already long file. Exception: `web-sql-injection` (278 lines, the longest) should get a concise evidence chapter.

- [ ] **Step 1: Process crypto-hardcoded-secrets.md (141 lines)**

```markdown
Changes:
1. Frontmatter: add precision: very-high, confidence: dynamic (after tags line)
2. FP table: already detailed (9 rows), add 证据要求 column to each row
   Example: | getenv() / System.getenv() | 运行时读取，非硬编码 | MUST: code_context 确认赋值右值为 getenv() 调用 |
3. Detection patterns: add MATCH/EXCLUDE labels
4. Verify: all checks pass
```

- [ ] **Step 2: Process crypto-hardcoded-iv.md (142 lines)**

```markdown
Changes:
1. Frontmatter: add precision: high, confidence: dynamic
2. FP table: convert to 3-column, add evidence requirements
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 3: Process crypto-aes-ecb-mode.md (150 lines)**

```markdown
Changes:
1. Frontmatter: add precision: very-high, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 4: Process web-prototype-pollution.md (151 lines)**

```markdown
Changes:
1. Frontmatter: add precision: medium, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 5: Process crypto-custom-crypto.md (153 lines)**

```markdown
Changes:
1. Frontmatter: add precision: medium, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 6: Process web-nosql-injection.md (157 lines)**

```markdown
Changes:
1. Frontmatter: add precision: high, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 7: Process crypto-tls-version.md (167 lines)**

```markdown
Changes:
1. Frontmatter: add precision: very-high, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 8: Process crypto-password-storage.md (172 lines)**

```markdown
Changes:
1. Frontmatter: add precision: very-high, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 9: Process error-exception-swallow.md (177 lines)**

```markdown
Changes:
1. Frontmatter: add precision: very-high, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 10: Process web-ssti.md (182 lines)**

```markdown
Changes:
1. Frontmatter: add precision: very-high, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 11: Process error-log-sensitive-data.md (188 lines)**

```markdown
Changes:
1. Frontmatter: add precision: high, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 12: Process web-excessive-data-exposure.md (190 lines)**

```markdown
Changes:
1. Frontmatter: add precision: medium, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 13: Process error-debug-mode-production.md (191 lines)**

```markdown
Changes:
1. Frontmatter: add precision: very-high, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 14: Process web-mass-assignment.md (196 lines)**

```markdown
Changes:
1. Frontmatter: add precision: high, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 15: Process error-stack-trace-leak.md (201 lines)**

```markdown
Changes:
1. Frontmatter: add precision: very-high, confidence: dynamic
2. FP table: convert to 3-column
3. Detection patterns: add MATCH/EXCLUDE
```

- [ ] **Step 16: Process web-sql-injection.md (278 lines)**

```markdown
Changes:
1. Frontmatter: add precision: very-high, confidence: dynamic
2. FP table: already 8 rows, add 证据要求 column
3. Insert concise evidence collection guide (this one is complex enough to benefit)
4. Detection patterns: add MATCH/EXCLUDE labels
```

- [ ] **Step 17: Process 4 remaining edge cases**

```markdown
system-path-traversal (83):
  - Add precision: very-high, confidence: dynamic
  - Add evidence chapter (currently no FP section — borderline between P1/P3)

system-privilege-escalation (82):
  - Add precision: high, confidence: dynamic
  - FP table: convert to 3-column

system-symlink-attack (82):
  - Add precision: medium, confidence: dynamic
  - FP table: convert to 3-column

resource-file-leak (71):
  - Add precision: high, confidence: dynamic
  - FP table: already has, convert to 3-column
```

- [ ] **Step 18: Verify P3 batch**

```bash
for f in crypto-hardcoded-secrets crypto-hardcoded-iv crypto-aes-ecb-mode web-prototype-pollution crypto-custom-crypto web-nosql-injection crypto-tls-version crypto-password-storage error-exception-swallow web-ssti error-log-sensitive-data web-excessive-data-exposure error-debug-mode-production web-mass-assignment error-stack-trace-leak web-sql-injection system-path-traversal system-privilege-escalation system-symlink-attack resource-file-leak; do
  echo "=== $f ==="
  echo "precision: $(grep -c 'precision:' knowledge/guard-rules/$f.md)"
  echo "confidence: $(grep -c 'confidence: dynamic' knowledge/guard-rules/$f.md)"
  echo "3-col FP: $(grep -c '排除依据.*证据要求' knowledge/guard-rules/$f.md)"
  echo ""
done
# Expected: all 20 show 1 for precision, 1 for confidence, ≥1 for 3-col FP
```

- [ ] **Step 19: Commit P3 batch**

```bash
git add knowledge/guard-rules/
git commit -m "feat(detectors): P3 — metadata upgrade for 20 well-formed detectors

Added precision + confidence: dynamic to frontmatter for all 20.
Converted FP tables to 3-column format (场景|排除依据|证据要求).
Added MATCH/EXCLUDE labels to detection patterns.

Coverage: crypto(6), web(6), error(4), system(3), resource(1).

All 67 detectors now complete with unified template.

Part of detector FP elimination + evidence enhancement (Phase P3).

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: Final Verification — Scan Example Code

**Purpose:** Verify the detector upgrades actually work by scanning example vulnerability code and comparing finding quality.

- [ ] **Step 1: Verify all 67 detectors pass structural checks**

```bash
#!/bin/bash
# Comprehensive structural verification
TOTAL=0; PASS=0; FAIL=0
echo "=== Detector Structural Verification ==="
for f in knowledge/guard-rules/*.md; do
  TOTAL=$((TOTAL+1))
  ERRORS=0
  
  # 1. Has precision
  grep -q 'precision:' "$f" || { echo "  MISSING precision: $f"; ERRORS=$((ERRORS+1)); }
  
  # 2. Has confidence: dynamic
  grep -q 'confidence: dynamic' "$f" || { echo "  MISSING confidence: $f"; ERRORS=$((ERRORS+1)); }
  
  # 3. Has evidence collection chapter
  grep -q '取证证据收集指引' "$f" || { echo "  MISSING evidence chapter: $f"; ERRORS=$((ERRORS+1)); }
  
  # 4. Has 3-column FP table
  grep -q '| 场景 | 排除依据 | 证据要求 |' "$f" && grep -q '排除依据.*证据要求' "$f" || { echo "  MISSING 3-col FP: $f"; ERRORS=$((ERRORS+1)); }
  
  # 5. Has MATCH/EXCLUDE
  grep -q 'MATCH\|EXCLUDE' "$f" || { echo "  MISSING MATCH/EXCLUDE: $f"; ERRORS=$((ERRORS+1)); }
  
  # 6. Has ≥6 chapters
  CHAPTERS=$(grep -c '^## ' "$f")
  [ "$CHAPTERS" -ge 6 ] || { echo "  FEW CHAPTERS ($CHAPTERS): $f"; ERRORS=$((ERRORS+1)); }
  
  if [ $ERRORS -eq 0 ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
  fi
done
echo "Results: $PASS/$TOTAL passed, $FAIL/$TOTAL failed"
[ $FAIL -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
```

Expected: 67/67 passed.

- [ ] **Step 2: Scan C++ example code**

```bash
# Launch secguard scan on C++ vuln demo
# This is an AI-driven scan — the agent reads detector knowledge and scans the code
# Expected: findings with evidence.code_context and evidence.judgment_rationale populated
# Expected: fewer FP than pre-upgrade baseline (precise count depends on scanner)
```

Record findings count and spot-check 3 findings for evidence completeness (code_context + judgment_rationale + data_flow_path populated).

- [ ] **Step 3: Scan Python example code**

```bash
# Similar scan on python-vuln-demo/src/
# Expected: web/* detectors trigger with evidence populated
```

- [ ] **Step 4: Scan Java example code**

```bash
# Similar scan on java-vuln-demo/src/
# Expected: crypto/*, web/* detectors trigger
```

- [ ] **Step 5: Compare evidence completeness**

```bash
# For each scan output, check evidence field population:
# - code_context: should be 100% populated
# - judgment_rationale: should be 100% populated
# - data_flow_path: should be ≥70% populated (some single-point vulns are N/A)
# - call_stack: should be ≥50% populated (cross-function vulns only)
```

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore(verify): final verification — all 67 detectors pass structural checks

Verification results:
- 67/67 detectors have precision + confidence metadata
- 67/67 detectors have evidence collection guide (MUST/SHOULD/MAY)
- 67/67 detectors have 3-column FP exclusion table
- 67/67 detectors have MATCH/EXCLUDE pattern separation
- 67/67 detectors have ≥6 standard chapters

Detector FP elimination + evidence enhancement — COMPLETE.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Summary

| Phase | Files | Changes | Verification |
|-------|-------|---------|-------------|
| Task 0 | 1 (schema) | +3 evidence fields | JSON validity |
| Task 1 (P0) | 6 detectors | Complete rebuild | Chapter count + FP rows + evidence MUST |
| Task 2 (P1) | 13 detectors | Enrich with evidence + FP binding | Same structural checks + scan |
| Task 3 (P2) | 28 detectors | Standardize format + add evidence | Same structural checks + scan |
| Task 4 (P3) | 20 detectors | Metadata upgrade only | precision + confidence present |
| Task 5 | All 67 | Final scan verification | Structural + scan quality checks |

**Total commits: ~10–15** (1 schema + 1 per P0 + 3-4 per P1 + 5 per P2 + 1 per P3 + 1 final verification)
