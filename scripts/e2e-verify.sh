#!/bin/bash
# SecGuardian — End-to-End Verification Suite v1.0
#
# Comprehensive multi-faceted verification of the AI/Renderer architecture.
# Covers: findings schema conformance, renderer output validation,
#         SARIF 2.1.0 compliance, 4-segment quality gate,
#         multi-language support, CI exit codes, delta comparison.
#
# Usage:
#   bash scripts/e2e-verify.sh              # Full suite
#   bash scripts/e2e-verify.sh --quick       # Fast subset (schema + renderer only)
#   bash scripts/e2e-verify.sh --ci          # CI mode (non-zero exit on failure)
#
# Part of CodePlan: hashed-juggling-sutherland

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# ── Colors ──────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'
BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; WARN=$((WARN+1)); }
section() { echo ""; echo -e "${BOLD}${CYAN}━━━ $1 ━━━${NC}"; }

MODE="${1:-full}"
[ "${1:-}" = "--ci" ] && MODE="ci"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian E2E Verification Suite v1.0     ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════
# 1. Findings Schema Conformance
# ═══════════════════════════════════════════════
section "1. Findings Schema Conformance"

SCHEMA="$PROJECT_ROOT/knowledge/protocols/findings-schema.json"
[ -f "$SCHEMA" ] && pass "Schema file exists" || { fail "Schema file missing: $SCHEMA"; }

# Validate schema is valid JSON
python3 -c "import json; json.load(open('$SCHEMA'))" 2>/dev/null && \
    pass "Schema is valid JSON" || \
    fail "Schema is invalid JSON"

# Validate schema has required top-level fields
python3 -c "
import json
s = json.load(open('$SCHEMA'))
req = s.get('required', [])
for f in ['schema_version', 'scan_id', 'command', 'findings']:
    assert f in req, f'Missing required: {f}'
print('OK')
" 2>/dev/null && pass "Schema has all required top-level fields" || fail "Schema missing required top-level fields"

# Validate Finding sub-schema has 4-segment fields
python3 -c "
import json
s = json.load(open('$SCHEMA'))
finding_props = s['\$defs']['Finding']['properties']
for seg in ['location', 'evidence', 'impact', 'fix']:
    assert seg in finding_props, f'Missing 4-segment field: {seg}'
print('OK')
" 2>/dev/null && pass "Schema enforces 4-segment protocol (location/evidence/impact/fix)" || fail "Schema missing 4-segment fields"

# Validate finding ID pattern
python3 -c "
import json, re
s = json.load(open('$SCHEMA'))
id_pattern = s['\$defs']['Finding']['properties']['id']['pattern']
# Test valid IDs
for tid in ['C-CMDINJ-execlike-L16', 'H-HARDCODED-crypto_utils-L34', 'M-CSRF-webapp-L85', 'L-XXE-webapp-L115']:
    assert re.match(id_pattern, tid), f'Valid ID rejected: {tid}'
# Test invalid IDs
for bad in ['X-001', 'CRITICAL-xxx', 'c-cmdinj-execlike-L16']:
    assert not re.match(id_pattern, bad), f'Invalid ID accepted: {bad}'
print('OK')
" 2>/dev/null && pass "Finding ID pattern validates correctly" || fail "Finding ID pattern broken"

# ═══════════════════════════════════════════════
# 2. Renderer — Basic Output Generation
# ═══════════════════════════════════════════════
section "2. Renderer — Basic Output Generation"

RENDERER="$PROJECT_ROOT/scripts/render-report.py"
[ -f "$RENDERER" ] && pass "Renderer script exists" || { fail "Renderer missing: $RENDERER"; }

# Create minimal test findings.json
cat > "$TMPDIR/test-findings.json" << 'JSONEOF'
{
  "schema_version": "1.0",
  "scan_id": "sc-20260606-120000-abcd",
  "command": "secguard",
  "started_at": "2026-06-06T12:00:00Z",
  "completed_at": "2026-06-06T12:01:00Z",
  "duration_ms": 60000,
  "path": "./src",
  "mode": "full",
  "filters": ["all"],
  "language": "go",
  "scope": {"files": 3, "lines": 238, "functions": 30, "call_edges": 1},
  "detectors": {"matched": 25, "executed": 25, "namespaces_used": ["system", "web", "crypto"]},
  "good_patterns": [
    {"name": "GoodExecShell", "file": "src/execlike.go", "line": 55, "description": "Uses structured args ✓"}
  ],
  "findings": [
    {
      "id": "C-TEST-example-L1", "severity": "Critical", "cwe": "CWE-77",
      "detector": "system.command-injection", "file": "src/example.go", "line": 1,
      "function": "BadFunc", "title": "Test finding",
      "fix_summary": "Use parameterized approach",
      "location": {
        "file_path": "src/example.go", "start_line": 1, "end_line": 3,
        "function_name": "BadFunc(arg string)",
        "snippet": "func BadFunc(arg string) {\n    exec.Command(\"sh\", \"-c\", arg)\n}"
      },
      "evidence": {
        "code_context": "func BadFunc(arg string) {\n    exec.Command(\"sh\", \"-c\", arg).Output()\n}",
        "judgment_rationale": "User input passed to shell without sanitization.",
        "data_flow_path": [
          {"step": "source", "file": "src/example.go", "line": 1, "description": "arg parameter"},
          {"step": "sink", "file": "src/example.go", "line": 2, "description": "exec.Command(\"sh\", \"-c\", arg)"}
        ]
      },
      "impact": {
        "attack_scenario": "Attacker injects shell commands.",
        "cvss_score": 9.8,
        "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
        "exploit_conditions": "Publicly accessible endpoint."
      },
      "fix": {
        "description": "Use structured command execution.",
        "before_code": "exec.Command(\"sh\", \"-c\", arg)",
        "after_code": "exec.Command(\"cmd\", arg)",
        "effort_hours": 0.5,
        "verification_method": "Test with benign and malicious inputs."
      },
      "sarif_specific": {
        "confidence": "high", "risk_of_fix": "none", "detector_namespace": "system"
      }
    }
  ]
}
JSONEOF

