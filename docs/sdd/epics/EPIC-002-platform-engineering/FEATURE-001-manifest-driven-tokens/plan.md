# Manifest-Driven Tokens — 实施计划

> **Feature**: FEATURE-001-manifest-driven-tokens
> **Epic**: EPIC-002-platform-engineering
> **状态**: ✅ 已完成


**Goal:** 消除 detector 数量变更时的散弹式修改——manifest.json 为单一权威源，sync-manifest.sh 自动传播到所有文件。

**Architecture:** `NNN<!-- @secguardian:token_name -->` 标记格式，`sync-manifest.sh` 读取 manifest.json 更新数字，`package.sh` 构建时调用，`self-check.sh` 的 `--check` 模式验证一致性。

**关联 Spec:** [spec.md](../spec.md)

---

### Task 1: 创建 `scripts/sync-manifest.sh` 核心同步脚本

**Files:**
- Create: `scripts/sync-manifest.sh`

这是整个方案的核心引擎。一个脚本完成所有 token 的读取、更新、校验。

- [ ] **Step 1: 创建脚本骨架**

```bash
#!/bin/bash
# sync-manifest.sh — Sync token markers across project files from manifest.json
#
# Token format: NNN<!-- @secguardian:token_name -->
# Each token is a number followed by an HTML comment identifying the key.
# sync-manifest.sh reads the authoritative value from manifest.json and
# updates the number before the marker.
#
# Usage:
#   bash scripts/sync-manifest.sh           Update all files
#   bash scripts/sync-manifest.sh --check   CI mode: verify only, exit 1 on mismatch

set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$PROJECT_ROOT/manifest.json"

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; fi

# Read canonical values from manifest.json
read_manifest() {
    python3 -c "
import json, sys
with open('$MANIFEST') as f:
    d = json.load(f)
det = d['knowledge']['detectors']
ns = det['namespaces']
print(f\"DETECTOR_COUNT={det['count']}\")
print(f\"NAMESPACE_COUNT={len(ns)}\")
for k, v in ns.items():
    print(f\"NAMESPACE_{k.upper()}={v}\")
"
}

eval "$(read_manifest)"

# Token definition: name → value
declare -A TOKENS=(
    ["detector_count"]="$DETECTOR_COUNT"
    ["namespace_count"]="$NAMESPACE_COUNT"
    ["namespace:memory"]="$NAMESPACE_MEMORY"
    ["namespace:concurrency"]="$NAMESPACE_CONCURRENCY"
    ["namespace:system"]="$NAMESPACE_SYSTEM"
    ["namespace:crypto"]="$NAMESPACE_CRYPTO"
    ["namespace:web"]="$NAMESPACE_WEB"
    ["namespace:error"]="$NAMESPACE_ERROR"
    ["namespace:resource"]="$NAMESPACE_RESOURCE"
)

# Find all files containing tokens in the project
FILES_WITH_TOKENS=$(grep -rl '@secguardian:' "$PROJECT_ROOT" \
    --include="*.md" --include="*.json" --include="*.sh" 2>/dev/null | \
    grep -v '.codeagent\|node_modules\|dist/\|.git/')

if [ -z "$FILES_WITH_TOKENS" ]; then
    echo "No token markers found in project files."
    exit 0
fi

PASS=0; FAIL=0

for file in $FILES_WITH_TOKENS; do
    # Process only tokens that exist in this file
    for token_name in "${!TOKENS[@]}"; do
        expected="${TOKENS[$token_name]}"
        marker="@secguardian:$token_name"
        
        if grep -q "$marker" "$file" 2>/dev/null; then
            if [ "$CHECK" -eq 1 ]; then
                # CI mode: verify correctness
                actual=$(grep -oP "[0-9]+(?=<!-- $marker -->)" "$file" 2>/dev/null || echo "")
                if [ -z "$actual" ]; then
                    echo "  ❌ $file: marker '<!-- $marker -->' found but no preceding number"
                    FAIL=$((FAIL + 1))
                elif [ "$actual" != "$expected" ]; then
                    echo "  ❌ $file: $marker = $actual (expected $expected)"
                    FAIL=$((FAIL + 1))
                else
                    echo "  ✅ $file: $marker = $actual"
                    PASS=$((PASS + 1))
                fi
            else
                # Update mode: replace preceding number
                sed -i '' -E "s/[0-9]+<!-- $marker -->/$expected<!-- $marker -->/g" "$file"
                echo "  ✓ $file: $marker → $expected"
            fi
        fi
    done
done

if [ "$CHECK" -eq 1 ]; then
    echo ""
    echo "Token check: $PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ] || exit 1
else
    echo ""
    echo "Synced ${#TOKENS[@]} token types across $(echo "$FILES_WITH_TOKENS" | wc -l | tr -d ' ') files."
fi
```

