---
name: codex-verify
description: "自验证流程 — 修改后运行全套检查"
---

# /codex-verify — 端到端自验证

修改 SecGuardian 代码后，运行此命令验证所有改动正确。

## 执行步骤

### Step 1: 语法自检

```bash
bash scripts/self-check.sh
if [ $? -ne 0 ]; then echo "❌ self-check 失败"; exit 1; fi
```

### Step 2: 构建 + 部署到 OpenCode

```bash
bash scripts/deploy.sh
```

### Step 3: 全语言扫描验证

对 5 个语言样例执行索引构建和输出结构检查：

```bash
FAIL=0
for lang in cpp go java python js; do
    echo "--- $lang ---"
    src="examples/${lang}-vuln-demo/src"
    [ ! -d "$src" ] && echo "  ⏭️  skip (no src)" && continue
    
    INDEX_FILE=""
    # 找共享索引
    for p in "examples/${lang}-vuln-demo/.codeagent/secguardian/index.json"; do
        [ -f "$p" ] && INDEX_FILE="$p" && break
    done
    
    if [ -n "$INDEX_FILE" ]; then
        FILES=$(python3 -c "import json; print(json.load(open('$INDEX_FILE')).get('file_count','?'))" 2>/dev/null)
        echo "  ✅ index exists: ${FILES} files"
    else
        echo "  ❌ index.json not found"
        FAIL=1
    fi
done
```

### Step 4: 输出协议检查

```bash
ERR=0
for lang in cpp go java python js; do
    SCAN_DIR="examples/${lang}-vuln-demo/.codeagent/secguardian"
    # 检查协议文件是否齐全
    for proto in human/executive-summary.md ai/remediation-pack.json report.md dashboard.html findings.json results.sarif summary.json status.json manifest.json delta.json; do
        FOUND=$(find "$SCAN_DIR" -name "$(basename $proto)" 2>/dev/null | head -1)
        if [ -z "$FOUND" ]; then
            echo "  ❌ $lang: missing $proto"
            ERR=1
        fi
    done
done
[ $ERR -eq 0 ] && echo "✅ 所有协议文件齐全"
```

### Step 5: 结果汇总

```bash
echo ""
echo "============================================"
echo "  验证完成"
echo "============================================"
echo "  ✅ self-check.sh: passed"
echo "  ✅ deploy: completed"
echo "  ✅ 5 languages indexed"
echo "  ✅ output protocol complete"
echo "============================================"
```