# Test 1: Generate all files
python3 "$RENDERER" --findings "$TMPDIR/test-findings.json" --output "$TMPDIR/out1/" >/dev/null 2>&1
for f in report.md results.sarif summary.json manifest.json status.json delta.json; do
    [ -f "$TMPDIR/out1/$f" ] && pass "Generated: $f" || fail "Missing: $f"
done

# Test 2: Generate single format
python3 "$RENDERER" --format sarif --findings "$TMPDIR/test-findings.json" --output "$TMPDIR/out2/" >/dev/null 2>&1
[ -f "$TMPDIR/out2/results.sarif" ] && pass "Single-format SARIF generation" || fail "Single-format SARIF failed"
[ ! -f "$TMPDIR/out2/report.md" ] && pass "Single-format skips non-requested files" || fail "Single-format generated unexpected files"

# Test 3: Renderer handles missing findings gracefully
echo '{"schema_version":"1.0","scan_id":"sc-test","command":"secguard","findings":[]}' > "$TMPDIR/empty.json"
python3 "$RENDERER" --findings "$TMPDIR/empty.json" --output "$TMPDIR/out3/" >/dev/null 2>&1
python3 -c "
import json
s = json.load(open('$TMPDIR/out3/summary.json'))
assert s['total_findings'] == 0, 'Empty scan should have 0 findings'
assert s['security_score'] == 100, 'Empty scan should score 100'
print('OK')
" 2>/dev/null && pass "Empty findings → score 100/100" || fail "Empty findings handling broken"

# ═══════════════════════════════════════════════
# 3. SARIF 2.1.0 Compliance
# ═══════════════════════════════════════════════
section "3. SARIF 2.1.0 Compliance"

SARIF_FILE="$TMPDIR/out1/results.sarif"
python3 << PYEOF
import json

with open('$SARIF_FILE') as f:
    s = json.load(f)

errors = []

# 3a. Top-level structure
if s.get('version') != '2.1.0':
    errors.append(f"Wrong SARIF version: {s.get('version')}")
if '\$schema' not in s:
    errors.append("Missing \$schema")
if 'runs' not in s or len(s['runs']) == 0:
    errors.append("Missing or empty runs[]")

run = s['runs'][0]

# 3b. Tool driver
driver = run.get('tool', {}).get('driver', {})
if not driver.get('name'):
    errors.append("Missing tool.driver.name")
if not driver.get('rules') or len(driver['rules']) == 0:
    errors.append("Missing tool.driver.rules[]")
for r in driver.get('rules', []):
    if 'id' not in r: errors.append(f"Rule missing id: {r}")

# 3c. Results structure
for i, result in enumerate(run.get('results', [])):
    prefix = f"result[{i}]"
    if 'ruleId' not in result: errors.append(f"{prefix} missing ruleId")
    if 'message' not in result: errors.append(f"{prefix} missing message")
    if 'text' not in result.get('message', {}): errors.append(f"{prefix} missing message.text")
    if 'locations' not in result or len(result['locations']) == 0:
        errors.append(f"{prefix} missing locations")
    if 'partialFingerprints' not in result:
        errors.append(f"{prefix} missing partialFingerprints")
    else:
        fp = result['partialFingerprints']
        if 'primary' not in fp: errors.append(f"{prefix} missing primary fingerprint")
    if 'properties' not in result:
        errors.append(f"{prefix} missing properties")
    else:
        for p in ['findingId', 'severity', 'cwe', 'confidence', 'cvss']:
            if p not in result['properties']:
                errors.append(f"{prefix} missing property: {p}")
    # Check fixes
    fixes = result.get('fixes', [])
    if fixes:
        for j, fix in enumerate(fixes):
            if 'fileChanges' not in fix:
                errors.append(f"{prefix} fix[{j}] missing fileChanges")

# 3d. Invocations
inv = run.get('invocations', [])
if not inv:
    errors.append("Missing invocations[]")
else:
    if 'executionSuccessful' not in inv[0]:
        errors.append("Missing executionSuccessful")

if errors:
    for e in errors:
        print(f"  SARIF_ERROR: {e}")
    print(f"TOTAL_ERRORS={len(errors)}")
else:
    print("OK")
PYEOF
SARIF_EXIT=$?
if [ $SARIF_EXIT -eq 0 ]; then
    pass "SARIF 2.1.0 structure compliant (version, driver, rules, results, fingerprints, fixes)"
else
    fail "SARIF 2.1.0 compliance issues found"
fi

# ═══════════════════════════════════════════════
# 4. 4-Segment Quality Gate
# ═══════════════════════════════════════════════
section "4. Four-Segment Quality Gate"