- [ ] **Step 2: 测试 sync-manifest.sh**

```bash
# 单元测试：创建一个测试 manifest，验证 token 替换
mkdir -p /tmp/test-sync && cp manifest.json /tmp/test-sync/
echo '67<!-- @secguardian:detector_count -->' > /tmp/test-sync/test.md

# 修改 manifest count 为 99
python3 -c "import json; d=json.load(open('/tmp/test-sync/manifest.json')); d['knowledge']['detectors']['count']=99; json.dump(d, open('/tmp/test-sync/manifest.json','w'))"

# 运行同步
MANIFEST=/tmp/test-sync/manifest.json bash scripts/sync-manifest.sh
# Expected: test.md 中的 67 更新为 99

# 验证
grep "99<!-- @secguardian:detector_count -->" /tmp/test-sync/test.md && echo "✅ Token updated" || echo "❌ FAIL"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/sync-manifest.sh && git commit -m "feat: add sync-manifest.sh — manifest-driven token synchronization

Token format: NNN<!-- @secguardian:token_name -->
Reads authoritative values from manifest.json, updates all project files.
--check mode for CI validation (exit 1 on mismatch).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Token 化系统文件

**Files:**
- Modify: `knowledge/threat-catalog.md`
- Modify: `extensions/secguard-secguardian/extension.json`
- Modify: `extensions/secaudit-secguardian/extension.json`
- Modify: `extensions/secreview-secguardian/extension.json`
- Modify: `commands/secguard.md`
- Modify: `skills/secguard/cpp/references/language-index.md`
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `GEMINI.md`

在每个文件的硬编码数字处添加 `<!-- @secguardian:xxx -->` 标记。

- [ ] **Step 1: knowledge/threat-catalog.md**

```markdown
# Before:
description: 安全威胁目录 — 覆盖所有 67 个检测器对应威胁类型的快速索引
## 内存安全 (memory) — 13 个 detectors

# After:
description: 安全威胁目录 — 覆盖所有 67<!-- @secguardian:detector_count --> 个检测器对应威胁类型的快速索引
## 内存安全 (memory) — 13<!-- @secguardian:namespace:memory --> 个 detectors
## 并发安全 (concurrency) — 4<!-- @secguardian:namespace:concurrency --> 个 detectors
## 系统安全 (system) — 8<!-- @secguardian:namespace:system --> 个 detectors
## 加密安全 (crypto) — 9<!-- @secguardian:namespace:crypto --> 个 detectors
## Web + 应用安全 (web) — 21<!-- @secguardian:namespace:web --> 个 detectors
## 资源安全 (resource) — 6<!-- @secguardian:namespace:resource --> 个 detectors
## 错误处理安全 (error) — 6<!-- @secguardian:namespace:error --> 个 detectors
```

- [ ] **Step 2: extensions/ 三个 extension.json**

```json
// Before:
"description": "安全加固项排查 — 67 个检测器覆盖 7 大安全分类"

// After:
"description": "安全加固项排查 — 67<!-- @secguardian:detector_count --> 个检测器覆盖 7<!-- @secguardian:namespace_count --> 大安全分类"
```

- [ ] **Step 3: commands/secguard.md frontmatter**

```yaml
# Before:
description: "安全加固项排查 — 67 个检测器覆盖 memory/concurrency/system/resource/crypto/web/error 7 大安全分类"

# After:
description: "安全加固项排查 — 67<!-- @secguardian:detector_count --> 个检测器覆盖 memory/concurrency/system/resource/crypto/web/error 7<!-- @secguardian:namespace_count --> 大安全分类"
```

- [ ] **Step 4: skills/secguard/cpp/references/language-index.md**

```markdown
# Before:
/secguard ./src *                     # 全部 67 个检测器

