# TASK-003: 渲染器目录树读取模式

> **Feature**: FEATURE-001-output-protocol (Phase 2 — v5.0)
> **状态**: ✅ Done
> **完成日期**: 2026-06-07
> **原则**: Task 驱动编码

## Goal

`scripts/render-report.py` 增加 `--findings-dir` 目录树读取模式，同时保持 `--findings` 向后兼容。

## Done

- [x] 实现 `load_findings_from_tree()` 函数
  - [x] `os.walk()` 遍历 `findings/<namespace>/<detector>/`
  - [x] 支持 `{"finding": {...}}` wrapper 和 bare object 两种格式
  - [x] 损坏文件跳过 + WARNING（不中断整体渲染）
- [x] argparse 新增 `--findings-dir` 参数
- [x] `main()` 数据加载逻辑改造
  - [x] `--findings-dir` 存在 → v5.0 目录树模式
  - [x] 否则 → v4.0 单体 JSON 模式（向后兼容）
  - [x] 从 `findings.json`（v5.0 轻量索引）读取扫描元数据
- [x] 渲染器内部逻辑（report.md / SARIF / summary / manifest / status / delta）无需改动

## Verification

```bash
# v4.0 兼容性
python3 scripts/render-report.py --findings findings.json --output /tmp/out/
# → 6 个输出文件正常生成

# v5.0 目录树
python3 scripts/render-report.py --findings-dir findings/ --output /tmp/out/
# → 与 v4.0 生成的报告内容一致

# 对比验证
diff <(python3 scripts/render-report.py --findings old.json --output /tmp/a/ 2>&1) \
     <(python3 scripts/render-report.py --findings-dir new/ --output /tmp/b/ 2>&1)
```

## Files Changed

| 文件 | 改动 |
|------|------|
| `scripts/render-report.py` | +80 行（load_findings_from_tree + argparse + main 改造） |
