# FEATURE-006: Finding Identity Redesign + 安全评分修复 — Plan

> **Goal**: 重构 Finding Identity 体系（SHA-256 + 序号分离），修复安全评分 bug
> **文件影响**: 6 个模块，8 个 Task

---

## Architecture

```
AI Agent (skills/ + commands/)
    ↓ 生成 finding 文件
findings/<ns>/<det>/<sha12>_<file_slug>-<line>.json
    ↓ 写入
findings.json (lightweight index with seq + sha)
    ↓
Renderer (render-report.py)
    ├─ manifest.json  ← seq + sha
    ├─ report.md      ← #N 表格, 无 ID 列
    ├─ results.sarif  ← partialFingerprints = SHA
    ├─ summary.json   ← security_score 从 findings 计算
    ├─ status.json    ← security_score 从 findings 计算
    └─ delta.json     ← SHA 对比
```

## File Structure

| 文件 | 改动量 | 类型 |
|------|--------|------|
| `scripts/render-report.py` | ~60 行 | 修改 manifest/report/SARIF 生成逻辑 |
| `knowledge/protocols/scan-output.md` | ~30 行 | 更新文件命名、finding 结构 |
| `commands/secguard.md` | ~20 行 | 更新 ID 格式描述 + 模板 |
| `commands/secaudit.md` | ~10 行 | 同步更新 |
| `commands/secreview.md` | ~10 行 | 同步更新 |
| `skills/secguard/java/SKILL.md` | ~5 行 | 更新 finding 写入指令 |
| `skills/secguard/cpp/SKILL.md` | ~5 行 | 同上 |
| `skills/secguard/python/SKILL.md` | ~5 行 | 同上 |
| `skills/secguard/go/SKILL.md` | ~5 行 | 同上 |
| `skills/secguard/js/SKILL.md` | ~5 行 | 同上 |
| `scripts/validate-findings.py` | ~10 行 | 更新 schema 验证 |
| `scripts/e2e-verify.sh` | ~10 行 | 更新测试数据 |

## Tasks

- [ ] **TASK-001**: 修复安全评分 bug — renderer 移除 `security_score` override + findings.json 模板移除
- [ ] **TASK-002**: Renderer 适配新 Finding 格式 — manifest/report/SARIF 改用序号 + SHA
- [ ] **TASK-003**: 更新 protocol docs — scan-output.md 更新文件命名和 finding 结构
- [ ] **TASK-004**: 更新 command 定义 — secguard/secaird/secreview 更新 ID 格式
- [ ] **TASK-005**: 更新 skills — 5 个语言 SKILL.md 更新 finding 写入指令
- [ ] **TASK-006**: 更新 validate 脚本 — validate-findings.py + e2e-verify.sh
- [ ] **TASK-007**: E2E 验证 — L1 + L4 全部通过
- [ ] **TASK-008**: 部署 — python deploy.sh all

## Verification

```bash
# L1: 设计一致性
bash scripts/self-check.sh

# L4: E2E 验证（含评分 + SARIF + delta）
bash scripts/e2e-verify.sh

# 手动验证: 用 test 输出对照 spec 3.3 的表格格式
python3 scripts/render-report.py --findings-dir <test-dir>/findings/ --index <test-dir>/index.json --output /tmp/verify/
grep -n '| #' /tmp/verify/report.md | head
grep security_score /tmp/verify/summary.json /tmp/verify/status.json
```

## 执行顺序

1. TASK-001（评分修复）→ 立即 deploy 看效果
2. TASK-002 → TASK-006（身份重构）→ 一起 deploy
3. TASK-007（验证）→ 确认全部通过
4. TASK-008（最终部署）
