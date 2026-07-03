#!/bin/bash
# SecGuardian — CWE Coverage Verification
# Automatically scans all 67 detectors for CWE tags and reports coverage.
# Usage: bash scripts/cwe-coverage.sh [--ci] [--json]
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

python3 << 'PYEOF'
import os, re, json, sys
from collections import defaultdict

DETECTOR_DIR = "knowledge/detectors"

# CWE Top 25 Most Dangerous (2024)
CWE_TOP25 = {
    "CWE-79": "Cross-site Scripting (XSS)",
    "CWE-787": "Out-of-bounds Write",
    "CWE-89": "SQL Injection",
    "CWE-352": "Cross-Site Request Forgery (CSRF)",
    "CWE-22": "Path Traversal",
    "CWE-125": "Out-of-bounds Read",
    "CWE-78": "OS Command Injection",
    "CWE-416": "Use After Free",
    "CWE-862": "Missing Authorization",
    "CWE-434": "Unrestricted File Upload",
    "CWE-94": "Code Injection",
    "CWE-20": "Improper Input Validation",
    "CWE-77": "Command Injection",
    "CWE-287": "Improper Authentication",
    "CWE-476": "NULL Pointer Dereference",
    "CWE-798": "Hardcoded Credentials",
    "CWE-119": "Buffer Overflow (generic)",
    "CWE-502": "Deserialization of Untrusted Data",
    "CWE-190": "Integer Overflow",
    "CWE-918": "Server-Side Request Forgery (SSRF)",
    "CWE-306": "Missing Authentication",
    "CWE-362": "Race Condition",
    "CWE-400": "Uncontrolled Resource Consumption",
    "CWE-611": "XXE",
    "CWE-276": "Incorrect Default Permissions",
}

# OWASP Top 10 (2021)
OWASP_TOP10 = {
    "A01: Broken Access Control": ["auth-bypass", "idor", "missing-authorization", "csrf"],
    "A02: Cryptographic Failures": ["weak-crypto-algorithm", "hardcoded-secrets", "weak-random",
        "insufficient-key-length", "password-storage", "hardcoded-iv", "custom-crypto", "tls-version", "aes-ecb-mode"],
    "A03: Injection": ["xss", "sql-injection", "code-injection", "command-injection", "nosql-injection", "ssti"],
    "A04: Insecure Design": ["SECAUDIT: design-review"],
    "A05: Security Misconfiguration": ["debug-mode-production", "http-security-headers",
        "insecure-permissions", "insecure-temp-file"],
    "A06: Vulnerable Components": ["SECAUDIT: dependency-security"],
    "A07: Identification and Authentication Failures": ["auth-bypass", "jwt-misuse", "missing-authentication"],
    "A08: Software and Data Integrity Failures": ["deserialization", "jwt-misuse", "mass-assignment"],
    "A09: Security Logging and Monitoring Failures": ["log-sensitive-data", "SECAUDIT: logging-and-monitoring"],
    "A10: Server-Side Request Forgery (SSRF)": ["ssrf"],
}

# Collect CWEs from all detectors
detector_cwes = {}
total_detectors = 0
all_cwes = set()

for fname in sorted(os.listdir(DETECTOR_DIR)):
    if not fname.endswith('.md'):
        continue
    total_detectors += 1
    fpath = os.path.join(DETECTOR_DIR, fname)
    with open(fpath) as f:
        content = f.read()
    cwes = re.findall(r'CWE-\d+', content)
    if cwes:
        det_name = fname.replace('.md', '')
        detector_cwes[det_name] = set(cwes)
        all_cwes.update(cwes)

# ---- Report ----
print()
print("=" * 50)
print("  SecGuardian CWE Coverage Report")
print("=" * 50)
print()

# 1. CWE Top 25
print("[1] CWE Top 25 (2024) Coverage")
print()
covered = 0
missing_list = []
for cwe_id, desc in CWE_TOP25.items():
    found_det = None
    for det_name, cwes in detector_cwes.items():
        if cwe_id in cwes:
            found_det = det_name
            break
    if found_det:
        print(f"  ✓ {cwe_id} — {desc}")
        print(f"         Detector: {found_det}")
        covered += 1
    else:
        print(f"  ✗ {cwe_id} — {desc}")
        missing_list.append(cwe_id)

pct = covered * 100 // 25
print()
print(f"  Coverage: {covered}/25 ({pct}%) covered, {25-covered} missing")
print()

# 2. OWASP Top 10
print("[2] OWASP Top 10 (2021) Coverage")
print()
owasp_detector = 0
owasp_secaudit = 0
owasp_missing = 0

for category, detectors in OWASP_TOP10.items():
    has_det = False
    has_skill = False
    for d in detectors:
        if d.startswith("SECAUDIT:"):
            has_skill = True
        else:
            # Check if detector exists in any namespace (e.g., web-auth-bypass, crypto-weak-random)
            found = False
            for fname in os.listdir(DETECTOR_DIR):
                if fname.endswith(f"-{d}.md"):
                    found = True
                    break
            if found:
                has_det = True

    if has_det and has_skill:
        print(f"  ✓ {category} (detectors + AI skill)")
        owasp_detector += 1
    elif has_det:
        print(f"  ✓ {category} (detectors)")
        owasp_detector += 1
    elif has_skill:
        print(f"  △ {category} (AI skill only)")
        owasp_secaudit += 1
    else:
        print(f"  ✗ {category}")
        owasp_missing += 1

print()
print(f"  Detector coverage: {owasp_detector}/10, AI skill only: {owasp_secaudit}/10, Missing: {owasp_missing}/10")
print()

# 3. Detector Statistics
print("[3] Detector Statistics")
print()
print(f"  Total detectors: {total_detectors}")
print(f"  Unique CWEs covered: {len(all_cwes)}")
print()
print("  By namespace:")
ns_counts = defaultdict(int)
for det_name in detector_cwes:
    ns = det_name.split('-')[0]
    ns_counts[ns] += 1
for ns in sorted(ns_counts):
    print(f"    {ns:15s} {ns_counts[ns]} detectors")
print()

# Summary
mode = sys.argv[1] if len(sys.argv) > 1 else ""

if mode == "--ci":
    if pct >= 60:
        print(f"PASS: CWE Top 25 coverage {pct}% >= 60%")
        sys.exit(0)
    else:
        print(f"FAIL: CWE Top 25 coverage {pct}% < 60%")
        sys.exit(1)

if mode == "--json":
    print(json.dumps({
        "cwe_top25_covered": covered,
        "cwe_top25_pct": pct,
        "owasp_top10_detectors": owasp_detector,
        "owasp_top10_secaudit": owasp_secaudit,
        "unique_cwes": len(all_cwes),
        "total_detectors": total_detectors,
    }, indent=2))
    sys.exit(0)

print("=" * 50)
print(f"  CWE Top 25: {covered}/25 ({pct}%)")
print(f"  OWASP Top 10: {owasp_detector}/10 detectors + {owasp_secaudit}/10 AI skills")
print(f"  Unique CWEs: {len(all_cwes)}")
print(f"  PPT claim: CWE Top 25 68%, OWASP Top 10 70%")
print(f"  Actual:    CWE Top 25 {pct}%, OWASP Top 10 {owasp_detector*10}%")
print()
PYEOF
