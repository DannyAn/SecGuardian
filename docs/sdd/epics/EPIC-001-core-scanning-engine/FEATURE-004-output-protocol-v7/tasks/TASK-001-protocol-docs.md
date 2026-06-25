# TASK-001: 协议文档更新

## Goal

更新 scan-output.md 到 v7.0 + findings-schema.json 到 v1.1 + 写入用户旅程。

## Done

- [ ] scan-output.md 版本号改为 7.0，写入 v7.0 变更说明
- [ ] scan-output.md 目录结构更新为最终版（无 by-file、无 attack-graph）
- [ ] scan-output.md 新增"用户旅程"节（按角色编排阅读路径）
- [ ] scan-output.md report.md 模板精简到 5 节
- [ ] scan-output.md executive-summary.md 规范（发现分布表格式）
- [ ] findings-schema.json 新增 related_finding 定义

## Files

- knowledge/protocols/scan-output.md
- knowledge/protocols/findings-schema.json

## Verification

```bash
grep -c "v7.0" knowledge/protocols/scan-output.md  # >= 1
grep -c "用户旅程" knowledge/protocols/scan-output.md  # >= 1
python3 -c "
import json
s = json.load(open('knowledge/protocols/findings-schema.json'))
print('Has RelatedFinding:', 'RelatedFinding' in s.get('$defs', {}))
"
```
