# TASK-003: Renderer — remediation-pack.json 生成

## Goal

新增 render_remediation_pack()，从 findings 目录树聚合修复数据，输出 AI 可消费的结构化修复包，每条 finding 含 related_findings。

## Done

- [ ] render_remediation_pack() 函数实现
- [ ] 遍历 findings，读取 fix 段 + evidence 段
- [ ] 构建修复包条目
- [ ] 构建 related_findings（同函数关联 + 同文件关联 + AI relationships）
- [ ] 写入 ai/remediation-pack.json
- [ ] main() 调用

## Design

```python
def render_remediation_pack(findings, output_dir):
    remediations = []
    # Build (file, function) index for auto-relationships
    idx = {}
    for i, f in enumerate(findings):
        key = (f.get("file",""), f.get("function",""))
        idx.setdefault(key, []).append(i)

    for i, f in enumerate(findings):
        related = list(f.get("relationships", []))
        key = (f.get("file",""), f.get("function",""))
        for j in idx.get(key, []):
            if j != i:
                rid = findings[j].get("id", "")
                if rid and rid not in related:
                    related.append(rid)

        rem = {
            "finding_id": f.get("id",""),
            "title": f.get("title",""),
            "severity": f.get("severity",""),
            "cwe": f.get("cwe",""),
            "detector": f.get("detector",""),
            "affected_files": [f.get("file","")],
            "root_cause": f.get("evidence",{}).get("judgment_rationale",""),
            "fix_strategy": f.get("fix",{}).get("description",""),
            "before_code": f.get("fix",{}).get("before_code",""),
            "after_code": f.get("fix",{}).get("after_code",""),
            "effort_hours": f.get("fix",{}).get("effort_hours", 0),
            "verification": f.get("fix",{}).get("verification_method",""),
            "related_findings": related
        }
        remediations.append(rem)
```

## Files

- scripts/render-report.py

## Verification

```bash
python3 -c "
import json
with open('.codeagent/.../ai/remediation-pack.json') as f:
    r = json.load(f)
for rem in r.get('remediations', []):
    print(rem['finding_id'], 'related:', len(rem.get('related_findings',[])))
"
```
