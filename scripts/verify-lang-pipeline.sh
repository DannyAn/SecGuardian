#!/bin/bash
# Cross-Language Full Pipeline Verification
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
RENDERER="$PROJECT_ROOT/scripts/render-report.py"
INDEXER="$PROJECT_ROOT/scripts/secguardian-index"
PASS=0; FAIL=0
green() { echo "  [OK] $1"; PASS=$((PASS+1)); }
red()   { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT
echo "Cross-Language Pipeline Verification"
for lang_dir in cpp-vuln-demo python-vuln-demo java-vuln-demo go-vuln-demo; do
    LANG_PATH="$PROJECT_ROOT/examples/$lang_dir/src"
    echo "--- $lang_dir ---"
    INDEX_FILE="$TMPDIR/${lang_dir}-index.json"
    if ! bash "$INDEXER" --path "$LANG_PATH" --output "$INDEX_FILE" >/dev/null 2>&1; then
        red "$lang_dir: indexer FAILED"; continue
    fi
    green "$lang_dir: indexer"
    SUMMARY=$(python3 "$PROJECT_ROOT/scripts/validate-index.py" --index "$INDEX_FILE" --scan-id "pipe-$lang_dir" 2>&1)
    LANG_NAME=$(echo "$SUMMARY" | python3 -c "import json,sys;print(json.load(sys.stdin)['primary_language'])" 2>/dev/null || echo "FAIL")
    if [ "$LANG_NAME" = "FAIL" ]; then red "$lang_dir: validate FAILED"; continue; fi
    green "$lang_dir: validate -> $LANG_NAME"
    FINDINGS_DIR="$TMPDIR/${lang_dir}-findings"
    mkdir -p "$FINDINGS_DIR/memory/buffer-overflow"
    python3 -c "import json; f={'schema_version':'1.0','finding':{'id':'C-BUF-pipeline-L1','severity':'Critical','cwe':'CWE-120','detector':'memory.buffer-overflow','file':'test.$LANG_NAME','line':10,'function':'test','title':'Test','fix_summary':'Fix','location':{'file_path':'test.$LANG_NAME','start_line':10,'end_line':12,'snippet':'bad'},'evidence':{'code_context':'bad','judgment_rationale':'no bounds','data_flow_path':'overflow'},'impact':{'attack_scenario':'overflow'},'fix':{'before_code':'old','after_code':'new'}}}; open('$FINDINGS_DIR/memory/buffer-overflow/C-BUF-pipeline-L1.json','w').write(json.dumps(f,indent=2))" 2>/dev/null
    python3 -c "import json; d={'scan_id':'pipe-$lang_dir','command':'secguard','path':'examples/$lang_dir/src','mode':'full','language':'$LANG_NAME','timing':{'started':'2026-06-23T00:00:00Z','completed':'2026-06-23T00:00:01Z','duration_ms':1000},'scope':{'files':1,'functions':1,'call_edges':0},'detectors':{'matched':1,'executed':1,'namespaces_used':['memory']},'security_score':75,'findings_index':[{'id':'C-BUF-pipeline-L1','severity':'Critical','cwe':'CWE-120','detector':'memory.buffer-overflow','file':'test.$LANG_NAME','line':10,'function':'test','title':'Test','fix_summary':'Fix','path':'findings/memory/buffer-overflow/C-BUF-pipeline-L1.json'}]}; open('$FINDINGS_DIR/../findings.json','w').write(json.dumps(d,indent=2))" 2>/dev/null
    green "$lang_dir: findings created"
    OUTPUT_DIR="$TMPDIR/${lang_dir}-output"
    python3 "$PROJECT_ROOT/scripts/validate-findings.py" --quiet --findings-dir "$FINDINGS_DIR" 2>/dev/null && green "$lang_dir: all findings validated" || red "$lang_dir: validate-findings FAILED"
    mkdir -p "$OUTPUT_DIR"
    if python3 "$RENDERER" --findings-dir "$FINDINGS_DIR" --index "$INDEX_FILE" --output "$OUTPUT_DIR" 2>/dev/null; then
        green "$lang_dir: renderer OK"
    else
        red "$lang_dir: renderer FAILED"; continue
    fi
    for req_file in report.md results.sarif summary.json manifest.json status.json delta.json; do
        if [ -f "$OUTPUT_DIR/$req_file" ] && [ -s "$OUTPUT_DIR/$req_file" ]; then
            green "  $lang_dir/$req_file OK"
        else
            red "  $lang_dir/$req_file MISSING"
        fi
    done
    CMD=$(python3 -c "import json;print(json.load(open('$OUTPUT_DIR/manifest.json'))['command'])" 2>/dev/null || echo "FAIL")
    [ "$CMD" = "secguard" ] && green "  manifest.command=secguard" || red "  manifest.command=$CMD"
done
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
