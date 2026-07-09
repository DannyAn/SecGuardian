# 验证体系设计：3 轮不同维度交叉验证

> 目的：解决"发布多个版本到生产环境才发现0检出"的问题
> 核心理念：不同维度验证之间不应有重叠的盲区

---

## Round 1：功能完备性验证（Functional Completeness）

**验证目标**：每个信号类型在每种语言上的产出是否非零且合理

### 1.1 信号非零断言

| 语言 | S1 calls | S2 strings | S3 decls | S4 values | S5 imports | S7 flow |
|------|----------|------------|----------|-----------|------------|---------|
| C/C++ | ≥50 | ≥20 | ≥10 | ≥1 | ≥10 | ≥10 |
| Go | ≥50 | ≥20 | N/A | N/A | ≥3 | ≥3 |
| Java | ≥20 | ≥20 | N/A | N/A | ≥5 | ≥1 |
| Python | ≥10 | ≥20 | N/A | N/A | ≥5 | ≥1 |
| JS | ≥30 | ≥50 | N/A | N/A | N/A | N/A |

**阈值依据**：每个 no-answers 项目包含 8-15 个源文件，含多种漏洞模式

### 1.2 安全关键调用覆盖检查

对每种语言，至少 N 个已知危险函数调用被检测到：

| 类别 | C/C++ | Go | Java | Python | JS |
|------|-------|----|------|--------|----|
| command execution | system, popen, exec* | exec.Command | exec | subprocess.run | exec, execSync, spawn |
| SQL injection | - | db.Query, db.QueryRow | executeQuery, prepareStatement | cursor.execute | - |
| memory unsafe | strcpy, memcpy, malloc | - | - | - | - |
| deserialization | - | - | readObject | pickle.loads | JSON.parse |
| crypto weak | DES_*, MD5_* | - | - | - | crypto.createHash |

### 1.3 字符串分类覆盖验证

至少检测到以下 5 种类别中的 3 种：
- api_key (sk-XXXX 模式)
- password (P@ssw0rd 模式)
- jwt (eyJ 模式)  
- url (http:// 前缀)
- secret (token/secret 关键词)

---

## Round 2：端到端检测价值验证（Finding Generation）

**验证目标**：信号是否真正能驱动安全发现，而非"有信号但不产出具价值的 finding"

### 2.1 信号→Finding 关联率

对每个 no-answers 项目：
1. 提取所有 call_sites
2. 按类别分组（string/memory/io/exec/sync/crypto/generic）
3. 确认每个分组至少产生 ≥1 个有意义的安全 finding（经 LLM Worker 分析后）

### 2.2 预筛命中率

对每个 language 的 call_sites，统计：
- `knownLibFuncs` 命中数（精确匹配 C/C++ 危险函数）
- 非匹配但安全相关的调用（Java executeQuery/Python subprocess.run 等）
- 预筛覆盖率 = 安全相关调用 / 总调用数 ≥ 30%

### 2.3 False Negative 探测

对每个 no-answers 项目，已知存在以下漏洞模式，确认信号覆盖：

| 漏洞模式 | C/C++ | Go | Java | Python | JS |
|----------|-------|----|------|--------|----|
| 缓冲区溢出 | strcpy/memcpy 调用 ✓ | - | - | - | - |
| SQL 注入 | - | db.Query 未参数化 ✓ | executeQuery 拼接 ✓ | cursor.execute 拼接 ✓ | - |
| 命令注入 | system/popen ✓ | exec.Command ✓ | Runtime.exec ✓ | subprocess.run ✓ | exec/execSync ✓ |
| 路径遍历 | fopen 未校验 ✓ | - | - | open 未校验 ✓ | - |
| 反序列化 | - | - | readObject ✓ | pickle/JSON ✓ | JSON.parse ✓ |
| 弱加密 | DES_set_key ✓ | - | - | - | crypto.createHash(md5) ✓ |
| 硬编码密钥 | 字符串含密钥 ✓ | 字符串含密钥 ✓ | 字符串含密钥 ✓ | 字符串含密钥 ✓ | 字符串含密钥 ✓ |

---

## Round 3：回归与边界验证（Regression + Edge Cases）

**验证目标**：修改不破坏现有功能，且边界情况不引发静默失败

### 3.1 回归验证（L1-L5）

按 AGENTS.md 验证流程：
- L1: `go build ./...` — 编译通过
- L2: `go test ./...` — 全部测试通过
- L3: 对 5 个 no-answers 项目运行 indexer，信号总和不低于 Round 1 阈值
- L4: 信号一致性对比（CGO vs 非 CGO 解析器产出对比）
- L5: 对 `cpp-vuln-demo`（非 no-answers）运行，验证可复现性

### 3.2 边界验证

| 边界场景 | 验证方法 | 预期 |
|----------|----------|------|
| 空文件 | indexer --path empty_dir | 0 files, 不 panic, 退出码 0 |
| 大文件 (>512KB) | JS 解析跳过 | 返回空 ParseResult, 不报错 |
| 混合语言仓库 | 文件多种扩展名 | auto-detect 选择主语言 |
| 无 CGO 环境 | `GOGC=off go build -tags !cgo` | 回退到 regex 解析器 |
| 特殊字符文件名 | 文件名含空格/中文 | ParseFile 正常处理 |
| 深层嵌套函数 | 递归调用 >10 层 | walkTopLevel 不栈溢出 |
| 编译错误代码 | 语法错误 | ParseFile 返回 error, 不 panic |

### 3.3 非 CGO 回退验证

验证 regex 解析器在无 CGO 时正确回退：
```bash
go test -tags !cgo ./parser/ -run TestSignalMatrixOnAllFiles
```

预期：C/C++ 信号总量 ≥ 50（与 CGO 版本一致允许 ±10% 差异）

---

## 验证执行流程

### 每次修改后（快速验证，<30 秒）
```
1. go build ./internal/...
2. go test ./internal/parser/ -run "TestSignal|TestStringLiteral|TestImport"
3. scripts/bin/secguardian-index --path examples/cpp-vuln-demo-no-answers/
   → 验证 signals 行非零
```

### 每次发布前（完整验证，<5 分钟）
```
4. Round 1: 所有 5 语言信号非零断言
5. Round 2: 安全调用覆盖抽样检查
6. Round 3: CGO + 非 CGO 双模式测试
7. 信号总和 vs 前一次发布的对比报告
```

### CI 集成建议
```
job: verify-signals
  - go test -tags cgo ./parser/ -run TestSignalMatrixOnAllFiles
  - 对 5 个 no-answers 项目运行 indexer
  - 解析 signals 行，与 Round 1 阈值对比
  - 失败时输出 diff: "之前: 237 calls, 现在: 0 calls → REGRESSION"
```
