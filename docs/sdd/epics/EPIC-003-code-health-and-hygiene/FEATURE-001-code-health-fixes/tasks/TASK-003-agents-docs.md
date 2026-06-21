 # TASK-003: AGENTS.md 文档刷新

 ## Goal

 修复 AGENTS.md 中的过时描述：
 - 版本号: v0.5.3 → v0.6.0
 - 测试套件: "无传统测试套件" → 更新为实际状态 (parser + indexer 有 go test)
 - 协议版本: 确保 protocol/scan-output 引用准确

 ## Files Changed

 - `AGENTS.md` — 项目解剖头部信息修复

 ## Verification

 ```bash
 rg 'v0\.5\.\d+' AGENTS.md  # should be empty
 rg '无传统测试套件' AGENTS.md  # should be empty
 ```