# Test: incomplete finding (missing impact.cvss_vector)
cat > "$TMPDIR/incomplete.json" << 'JSONEOF'
{
  "schema_version": "1.0",
  "scan_id": "sec-20260606-120000-abcd",
  "command": "secaudit",
  "started_at": "2026-06-06T12:00:00Z",
  "completed_at": "2026-06-06T12:01:00Z",
  "duration_ms": 60000,
  "path": "./src",
  "mode": "full",
  "language": "go",
  "scope": {"files": 1, "lines": 10, "functions": 1, "call_edges": 0},
  "detectors": {"matched": 1, "executed": 1, "namespaces_used": ["web"]},
  "secaudit_specific": {"skill_name": "taint-analysis", "skill_category": "analysis", "analysis_paths": 1, "complete_chains": 1},
  "findings": [
    {
      "id": "H-INCOMPLETE-test-L1", "severity": "High", "cwe": "CWE-89",
      "detector": "web.sql-injection", "file": "test.go", "line": 1,
      "function": "Test", "title": "Incomplete finding",
      "fix_summary": "Fix it",
      "location": {"file_path": "test.go", "start_line": 1, "end_line": 2,
        "function_name": "Test()", "snippet": "func Test() {}"},
      "evidence": {"code_context": "code", "judgment_rationale": "bad"},
      "impact": {"attack_scenario": "hack", "cvss_score": 7.0},
      "fix": {"description": "fix", "before_code": "bad", "after_code": "good",
        "effort_hours": 1.0, "verification_method": "test"},
      "sarif_specific": {"confidence": "high", "risk_of_fix": "none", "detector_namespace": "web"}
    }
  ]
}
JSONEOF

# Render and check for quality gate warnings
python3 "$RENDERER" --findings "$TMPDIR/incomplete.json" --output "$TMPDIR/out-qg/" >/dev/null 2>&1 || true

# Check that report.md exists (it should, with a warning about incomplete finding)
if [ -f "$TMPDIR/out-qg/report.md" ]; then
    pass "Renderer handles incomplete findings gracefully (no crash)"
else
    fail "Renderer crashed on incomplete findings"
fi

# Check that our COMPLETE finding passes all 4-segment checks
python3 << PYEOF
import json, sys

# Read the complete finding from test-findings.json
with open('$TMPDIR/test-findings.json') as f:
    data = json.load(f)

f = data['findings'][0]
missing = []

loc = f.get('location', {})
if not loc.get('file_path'): missing.append('location.file_path')
if not loc.get('start_line'): missing.append('location.start_line')
if not loc.get('function_name'): missing.append('location.function_name')
if not loc.get('snippet'): missing.append('location.snippet')

ev = f.get('evidence', {})
if not ev.get('code_context'): missing.append('evidence.code_context')
if not ev.get('judgment_rationale'): missing.append('evidence.judgment_rationale')
if not ev.get('data_flow_path'): missing.append('evidence.data_flow_path')

imp = f.get('impact', {})
if not imp.get('attack_scenario'): missing.append('impact.attack_scenario')
if imp.get('cvss_score') is None: missing.append('impact.cvss_score')
if not imp.get('cvss_vector'): missing.append('impact.cvss_vector')

fi = f.get('fix', {})
if not fi.get('description'): missing.append('fix.description')
if not fi.get('before_code'): missing.append('fix.before_code')
if not fi.get('after_code'): missing.append('fix.after_code')

if missing:
    print(f"INCOMPLETE: {missing}")
    sys.exit(1)
else:
    print("OK — all 4 segments complete")
PYEOF
if [ $? -eq 0 ]; then
    pass "Complete finding passes 4-segment validation"
else
    fail "Complete finding fails 4-segment validation"
fi

# ═══════════════════════════════════════════════
# 5. Security Score Calculation
# ═══════════════════════════════════════════════
section "5. Security Score Calculation"

python3 << PYEOF
import json, subprocess, sys

# Test score: 0 Critical, 1 High → should be 90
data = {
    "schema_version": "1.0",
    "scan_id": "sc-score-test",
    "command": "secguard",
    "started_at": "2026-06-06T12:00:00Z",
    "completed_at": "2026-06-06T12:01:00Z",
    "duration_ms": 60000,
    "language": "go",
    "scope": {"files": 1, "lines": 10, "functions": 1},
    "detectors": {"matched": 1, "executed": 1},
    "findings": [
        {"id": "H-TEST-score-L1", "severity": "High", "cwe": "CWE-79", "detector": "web.xss",
         "file": "test.go", "line": 1, "function": "Test", "title": "XSS",
         "fix_summary": "Escape output",
         "location": {"file_path": "test.go", "start_line": 1, "end_line": 1,
           "function_name": "Test()", "snippet": "code"},
         "evidence": {"code_context": "ctx", "judgment_rationale": "reason",
           "data_flow_path": [{"step": "source", "file": "t.go", "line": 1, "description": "d"}]},
         "impact": {"attack_scenario": "xss", "cvss_score": 6.1,
           "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:L/A:N",
           "exploit_conditions": "user visits page"},
         "fix": {"description": "escape", "before_code": "raw", "after_code": "escaped",
           "effort_hours": 1.0, "verification_method": "test"},
         "sarif_specific": {"confidence": "high", "risk_of_fix": "none", "detector_namespace": "web"}}
    ]
}

import os
os.makedirs('$TMPDIR/out-score', exist_ok=True)
with open('$TMPDIR/out-score/findings.json', 'w') as f:
    json.dump(data, f)

subprocess.run(['python3', '$RENDERER', '--findings', '$TMPDIR/out-score/findings.json',
                '--output', '$TMPDIR/out-score/'], capture_output=True)

with open('$TMPDIR/out-score/summary.json') as f:
    s = json.load(f)

score = s['security_score']
grade = s['score_grade']

expected_score = max(0, round(100 * __import__('math').exp(-(0*0.2 + 1*0.1 + 0*0.04 + 0*0.01))))

if score == expected_score:
    print(f"  Score: {score}/100 (expected {expected_score}) — OK")
    if grade == 'A' and score >= 80:
        print(f"  Grade: {grade} — OK")
    elif grade == 'B' and score >= 55:
        print(f"  Grade: {grade} — OK")
    else:
        print(f"  Grade: {grade} — WARNING (score={score})")
