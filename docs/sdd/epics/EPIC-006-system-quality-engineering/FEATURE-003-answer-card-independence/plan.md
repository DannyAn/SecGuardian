# FEATURE-003: Plan — Answer-Card Independence

## 实现步骤

### Step 1: 受控实验 🔬 [完成]

- [x] 创建 `examples/java-vuln-demo-stripped/`（剥离 67 条答案卡）
- [x] 执行完整 secguard 扫描（28 findings，vs 原始 27）
- [x] 验证无退化：剥离版本检出了全部原始问题 + 多 1 个

### Step 2: 脱敏脚本 [完成]

- [x] 创建 `scripts/strip-answer-cards.py`
- [x] 支持行注释模式（VULNERABILITY / CWE / BAD / TP-P0-P3）
- [x] 支持块注释模式（CWE 列表 / VULNERABILITIES 标题）
- [x] 空行保留（行号不变）
- [x] 幂等操作（已脱敏文件再次处理 = 0 行变更）
- [x] dry-run 模式
- [x] 输出脱敏清单 `.strip-manifest.json`
- [x] 验证：在原始 demo 上运行，75 行被剥离 → 副本中 0 个 VULNERABILITY 残留

### Step 3: 模板集成 [完成]

- [x] `commands/secguard.md` Step 2.5a.5 新增脱敏步骤
- [x] Step 2.5b 强制读取规则指向脱敏副本
- [x] Step 3d 验证读取指向脱敏副本
- [x] 阻止 AI 直接读取原始文件

### Step 4: 自检守卫 [完成]

- [x] `scripts/self-check.sh` §13e 检查 secguard 模板包含 strip-answer-cards.py
- [x] self-check 172/172 通过

### Step 5: SDD 文档 [完成]

- [x] spec.md — 问题陈述 + 实验证据 + 需求规格
- [x] adr.md — 方案对比 + 决策理由
- [x] plan.md — 本文件
- [x] progress.md — 状态
- [x] changes/CHANGE-001-initial-implementation.md — 变更记录

## 涉及文件变更

```
ADD: scripts/strip-answer-cards.py                — 答案卡脱敏脚本（112 行）
MOD: commands/secguard.md                         — Step 2.5a.5 新增 + 3 处脱敏引用
MOD: scripts/self-check.sh                        — §13e 新增检查
ADD: docs/sdd/epics/EPIC-006/.../spec.md           — SDD 规格
ADD: docs/sdd/epics/EPIC-006/.../adr.md            — 架构决策
ADD: docs/sdd/epics/EPIC-006/.../plan.md           — 实现计划
ADD: docs/sdd/epics/EPIC-006/.../progress.md        — 进度
ADD: docs/sdd/epics/EPIC-006/.../changes/CHANGE-001 — 变更记录
```

## 验证命令

```bash
# 脱敏脚本测试
python3 scripts/strip-answer-cards.py \
  --index examples/java-vuln-demo/.codeagent/secguardian/index.json \
  --source-root examples/java-vuln-demo \
  --output-dir /tmp/strip-verify \
  --dry-run

# 脱敏后答案卡应为 0
grep -r 'VULNERABILITY' /tmp/strip-verify/src/ | wc -l    # → 0

# self-check
bash scripts/self-check.sh                                # → 172/172 passed
```

## 回滚方案

如脱敏机制导致问题，删除以下变更即可：
1. `git revert` Step 2.5a.5 的模板变更（secguard.md）
2. 删除 `scripts/strip-answer-cards.py`
3. 恢复 `scripts/self-check.sh` §13e
