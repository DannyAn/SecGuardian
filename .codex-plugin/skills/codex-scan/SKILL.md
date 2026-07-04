---
name: codex-scan
description: "对指定语言样例执行单次扫描验证"
---

# /codex-scan — 单语言扫描验证

参数: `<language>` (cpp/go/java/python/js)

## Step 1: 索引检查

检查共享索引是否存在。不存在则构建。

```bash
LANG="$1"
SRC="examples/${LANG}-vuln-demo/src"
OUT="examples/${LANG}-vuln-demo/.codeagent/secguardian/index.json"
mkdir -p "$(dirname "$OUT")"

if [ ! -f "$OUT" ]; then
    bash scripts/secguardian-index --path "$SRC" --output "$OUT"
fi
python3 -c "import json; d=json.load(open('$OUT')); print(f'Index: {d[\"file_count\"]} files, path={d[\"path\"]}')"
```

## Step 2: 输出路径验证

```bash
SCAN_DIR="examples/${LANG}-vuln-demo/.codeagent/secguardian/secguard/scans"
[ -d "$SCAN_DIR" ] && echo "✅ 输出目录: $SCAN_DIR" || echo "❌ 无扫描输出"
```

## Step 3: 缓存验证

再次构建应命中缓存：

```bash
bash scripts/secguardian-index --path "$SRC" --output "$OUT" 2>&1 | grep -q "INDEX EXISTS" && echo "✅ 缓存命中" || echo "⚠️ 未命中缓存"
```