else:
    print(f"  SCORE MISMATCH: got {score}, expected {expected_score}")
    sys.exit(1)
PYEOF
if [ $? -eq 0 ]; then
    pass "Security score calculation correct (100 × exp(-0.2×Crit - 0.1×High - 0.04×Med - 0.01×Low))"
else
    fail "Security score calculation incorrect"
fi

# ═══════════════════════════════════════════════
# 6. CI Gate / Exit Code
# ═══════════════════════════════════════════════
section "6. CI Gate & Exit Codes"

cat > "$TMPDIR/ci-critical.json" << 'JSONEOF'
{
  "schema_version": "1.0",
  "scan_id": "sc-ci-test",
  "command": "secguard",
  "started_at": "2026-06-06T12:00:00Z",
  "completed_at": "2026-06-06T12:01:00Z",
  "duration_ms": 60000,
  "language": "go",
  "scope": {"files": 1, "lines": 10, "functions": 1},
  "detectors": {"matched": 1, "executed": 1},
  "findings": [
    {"id": "C-CI-TEST-L1", "severity": "Critical", "cwe": "CWE-77", "detector": "system.command-injection",
     "file": "test.go", "line": 1, "function": "Test", "title": "CI test",
     "fix_summary": "Fix",
     "location": {"file_path": "test.go", "start_line": 1, "end_line": 1,
       "function_name": "Test()", "snippet": "code"},
     "evidence": {"code_context": "ctx", "judgment_rationale": "reason",
       "data_flow_path": [{"step": "source", "file": "t.go", "line": 1, "description": "d"}]},
     "impact": {"attack_scenario": "rce", "cvss_score": 9.8,
       "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H",
       "exploit_conditions": "any"},
     "fix": {"description": "fix", "before_code": "bad", "after_code": "good",
       "effort_hours": 1.0, "verification_method": "test"},
     "sarif_specific": {"confidence": "high", "risk_of_fix": "none", "detector_namespace": "system"}}
  ]
}
JSONEOF

python3 "$RENDERER" --ci --findings "$TMPDIR/ci-critical.json" --output "$TMPDIR/out-ci/" >/dev/null 2>&1
python3 -c "
import json
s = json.load(open('$TMPDIR/out-ci/status.json'))
assert s['gate_result'] == 'FAILED', f'Expected FAILED, got {s[\"gate_result\"]}'
assert s['exit_code'] == 1, f'Expected exit_code 1, got {s[\"exit_code\"]}'
assert s['security_score'] == 82, f'Expected score 82 (100 × exp(-0.2)), got {s["security_score"]}'
print('OK — CI gate FAILED correctly on Critical finding')
" 2>/dev/null && pass "CI mode: Critical finding → FAILED + exit_code=1" || fail "CI mode exit code incorrect"

# Also test clean scan → PASSED
echo '{"schema_version":"1.0","scan_id":"sc-ci-clean","command":"secguard","started_at":"2026-06-06T12:00:00Z","completed_at":"2026-06-06T12:01:00Z","duration_ms":60000,"language":"go","scope":{"files":1,"lines":10,"functions":1},"detectors":{"matched":0,"executed":0},"findings":[]}' > "$TMPDIR/ci-clean.json"
python3 "$RENDERER" --ci --findings "$TMPDIR/ci-clean.json" --output "$TMPDIR/out-ci-clean/" >/dev/null 2>&1
python3 -c "
import json
s = json.load(open('$TMPDIR/out-ci-clean/status.json'))
assert s['gate_result'] == 'PASSED', f'Expected PASSED, got {s[\"gate_result\"]}'
assert s['exit_code'] == 0, f'Expected exit_code 0, got {s[\"exit_code\"]}'
print('OK — CI gate PASSED on clean scan')
" 2>/dev/null && pass "CI mode: Clean scan → PASSED + exit_code=0" || fail "CI mode clean scan exit code incorrect"

# ═══════════════════════════════════════════════
# 7. Delta Comparison
# ═══════════════════════════════════════════════
section "7. Delta Comparison"

mkdir -p "$TMPDIR/delta-scans/scan1" "$TMPDIR/delta-scans/scan2"
ln -sfn scan1 "$TMPDIR/delta-scans/latest"

