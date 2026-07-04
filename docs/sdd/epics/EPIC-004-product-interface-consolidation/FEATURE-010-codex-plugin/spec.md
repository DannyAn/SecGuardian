# FEATURE-010: Codex 自验证 Plugin

## 问题

SecGuardian 的修改验证依赖人类用户手动执行扫描验证。AI Agent 修改代码后无法自主验证结果，导致：
- 每次修改都需要用户介入测试
- 回归问题不能及时发现
- AI Agent 缺少闭环验证能力

## 方案

为 Codex 创建 `.codex-plugin/` 插件，提供自验证 skill：
- `codex-verify`: 全套验证流程（构建+部署+扫描+检查）
- `codex-scan`: 单语言扫描验证

## 验收标准

1. `.codex-plugin/plugin.json` 注册两个 skill
2. `codex-verify` 执行后能完成 self-check + deploy + 全语言索引 + 输出检查
3. `codex-scan <lang>` 能对单语言执行扫描验证
4. 无需人类介入即可验证代码改动
