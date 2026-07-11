#!/usr/bin/env python3
"""Generate standardized Task prompts from partition-plan.json (FEATURE-007 P4).

Each nonempty (rule_id, batch_id) produces one JSON prompt object with:
- rule_id, batch_id, rule_path
- signal list (signal_id, file, line, callee, category)
- All canonical artifact schemas
- CRITICAL format constraints

Usage:
  python3 gen-task-prompts.py --plan partition-plan.json \
    --project /path/to/project --scan-dir /path/to/scan/dir \
    --index-json /path/to/index.json
  python3 gen-task-prompts.py --self-test
"""

import json
import sys

JUDGE_VERDICT_SCHEMA = {
    "rule_id": "<rule_id>",
    "batch_id": "<batch_id>",
    "verdicts": [
        {
            "signal_id": "<signal_id>",
            "file": "<source_file>",
            "line": "<line_number>",
            "verdict": "CONFIRMED",
            "severity": "Critical",
            "cwe": "CWE-120",
            "judgment_matrix": {
                "Q1_<descriptor>": True,
                "Q2_<descriptor>": True,
                "Q3_<descriptor>": False,
                "conclusion": "CONFIRMED"
            }
        }
    ],
    "summary": {"confirmed": 0, "suppressed": 0}
}

BLINDSPOT_SCHEMA = {
    "rule_id": "<rule_id>",
    "batch_id": "<batch_id>",
    "suppressed": [
        {"signal_id": "<id>", "reason": "<why this signal is not a vulnerability>"}
    ]
}

TASK_PROMPT_HEADER = """Execute ONLY this SecGuardian isolated batch.
SCAN_ID: {scan_id}
PROJECT: {project}
RULE_ID: {rule_id}
BATCH_ID: {batch_id}
RULE_PATH: {rule_path}
INDEX_JSON: {index_json}
SCAN_DIR: {scan_dir}
TMP_DIR: {tmp_dir}

Load state from {project}/.codeagent/secguardian/.scan_state.secguard.
Read ONLY RULE_PATH and source windows for signals below using Read(file, offset=line-15, limit=30).
Do NOT read complete source files. Do NOT read partition-plan.json.

Use TMP_DIR for scratch files. It is already created under the scan directory.

===== SIGNALS IN THIS BATCH =====
{signals_text}

===== CANONICAL ARTIFACT FORMATS (MUST MATCH EXACTLY) =====

1. judge_verdict.json — THE GATE CONSUMES THIS:
{judge_schema}

CRITICAL RULES:
- Every verdict entry MUST have: signal_id, file, line, verdict.
- verdict MUST be EXACTLY "CONFIRMED" or "SUPPRESS". No other values.
- judgment_matrix field names MUST start with Q1_/Q2_/Q3_ prefix + underscore + descriptor FROM rule.md Detection Spec.
- summary.confirmed and summary.suppressed MUST be integers.
- NO extra top-level fields (no generated_at, scan_id, judge_timestamp, etc.).

2. blindspot.json — ALL signals not confirmed, with reason:
{blindspot_schema}

3. record-finding.py --from-file (for each CONFIRMED verdict):
{{
  "detector": "<canonical detector name from rule.md>",
  "severity": "Critical|High|Medium",
  "cwe": "CWE-xxx",
  "title": "<one line>",
  "file": "<path relative to project, e.g. src/parser.c>",
  "line": <line>,
  "function": "<function name from index.json symbols.functions>",
  "snippet": "<the code line>",
  "rule_id": "{rule_id}",
  "batch_id": "{batch_id}",
  "signal_id": "<exact signal_id from SIGNALS list above>",
  "index_json": "{index_json}",
  "scan_dir": "{scan_dir}"
}}

CRITICAL: signal_id MUST be copied exactly from the SIGNALS list above.
CRITICAL: function MUST match a function name in index.json symbols.functions.

Do not process any other rule or batch. Do not edit source code.
Return: {{rule_id: "{rule_id}", batch_id: "{batch_id}", confirmed: N, suppressed: M, artifacts: [list of files created]}}"""