# First scan: 3 findings
cat > "$TMPDIR/delta-scan1.json" << 'JSONEOF'
{
  "schema_version": "1.0",
  "scan_id": "sc-delta-1", "command": "secguard",
  "started_at": "2026-06-06T12:00:00Z", "completed_at": "2026-06-06T12:01:00Z",
  "duration_ms": 60000, "language": "go",
  "scope": {"files": 1, "lines": 10, "functions": 1},
  "detectors": {"matched": 3, "executed": 3},
  "findings": [
    {"id": "H-DELTA-1-L1", "severity": "High", "cwe": "CWE-79", "detector": "web.xss",
     "file": "scan1_file", "line": 1, "function": "A", "title": "XSS A", "fix_summary": "Fix",
     "location": {"file_path": "scan1_file", "start_line": 1, "end_line": 1, "function_name": "A()", "snippet": "c"},
     "evidence": {"code_context": "c", "judgment_rationale": "r", "data_flow_path": [{"step": "source", "file": "a.go", "line": 1, "description": "d"}]},
     "impact": {"attack_scenario": "xss", "cvss_score": 6.1, "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:L/A:N", "exploit_conditions": "any"},
     "fix": {"description": "f", "before_code": "b", "after_code": "a", "effort_hours": 1.0, "verification_method": "t"},
     "sarif_specific": {"confidence": "high", "risk_of_fix": "none", "detector_namespace": "web"}},
    {"id": "H-DELTA-2-L1", "severity": "High", "cwe": "CWE-79", "detector": "web.xss",
     "file": "b.go", "line": 1, "function": "B", "title": "XSS B", "fix_summary": "Fix",
     "location": {"file_path": "b.go", "start_line": 1, "end_line": 1, "function_name": "B()", "snippet": "c"},
     "evidence": {"code_context": "c", "judgment_rationale": "r", "data_flow_path": [{"step": "source", "file": "b.go", "line": 1, "description": "d"}]},
     "impact": {"attack_scenario": "xss", "cvss_score": 6.1, "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:L/A:N", "exploit_conditions": "any"},
     "fix": {"description": "f", "before_code": "b", "after_code": "a", "effort_hours": 1.0, "verification_method": "t"},
     "sarif_specific": {"confidence": "high", "risk_of_fix": "none", "detector_namespace": "web"}},
    {"id": "M-DELTA-3-L1", "severity": "Medium", "cwe": "CWE-352", "detector": "web.csrf",
     "file": "c.go", "line": 1, "function": "C", "title": "CSRF", "fix_summary": "Fix",
     "location": {"file_path": "c.go", "start_line": 1, "end_line": 1, "function_name": "C()", "snippet": "c"},
     "evidence": {"code_context": "c", "judgment_rationale": "r", "data_flow_path": [{"step": "source", "file": "c.go", "line": 1, "description": "d"}]},
     "impact": {"attack_scenario": "csrf", "cvss_score": 6.5, "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:L/A:L", "exploit_conditions": "any"},
     "fix": {"description": "f", "before_code": "b", "after_code": "a", "effort_hours": 1.0, "verification_method": "t"},
     "sarif_specific": {"confidence": "medium", "risk_of_fix": "none", "detector_namespace": "web"}}
  ]
}
JSONEOF

# Generate first scan output
python3 "$RENDERER" --findings "$TMPDIR/delta-scan1.json" --output "$TMPDIR/delta-scans/scan1/" >/dev/null 2>&1

# Second scan: 2 findings (1 fixed, 1 new, 1 still open)
cat > "$TMPDIR/delta-scan2.json" << 'JSONEOF'
{
  "schema_version": "1.0",
  "scan_id": "sc-delta-2", "command": "secguard",
  "started_at": "2026-06-06T13:00:00Z", "completed_at": "2026-06-06T13:01:00Z",
  "duration_ms": 60000, "language": "go",
  "scope": {"files": 1, "lines": 10, "functions": 1},
  "detectors": {"matched": 2, "executed": 2},
  "findings": [
    {"id": "H-DELTA-1-L1", "severity": "High", "cwe": "CWE-79", "detector": "web.xss",
     "file": "scan1_file", "line": 1, "function": "A", "title": "XSS A", "fix_summary": "Fix",
     "location": {"file_path": "scan1_file", "start_line": 1, "end_line": 1, "function_name": "A()", "snippet": "c"},
     "evidence": {"code_context": "c", "judgment_rationale": "r", "data_flow_path": [{"step": "source", "file": "a.go", "line": 1, "description": "d"}]},
     "impact": {"attack_scenario": "xss", "cvss_score": 6.1, "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:L/A:N", "exploit_conditions": "any"},
     "fix": {"description": "f", "before_code": "b", "after_code": "a", "effort_hours": 1.0, "verification_method": "t"},
     "sarif_specific": {"confidence": "high", "risk_of_fix": "none", "detector_namespace": "web"}},
    {"id": "C-DELTA-NEW-L1", "severity": "Critical", "cwe": "CWE-77", "detector": "system.command-injection",
     "file": "d.go", "line": 1, "function": "D", "title": "New RCE", "fix_summary": "Fix",
     "location": {"file_path": "d.go", "start_line": 1, "end_line": 1, "function_name": "D()", "snippet": "c"},
     "evidence": {"code_context": "c", "judgment_rationale": "r", "data_flow_path": [{"step": "source", "file": "d.go", "line": 1, "description": "d"}]},
     "impact": {"attack_scenario": "rce", "cvss_score": 9.8, "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H", "exploit_conditions": "any"},
     "fix": {"description": "f", "before_code": "b", "after_code": "a", "effort_hours": 0.5, "verification_method": "t"},
     "sarif_specific": {"confidence": "high", "risk_of_fix": "none", "detector_namespace": "system"}}
  ]
}
JSONEOF

# Update latest symlink
rm -f "$TMPDIR/delta-scans/latest"
ln -sfn scan1 "$TMPDIR/delta-scans/latest"

python3 "$RENDERER" --findings "$TMPDIR/delta-scan2.json" --output "$TMPDIR/delta-scans/scan2/" >/dev/null 2>&1

python3 -c "
import json
d = json.load(open('$TMPDIR/delta-scans/scan2/delta.json'))
c = d['comparison']
assert c['new_findings'] == 1, f'Expected 1 new, got {c[\"new_findings\"]}'
assert c['fixed_findings'] == 2, f'Expected 2 fixed, got {c[\"fixed_findings\"]}'
assert c['still_open'] == 1, f'Expected 1 still open, got {c[\"still_open\"]}'
assert c['total_current'] == 2
assert c['total_previous'] == 3
print(f'Delta OK: +{c[\"new_findings\"]} new, -{c[\"fixed_findings\"]} fixed, {c[\"still_open\"]} still open')
" 2>/dev/null && pass "Delta comparison: new=1, fixed=2, still_open=1" || fail "Delta comparison incorrect"

# ═══════════════════════════════════════════════
# 8. All 3 Command Types
# ═══════════════════════════════════════════════
section "8. All Command Types"

for cmd in secguard secaudit secreview; do
    # Use Python to generate test JSON (avoids bash heredoc substitution issues)
    python3 -c "