# After:
/secguard ./src *                     # 全部 67<!-- @secguardian:detector_count --> 个检测器
```

- [ ] **Step 5: CLAUDE.md / AGENTS.md / GEMINI.md**

将其中所有 "67 个检测器"、"覆盖 7 大" 等硬编码改为 token 格式。

- [ ] **Step 6: 运行 sync-manifest.sh --check 验证**

```bash
bash scripts/sync-manifest.sh --check
# Expected: 所有 token 数字与 manifest.json 一致，pass=全部
```

- [ ] **Step 7: Commit**

```bash
git add knowledge/threat-catalog.md extensions/ commands/secguard.md \
        skills/secguard/cpp/references/language-index.md CLAUDE.md AGENTS.md GEMINI.md
git commit -m "feat: tokenize all system files with @secguardian markers

Replace hardcoded detector counts with NNN<!-- @secguardian:xxx --> tokens.
Tokenized files: threat-catalog, extension.json x3, secguard.md,
language-index.md, CLAUDE.md, AGENTS.md, GEMINI.md.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: render-report.py DETECTOR_RULE_INDEX 动态化

**Files:**
- Modify: `scripts/render-report.py`

当前 70 行硬编码 CWE 映射。

- [ ] **Step 1: 添加 detector 信息解析函数**

```python
def load_detector_index_from_files(detectors_dir=None):
    """Build detector → {index, cwe} mapping from knowledge/guard-rules/*.md files.
    
    Falls back to builtin DETECTOR_RULE_INDEX if detector files not available.
    """
    if detectors_dir is None:
        # Find knowledge/guard-rules/ relative to this script
        script_dir = os.path.dirname(os.path.abspath(__file__))
        detectors_dir = os.path.join(script_dir, "..", "knowledge", "detectors")
    
    if not os.path.isdir(detectors_dir):
        return DETECTOR_RULE_INDEX  # fallback
    
    index = {}
    detector_files = sorted(f for f in os.listdir(detectors_dir) if f.endswith('.md'))
    
    for i, fname in enumerate(detector_files):
        # Convert filename to detector name: memory-null-dereference.md → memory.null-dereference
        name = fname[:-3]  # strip .md
        parts = name.split('-', 1)
        if len(parts) == 2:
            detector_name = f"{parts[0]}.{parts[1]}"
        else:
            detector_name = name
        
        # Parse CWE from detector file frontmatter
        cwe_list = []
        filepath = os.path.join(detectors_dir, fname)
        try:
            with open(filepath) as f:
                content = f.read(4096)  # read first 4KB for frontmatter
            for line in content.split('\n'):
                if line.startswith('cwe:') or line.startswith('CWE:'):
                    cwe_list = [c.strip() for c in line.split(':', 1)[1].split(',')]
                    break
        except Exception:
            pass
        
        if not cwe_list:
            cwe_list = ["CWE-000"]
        
        index[detector_name] = {"index": i, "cwe": cwe_list}
    
    return index


# Keep builtin as fallback
DETECTOR_RULE_INDEX_FALLBACK = {
    # ... keep existing dict as fallback ...
}

# Use dynamic loading, fall back to builtin
try:
    DETECTOR_RULE_INDEX = load_detector_index_from_files()
    if not DETECTOR_RULE_INDEX:
        DETECTOR_RULE_INDEX = DETECTOR_RULE_INDEX_FALLBACK
except Exception:
    DETECTOR_RULE_INDEX = DETECTOR_RULE_INDEX_FALLBACK
```

- [ ] **Step 2: 验证 SARIF 输出不变**

```bash
# 用同一个 findings.json 运行新旧渲染器，对比 SARIF rules 数量
/usr/bin/python3 scripts/render-report.py \
    --findings .../findings.json --index .../index.json --output /tmp/test-sarif/
python3 -c "import json; d=json.load(open('/tmp/test-sarif/results.sarif')); print(f'SARIF rules: {len(d[\"runs\"][0][\"tool\"][\"driver\"][\"rules\"])}')"
# Expected: SARIF rules count matches number of unique detectors in findings
```

- [ ] **Step 3: Commit**

