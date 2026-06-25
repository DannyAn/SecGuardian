# TASK-004: Renderer — generate_report_md() 精简

## Goal

修改 generate_report_md()，从 7 节精简到 5 节。去掉 §1 管理层摘要、§1.5 验证漏斗、§2 合规仪表盘。

## Done

- [ ] 去掉 report.md 中的 §1 管理层摘要（评分/等级/趋势）
- [ ] 去掉 §1.5 验证漏斗
- [ ] 去掉 §2 合规仪表盘
- [ ] 重新编节号：扫描元数据 1 / 检出清单 2 / 详细发现 3 / 修复路线图 4 / 附录 5
- [ ] 验证精简后与 SARIF/summary 数据一致

## Design

保留的 5 节结构：

```
Section 1: 扫描元数据（缩减到 5 行）
Section 2: 检出清单表格
Section 3: 详细发现（四段式，保持不动）
Section 4: 修复路线图（保持不动）
Section 5: 附录（保持不动）
```

## Files

- scripts/render-report.py（修改 generate_report_md）

## Verification

```bash
! grep -q "执行摘要\|合规仪表盘\|验证漏斗" .codeagent/.../report.md && echo "cleaned"
grep -c "详细发现\|修复路线图\|附录" .codeagent/.../report.md
```