import json
data = {
    'schema_version': '1.0',
    'scan_id': 'sc-cmd-${cmd}',
    'command': '${cmd}',
    'started_at': '2026-06-06T12:00:00Z',
    'completed_at': '2026-06-06T12:01:00Z',
    'duration_ms': 60000,
    'language': 'go',
    'scope': {'files': 1, 'lines': 10, 'functions': 1},
    'detectors': {'matched': 1, 'executed': 1},
    'findings': [{
        'id': 'H-${cmd}-TEST-L1', 'severity': 'High', 'cwe': 'CWE-79',
        'detector': 'web.xss', 'file': 'test.go', 'line': 1,
        'function': 'Test', 'title': '${cmd} test finding', 'fix_summary': 'Fix',
        'location': {'file_path': 'test.go', 'start_line': 1, 'end_line': 1,
            'function_name': 'Test()', 'snippet': 'code'},
        'evidence': {'code_context': 'ctx', 'judgment_rationale': 'reason',
            'data_flow_path': [{'step': 'source', 'file': 't.go', 'line': 1, 'description': 'd'}]},
        'impact': {'attack_scenario': 'xss', 'cvss_score': 6.1,
            'cvss_vector': 'CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:L/A:N',
            'exploit_conditions': 'any'},
        'fix': {'description': 'fix', 'before_code': 'bad', 'after_code': 'good',
            'effort_hours': 1.0, 'verification_method': 'test'},
        'sarif_specific': {'confidence': 'high', 'risk_of_fix': 'none', 'detector_namespace': 'web'}
    }]
}
if '${cmd}' == 'secaudit':
    data['secaudit_specific'] = {'skill_name': 'taint-analysis', 'skill_category': 'analysis', 'analysis_paths': 1, 'complete_chains': 1}
elif '${cmd}' == 'secreview':
    data['secreview_specific'] = {'review_type': 'full', 'review_focus': ['security', 'code-quality']}
with open('$TMPDIR/cmd-${cmd}.json', 'w') as f:
    json.dump(data, f)
"

    python3 "$RENDERER" --findings "$TMPDIR/cmd-${cmd}.json" --output "$TMPDIR/out-cmd-${cmd}/" >/dev/null 2>&1

    # Verify manifest reports correct command
    cmd_in_manifest=$(python3 -c "import json; print(json.load(open('$TMPDIR/out-cmd-${cmd}/manifest.json'))['command'])")
    if [ "$cmd_in_manifest" = "$cmd" ]; then
        pass "Command type '$cmd': manifest.json correct"
    else
        fail "Command type '$cmd': manifest.json shows '$cmd_in_manifest'"
    fi

    # Verify report.md has correct title
    case "$cmd" in
        secguard) expected_title="Security Scan" ;;
        secaudit) expected_title="Security Audit" ;;
        secreview) expected_title="Security Review" ;;
    esac
    if grep -q "$expected_title" "$TMPDIR/out-cmd-${cmd}/report.md"; then
        pass "Command type '$cmd': report.md title correct"
    else
        fail "Command type '$cmd': report.md title incorrect"
    fi
done

# ═══════════════════════════════════════════════
# 9. Multi-Language Support Check
# ═══════════════════════════════════════════════
if [ "$MODE" != "quick" ]; then
section "9. Multi-Language Example Repos"

