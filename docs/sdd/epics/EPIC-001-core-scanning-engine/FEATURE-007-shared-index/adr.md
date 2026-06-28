# ADR-001: 共享索引文件位置

**日期**: 2026-06-28 | **状态**: ✅ Accepted

## Decision
`index.json` 放在 `.codeagent/secguardian/index.json`，三个命令共用。
文件名保持 `index.json` 不变（与索引器 `--output` 参数一致）。

## Reason
1. 索引器已有 `--output <path>/index.json` 输出约定，不改文件名
2. 产品级目录 `secguardian/` 天然属于三个命令共享
3. `.codeagent/` 是官方扩展数据目录，用户和 AI 都习惯在此查找

## Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| `.codeagent/.index/` | 额外隐藏目录增加复杂度 |
| 保留在 scan 目录 + 符号链接 | 链接管理复杂，`--force` 行为不直观 |

---

# ADR-002: 目录结构重组

## Decision
`<cmd>-secguardian/scans/` → `secguardian/<cmd>/scans/`
旧式：`.codeagent/secguard-secguardian/scans/<id>/`
新式：`.codeagent/secguardian/secguard/scans/<id>/`

## Reason
1. 共享 index.json 放在 `secguardian/` 根下，自然属于所有命令
2. 去掉冗余的 `secguardian` 后缀（`securd-secguardian` → `secguardian/secguard`）
3. 与产品品牌 `secguardian` 对齐

## Consequences
- 「latest」符号链接位置变为 `secguardian/<cmd>/scans/latest`
- delta.json 读取前次 manifest 的路径随之变更