```bash
git add scripts/render-report.py
git commit -m "feat(renderer): dynamic DETECTOR_RULE_INDEX from knowledge/guard-rules/

Replace 70-line hardcoded CWE mapping with runtime loading from
detector file frontmatter. Builtin fallback preserved for when
detector files are unavailable.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: 集成到构建和验证流程

**Files:**
- Modify: `scripts/package.sh`
- Modify: `scripts/self-check.sh`

- [ ] **Step 1: package.sh 调用 sync-manifest.sh**

在 `package.sh` 的编译步骤之后、`assemble dist/` 之前加入：

```bash
# ── Sync manifest tokens ──
echo "  → Syncing manifest tokens..."
bash "$PROJECT_ROOT/scripts/sync-manifest.sh" || {
    echo "ERROR: sync-manifest.sh failed — token mismatch detected"
    exit 1
}
```

- [ ] **Step 2: self-check.sh 新增 token 一致性检查**

在 self-check.sh 现有 §7 (threat-catalog vs manifest) 之后、Go compilation 之前加入：

```bash
# ── 7.5. Token consistency (manifest-driven) ──
echo "7.5. Manifest token consistency"
bash "$PROJECT_ROOT/scripts/sync-manifest.sh" --check
if [ $? -eq 0 ]; then
    green "All @secguardian tokens match manifest.json"
else
    red "Token mismatch — run: bash scripts/sync-manifest.sh"
fi
echo ""
```

- [ ] **Step 3: 全量验证**

```bash
# 模拟 detector 变更流程
python3 -c "
import json
m = json.load(open('manifest.json'))
m['knowledge']['detectors']['count'] = 99  # 故意制造不一致
json.dump(m, open('/tmp/test-manifest.json', 'w'))
"
# sync-manifest.sh --check 应该检测到不一致
MANIFEST=/tmp/test-manifest.json bash scripts/sync-manifest.sh --check
# Expected: exit 1, 报告 token 不匹配

# 恢复
rm /tmp/test-manifest.json
```

- [ ] **Step 4: Commit**

```bash
git add scripts/package.sh scripts/self-check.sh
git commit -m "feat: integrate sync-manifest.sh into build + verify pipeline

- package.sh calls sync-manifest.sh before assembling dist/
- self-check.sh calls sync-manifest.sh --check as L1 verification

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: 端到端验证

- [ ] **Step 1: 模拟新增 detector 全流程**

```bash
# 1. 创建一个新 detector 文件
echo "---
cwe: CWE-999
severity: Medium
---
# Test Detector" > knowledge/guard-rules/test-new-detector.md

# 2. 更新 manifest.json（count +1, namespace +1）
python3 -c "
import json
m = json.load(open('manifest.json'))
m['knowledge']['detectors']['count'] = 68
m['knowledge']['detectors']['namespaces']['test'] = 1
json.dump(m, open('manifest.json', 'w'), indent=2, ensure_ascii=False)
" 

# 3. 运行 sync-manifest.sh
bash scripts/sync-manifest.sh

# 4. 验证所有 token 已更新
bash scripts/sync-manifest.sh --check
# Expected: 全部 pass

# 5. 运行 self-check.sh
bash scripts/self-check.sh
# Expected: 新 detector 文件被识别

# 6. 运行 dev-deploy.sh
bash scripts/dev-deploy.sh
# Expected: 部署成功，所有 token 为最新值

# 7. 清理
rm knowledge/guard-rules/test-new-detector.md
git checkout manifest.json
bash scripts/sync-manifest.sh
```

- [ ] **Step 2: 运行完整 L1-L4 验证**

```bash
bash scripts/self-check.sh && bash scripts/ci-check.sh && \
bash scripts/dev-verify.sh && bash scripts/e2e-verify.sh
# Expected: 全绿
```

---

## 验证检查清单

- [ ] `sync-manifest.sh --check` 在干净工作区返回 0
- [ ] 修改 manifest.json count → `sync-manifest.sh --check` 返回 1
- [ ] `sync-manifest.sh` 更新所有文件的 token 数字为权威值
- [ ] `package.sh` 构建时自动调用 sync-manifest.sh
- [ ] `self-check.sh` 新增 token 一致性检查
- [ ] `dev-deploy.sh --reset` 完整通过
- [ ] 新增 detector → 只改 manifest.json + 写 detector 文件 → deploy 后所有 token 自动更新

---

*关联文档: [spec.md](../spec.md)*