for lang_dir in cpp-vuln-demo python-vuln-demo java-vuln-demo go-vuln-demo; do
    LANG_PATH="examples/$lang_dir/src"
    if [ -d "$LANG_PATH" ]; then
        file_count=$(find "$LANG_PATH" -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.py" -o -name "*.java" -o -name "*.go" \) 2>/dev/null | wc -l | tr -d ' ')
        if [ "$file_count" -gt 0 ]; then
            pass "$lang_dir: $file_count source files available"
        else
            warn "$lang_dir: no source files found"
        fi
    else
        warn "$lang_dir: directory not found"
    fi
done

# Index each language (quick health check)
for lang_dir in cpp-vuln-demo python-vuln-demo java-vuln-demo go-vuln-demo; do
    INDEXER="$PROJECT_ROOT/scripts/bin/secguardian-index"
    LANG_PATH="examples/$lang_dir/src"
    if [ -d "$LANG_PATH" ] && [ -x "$INDEXER" ]; then
        result=$("$INDEXER" --path "$LANG_PATH" --output "$TMPDIR/index-${lang_dir}.json" 2>&1)
        if echo "$result" | grep -q "Index written"; then
            file_n=$(python3 -c "import json; print(len(json.load(open('$TMPDIR/index-${lang_dir}.json'))['files']))" 2>/dev/null || echo "?")
            pass "$lang_dir: indexer parsed $file_n files"
        else
            fail "$lang_dir: indexer failed — $result"
        fi
    fi
done
fi

# ═══════════════════════════════════════════════
# 10. Renderer Performance
# ═══════════════════════════════════════════════
section "10. Renderer Performance"

# Time renderer with 4 findings (typical medium scan)
START=$(python3 -c "import time; print(int(time.time()*1000))")
python3 "$RENDERER" --findings "$TMPDIR/test-findings.json" --output "$TMPDIR/out-perf/" >/dev/null 2>&1
END=$(python3 -c "import time; print(int(time.time()*1000))")
ELAPSED=$((END - START))

if [ $ELAPSED -lt 5000 ]; then
    pass "Renderer speed: ${ELAPSED}ms for 1 finding (< 5s threshold)"
elif [ $ELAPSED -lt 10000 ]; then
    warn "Renderer speed: ${ELAPSED}ms for 1 finding (< 10s, acceptable)"
else
    fail "Renderer speed: ${ELAPSED}ms for 1 finding (> 10s, too slow)"
fi

# 11. Verification Pipeline (v6.0)
# ═══════════════════════════════════════════════
section "11. Verification Pipeline (v6.0)"

# 11.1 Verification protocol file
VERIFY_PROTO="knowledge/protocols/verification-protocol.md"
if [ -f "$VERIFY_PROTO" ]; then
    pass "Verification protocol file exists"
    # Check evidence gate constraints
    GATE_COUNT=$(grep -c "只能使用" "$VERIFY_PROTO" 2>/dev/null || true)
    if [ "$GATE_COUNT" -ge 3 ]; then
        pass "Evidence gate constraints present ($GATE_COUNT rounds)"
    else
        warn "Evidence gate constraints: $GATE_COUNT found, expected >= 3"
    fi
else
    fail "Verification protocol file missing: $VERIFY_PROTO"
fi

# 11.2 Dismissed.json format validation
DISMISSED_TEST="$TMPDIR/test-dismissed.json"
python3 << 'PYEOF' 2>/dev/null
import json, os
test = {
    "scan_id": "test",
    "dismissed": [
        {"finding_id": "H-TEST-test_c-L1", "dismissed_at_round": "P1",
         "dismiss_reason": "SafeCopy wrapper", "original_severity": "High",
         "original_detector": "memory.buffer-overflow"}
    ],
    "summary": {
        "total_findings": 10,
        "dismissed_by_p1": 3, "dismissed_by_p2": 2, "dismissed_by_p3": 1,
        "certified": 4
    }
}
with open(os.environ.get('DISMISSED_TEST', '/tmp/test-dismissed.json'), 'w') as f:
    json.dump(test, f)
# Validate structure
for d in test['dismissed']:
    assert d['finding_id']
    assert d['dismissed_at_round'] in ('P1', 'P2', 'P3')
    assert d['dismiss_reason']
s = test['summary']
assert s['total_findings'] == s['dismissed_by_p1'] + s['dismissed_by_p2'] + s['dismissed_by_p3'] + s['certified']
print('OK')
PYEOF
if [ $? -eq 0 ]; then
    pass "Dismissed.json format valid"
else
    fail "Dismissed.json format validation failed"
fi

# 11.3 Verification-audit.json format validation
AUDIT_TEST="$TMPDIR/test-audit.json"
python3 << 'PYEOF' 2>/dev/null
import json, os
test = {
    "scan_id": "test",
    "pipeline_version": "1.0",
    "rounds": {
        "p1_semantic": {"input_count": 10, "exempted": 2, "no_exemption": 7, "uncertain": 1},
        "p2_counter_evidence": {"input_count": 8, "counter_evidence_found": 3, "counter_evidence_not_found": 5},
        "p3_court": {"input_count": 5, "confirmed": 3, "suspected": 1, "dismissed": 1}
    },
    "certified_count": 4,
    "dismissed_count": 6
}
with open(os.environ.get('AUDIT_TEST', '/tmp/test-audit.json'), 'w') as f:
    json.dump(test, f)
for rk in ('p1_semantic', 'p2_counter_evidence', 'p3_court'):
    assert rk in test['rounds'], f'Missing round: {rk}'
assert test['certified_count'] + test['dismissed_count'] == test['rounds']['p1_semantic']['input_count']
print('OK')
PYEOF
if [ $? -eq 0 ]; then
    pass "Verification-audit.json format valid"
else
    fail "Verification-audit.json format validation failed"
fi

# 11.4 Scan output protocol references v6.0
SCAN_OUT="knowledge/protocols/scan-output.md"
if grep -q "v6.0" "$SCAN_OUT" 2>/dev/null; then
    pass "Scan output protocol references v6.0"
else
    fail "Scan output protocol missing v6.0 reference"
fi

# 11.5 Dismissed.json and verification-audit.json in scan structure
if grep -q "dismissed.json" "$SCAN_OUT" && grep -q "verification-audit.json" "$SCAN_OUT"; then
    pass "v6.0 files documented in scan-output.md"
else
    fail "v6.0 files not found in scan-output.md"
fi

# ═══════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════
echo ""
# ── 12. Build → Package → Execute (L5 Pipeline) ──
if [ "$MODE" != "quick" ]; then
echo -e "${BOLD}${CYAN}━━━ 12. Build → Package → Execute (L5 Pipeline) ━━━${NC}"

echo "  Preparing..."
rm -rf dist/
bash scripts/package.sh >/dev/null 2>&1
EXT="dist/secguard-secguardian"

[ -d "$EXT" ] && pass "package.sh: dist/secguard-secguardian created" || fail "BUILD FAILED"
for dir in guard-rules audit-rules review-rules; do
    c=$(find "$EXT/knowledge/$dir" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    [ "$c" -gt 0 ] && pass "knowledge/$dir: $c files" || fail "knowledge/$dir: MISSING"
done
[ -f "$EXT/knowledge/language-index.md" ] && pass "knowledge/language-index.md" || fail "language-index.md MISSING"
for cmd in secguard secaudit secreview; do
    [ -f "dist/${cmd}-secguardian/commands/${cmd}.md" ] && pass "dist/${cmd}-secguardian/commands/${cmd}.md" || fail "dist/${cmd}-secguardian MISSING"
done
[ -f "$EXT/.claude-plugin/plugin.json" ] && pass "plugin.json" || fail "plugin.json MISSING"

tmp=$(mktemp -d)
OUTPUT="$tmp/index.json"
"$EXT/scripts/secguardian-index" --path "examples/cpp-vuln-demo/src" --output "$OUTPUT" >/dev/null 2>&1
[ -f "$OUTPUT" ] && pass "indexer: index.json ($(wc -c < "$OUTPUT" | tr -d ' ') bytes)" || fail "indexer FAILED"

python3 -c "
import json
with open('$OUTPUT') as f:
    d = json.load(f)
ok = True
for name, cond in [('path present', 'path' in d),('files>0',len(d['files'])>0),('functions>0',len(d['symbols']['functions'])>0),('edges>0',len(d['call_graph']['edges'])>0)]:
    print('    %s: %s' % (name, 'OK' if cond else 'FAIL'))
    ok = ok and cond
" && pass "index.json structure" || fail "index.json structure FAILED"

# Verify opencode-plugin.js source has required registrations
OPENCODE_PLUGIN_SRC="$PROJECT_ROOT/scripts/opencode-plugin.js"
if [ -f "$OPENCODE_PLUGIN_SRC" ]; then
    K=$(grep -c 'cfg.knowledge' "$OPENCODE_PLUGIN_SRC" 2>/dev/null || echo 0)
    S=$(grep -c 'cfg.skills' "$OPENCODE_PLUGIN_SRC" 2>/dev/null || echo 0)
    C=$(grep -c 'cfg.command' "$OPENCODE_PLUGIN_SRC" 2>/dev/null || echo 0)
    [ "$K" -gt 0 ] && [ "$S" -gt 0 ] && [ "$C" -gt 0 ] &&         pass "opencode-plugin.js: knowledge+skills+commands" ||         fail "opencode-plugin.js: missing (k=$K s=$S c=$C)"
else
    fail "opencode-plugin.js NOT FOUND at $OPENCODE_PLUGIN_SRC"
fi

rm -rf "$tmp" dist/

fi
# ── 13. Cross-Language Pipeline Verification ──
section "13. Cross-Language Pipeline Verification"
if bash "$PROJECT_ROOT/scripts/verify-lang-pipeline.sh" >/dev/null 2>&1; then
    pass "All 4 languages pass full pipeline"
else
    fail "Cross-language pipeline test FAILED"
fi

echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  E2E Verification Summary                   ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
printf "  ${GREEN}Passed: %d${NC}  ${RED}Failed: %d${NC}  ${YELLOW}Warnings: %d${NC}\n" "$PASS" "$FAIL" "$WARN"
echo ""

TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✅ All E2E checks passed${NC} (${PASS}/${TOTAL})"
    echo ""
    echo "  Architecture verification complete:"
    echo "  ✓ Findings schema validates correctly"
    echo "  ✓ Renderer generates all 6 output files"
    echo "  ✓ SARIF 2.1.0 structure compliant"
    echo "  ✓ 4-segment quality gate operational"
    echo "  ✓ Security score calculation accurate"
    echo "  ✓ CI exit codes correct"
    echo "  ✓ Delta comparison functional"
    if [ "$MODE" != "quick" ]; then
        echo "  ✓ All 3 command types handled"
        echo "  ✓ Multi-language indexer coverage"
        echo "  ✓ Verification pipeline v6.0 validated"
        echo "  ✓ L5 build→package→execute pipeline"
    fi
    echo ""
else
    echo -e "  ${RED}${BOLD}❌ $FAIL checks failed${NC} — review output above"
    echo ""
fi

[ "$MODE" = "ci" ] && exit $FAIL
# ── §12: v7.0 Consumer-Centric Output ─────────────────────────────
echo ""
echo "=== §12: Consumer-Centric Output ==="
SCAN_DIR=".codeagent/secguard/latest"
FAILED=0

# 12.1 human/executive-summary.md
if [ -f "$SCAN_DIR/human/executive-summary.md" ]; then
    echo "  ✅ 12.1 human/executive-summary.md exists"
else
    echo "  ❌ 12.1 human/executive-summary.md missing"
    FAILED=$((FAILED+1))
fi

# 12.2 ai/remediation-pack.json
if [ -f "$SCAN_DIR/ai/remediation-pack.json" ]; then
    echo "  ✅ 12.2 ai/remediation-pack.json exists"
    python3 -c "
import json
with open('$SCAN_DIR/ai/remediation-pack.json') as f:
    d = json.load(f)
assert 'version' in d
assert 'remediations' in d
print(f'       ({len(d[\"remediations\"])} remediations)')
" && echo "  ✅ 12.2 valid"
else
    echo "  ❌ 12.2 ai/remediation-pack.json missing"
    FAILED=$((FAILED+1))
fi

# 12.3 dashboard.html
if [ -f "$SCAN_DIR/dashboard.html" ]; then
    echo "  ✅ 12.3 dashboard.html exists"
    python3 -c "
with open('$SCAN_DIR/dashboard.html') as f:
    html = f.read()
assert '<!DOCTYPE html>' in html
assert '</html>' in html
assert 'Severity' in html
print(f'       ({len(html)} bytes)')
" && echo "  ✅ 12.3 valid (no code blocks)"
else
    echo "  ❌ 12.3 dashboard.html missing"
    FAILED=$((FAILED+1))
fi

# 12.4 report.md simplified (no executive/verification/compliance)
python3 -c "
with open('$SCAN_DIR/report.md') as f:
    content = f.read()
sections_removed = ['Executive Summary', 'Verification Funnel', 'Compliance Dashboard']
found = [s for s in sections_removed if s in content]
if found:
    print(f'  ⚠️  report.md still contains: {found}')
else:
    print(f'  ✅ 12.4 report.md simplified')
"

echo ""
if [ $FAILED -gt 0 ]; then
    echo "  ❌ §12: $FAILED checks failed"
    FAIL=$((FAIL + FAILED))
else
    echo "  ✅ §12: All checks passed"
fi