def generate_prompts(plan_path, project, scan_dir, index_json):
    import os
    with open(plan_path) as f:
        plan = json.load(f)

    scan_id = plan.get("summary", {}).get("scan_id", "unknown")
    prompts = []

    # Ensure .tmp/ exists under scan directory (not /tmp/)
    tmp_dir = os.path.join(scan_dir, ".tmp")
    os.makedirs(tmp_dir, exist_ok=True)

    for rule in plan.get("rules", []):
        for batch in rule.get("batches", []):
            signals = batch.get("signals", [])
            if not signals:
                continue

            signals_text = "\n".join(
                f'  signal_id={s.get("signal_id","?")} callee={s.get("callee","?")} '
                f'file={s.get("file","?")} line={s.get("line","?")} '
                f'args={s.get("arguments",[])}'
                for s in signals
            )

            prompt = TASK_PROMPT_HEADER.format(
                scan_id=scan_id,
                project=project,
                rule_id=rule["rule_id"],
                batch_id=batch["batch_id"],
                rule_path=rule["rule_path"],
                index_json=index_json,
                scan_dir=scan_dir,
                tmp_dir=tmp_dir,
                signals_text=signals_text,
                judge_schema=json.dumps(JUDGE_VERDICT_SCHEMA, indent=2),
                blindspot_schema=json.dumps(BLINDSPOT_SCHEMA, indent=2),
            )

            prompts.append({
                "rule_id": rule["rule_id"],
                "batch_id": batch["batch_id"],
                "signal_count": len(signals),
                "prompt": prompt,
            })

    return prompts


def self_test():
    import tempfile, os
    with tempfile.TemporaryDirectory() as tmp:
        plan = {
            "summary": {"scan_id": "test-scan"},
            "rules": [{
                "rule_id": "test.rule",
                "rule_path": os.path.join(tmp, "rule.md"),
                "batches": [{
                    "batch_id": "batch-001",
                    "signals": [{
                        "signal_id": "sig-test",
                        "callee": "malloc",
                        "file": "test.c",
                        "line": 10,
                        "arguments": ["size"]
                    }]
                }]
            }]
        }
        plan_path = os.path.join(tmp, "plan.json")
        with open(plan_path, "w") as f:
            json.dump(plan, f)

        scan_dir = os.path.join(tmp, "scan")
        prompts = generate_prompts(plan_path, os.path.join(tmp, "proj"), scan_dir, os.path.join(tmp, "index.json"))
        assert len(prompts) == 1
        p = prompts[0]["prompt"]
        assert "SIGNALS IN THIS BATCH" in p
        assert "JUDGE_VERDICT" not in p  # schema should be expanded, not a placeholder name
        assert "judgment_matrix" in p
        assert "CRITICAL RULES" in p
        assert "CANONICAL ARTIFACT FORMATS" in p
        assert "TMP_DIR:" in p
        assert scan_dir in p
        # Verify .tmp/ was created
        assert os.path.isdir(os.path.join(scan_dir, ".tmp"))
        print("OK - gen-task-prompts self-test passed")
    return 0


def main():
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--plan", help="path to partition-plan.json")
    p.add_argument("--project", help="user project root directory")
    p.add_argument("--scan-dir", help="scan output directory")
    p.add_argument("--index-json", help="path to index.json")
    p.add_argument("--self-test", action="store_true")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    if args.self_test:
        return self_test()

    if not all([args.plan, args.project, args.scan_dir, args.index_json]):
        p.error("--plan, --project, --scan-dir, --index-json are required (or use --self-test)")

    prompts = generate_prompts(args.plan, args.project, args.scan_dir, args.index_json)
    if args.json:
        print(json.dumps(prompts, indent=2))
    else:
        for i, pr in enumerate(prompts):
            print(f"=== Batch {i+1}/{len(prompts)}: {pr['rule_id']}/{pr['batch_id']} ({pr['signal_count']} signals) ===")
            print(pr["prompt"])
            print()


if __name__ == "__main__":
    sys.exit(main())
