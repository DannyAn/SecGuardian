---
category: standards
standard: SEI CERT Java
version: "2016"
rules_count: 60+
mapped_detectors: 18
---

# SEI CERT Java 编码标准 → SecGuardian Detector 映射

> 来源: [SEI CERT Java Coding Standard](https://wiki.sei.cmu.edu/confluence/display/java/SEI+CERT+Oracle+Coding+Standard+for+Java)

## 规则映射

### 00. 输入验证和数据消毒 (IDS)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| IDS00-J | 消毒不可信数据并传播到外部系统 | input-validation | ✅ 完全 |
| IDS01-J | 在拼接前规范化字符串 | sql-injection | ⚠️ 部分 |
| IDS03-J | 不记录敏感数据 | error-log-sensitive-data | ✅ 完全 |
| IDS04-J | 限制传递给 ZipInputStream 的文件大小 | resource-exhaustion | ⚠️ 部分 |
| IDS06-J | 排除用户输入中的不信任字符 | input-validation | ✅ 完全 |
| IDS07-J | 不要将不可信数据传递给 Runtime.exec() | command-injection | ✅ 完全 |
| IDS08-J | 在使用正则表达式之前消毒不可信数据 | resource-exhaustion | ⚠️ 部分 |
| IDS11-J | 在修改或将数据返回给用户时规范化路径名 | path-traversal | ✅ 完全 |
| IDS13-J | 使用兼容的编码在字符串间转换 | — | ❌ 未覆盖 |
| IDS14-J | 不要使用不完整的黑名单过滤 | input-validation | ✅ 完全 |
| IDS16-J | 防止 XML 外部实体攻击 (XXE) | xxe | ✅ 完全 |
| IDS17-J | 防止 XML Entity Expansion (Billion Laughs) | xxe | ⚠️ 部分 |

### 01. 声明和初始化 (DCL)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| DCL00-J | 防止循环类初始化 | — | ❌ 未覆盖 |

### 02. 表达式 (EXP)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| EXP00-J | 不要忽略方法返回值 | exception-swallow | ⚠️ 部分 |
| EXP01-J | 不要使用肯定为空的指针/引用 | null-dereference | ✅ 完全 |
| EXP02-J | 不要使用 `==` 比较数组内容 | — | ❌ 未覆盖 |

### 04. 数值类型和运算 (NUM)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| NUM00-J | 检测或防止整数溢出 | integer-overflow | ✅ 完全 |
| NUM02-J | 确保除法和取余操作数不为零 | — | ❌ 未覆盖 |
| NUM07-J | 不要尝试与 NaN 进行比较 | — | ❌ 未覆盖 |

### 05. 对象导向 (OBJ)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| OBJ01-J | 限制对类字段的可访问性 | excessive-data-exposure | ⚠️ 部分 |
| OBJ06-J | 防御性地复制可变输入和内部组件 | mass-assignment | ⚠️ 部分 |
| OBJ07-J | 在返回引用之前防御性地复制内部组件 | excessive-data-exposure | ✅ 完全 |
| OBJ08-J | 不要将外部控制的类提供给反序列化 | deserialization | ✅ 完全 |
| OBJ09-J | 比较类而不是名称 | — | ❌ 未覆盖 |
| OBJ10-J | 不要使用公共的可变静态字段 | — | ❌ 未覆盖 |
| OBJ11-J | 警惕构造函数的异常安全性 | — | ❌ 未覆盖 |

### 06. 方法 (MET)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| MET00-J | 验证方法参数 | input-validation | ✅ 完全 |
| MET01-J | 不要将 assert 用于参数验证 | — | ❌ 未覆盖 |
| MET02-J | 不要使用已废弃的 API | dependency-security | ⚠️ 部分 |
| MET03-J | 方法执行安全相关检查不要依赖 finally | — | ❌ 未覆盖 |

### 07. 异常行为 (ERR)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| ERR00-J | 不要抑制或忽略检查异常 | exception-swallow | ✅ 完全 |
| ERR01-J | 不要允许异常泄露敏感信息 | error-stack-trace-leak | ✅ 完全 |
| ERR02-J | 防止异常丢失原先的堆栈信息 | — | ❌ 未覆盖 |
| ERR03-J | 在 finally 块中恢复对象的原始状态 | — | ❌ 未覆盖 |
| ERR04-J | 不要从 finally 块中退出 | — | ❌ 未覆盖 |
| ERR05-J | 不要将抛出的异常类型用于控制流 | — | ❌ 未覆盖 |
| ERR06-J | 不要抛出未声明的检查异常 | — | ❌ 未覆盖 |
| ERR07-J | 不要抛出 RuntimeException/Exception/Throwable | — | ❌ 未覆盖 |
| ERR08-J | 不要捕获 NullPointerException 或任何其父类 | — | ❌ 未覆盖 |
| ERR09-J | 不要为迭代器使用 `while` 循环 | — | ❌ 未覆盖 |

### 08. 可见性和原子性 (VNA)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| VNA00-J | 确保共享变量的可见性和原子性 | race-condition | ⚠️ 部分 |
| VNA01-J | 确保对共享可变变量的操作原子 | race-condition | ⚠️ 部分 |
| VNA02-J | 确保对复合操作的加锁是原子的 | race-condition | ✅ 完全 |
| VNA03-J | 不要假设一组操作会原子执行 | race-condition | ⚠️ 部分 |
| VNA04-J | 确保对共享的 long/double 的读写是原子的 | — | ❌ 未覆盖 |

### 09. 锁 (LCK)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| LCK00-J | 使用私有 final 锁对象 | — | ❌ 未覆盖 |
| LCK01-J | 不要同步共享的可变对象 | — | ❌ 未覆盖 |
| LCK05-J | 使用相同的顺序请求和释放锁 | deadlock | ✅ 完全 |
| LCK07-J | 避免通过线程实例调用 run() | — | ❌ 未覆盖 |

### 10. 线程 API (THI)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| THI00-J | 不要在线程池中调用 Thread.run() | — | ❌ 未覆盖 |

### 11. 线程池 (TPS)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| TPS00-J | 使用线程池处理大量的并发请求 | — | ❌ 未覆盖 |

### 12. 输入输出 (FIO)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| FIO00-J | 不要对共享目录操作时不检查符号链接 | toctou | ✅ 完全 |
| FIO01-J | 创建文件时使用正确的访问权限 | insecure-permissions | ✅ 完全 |
| FIO02-J | 检测并处理文件相关的错误返回 | resource-exhaustion | ⚠️ 部分 |
| FIO03-J | 在使用后释放资源 | memory-leak | ✅ 完全 |
| FIO04-J | 使用后关闭资源 | memory-leak | ✅ 完全 |

### 15. 平台安全 (SEC)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| SEC00-J | 不要使用不安全的加密算法 | weak-crypto-algorithm | ✅ 完全 |
| SEC01-J | 不要使用弱随机数生成器 | weak-random | ✅ 完全 |
| SEC02-J | 不要将敏感数据存储在不安全的位置 | hardcoded-secrets | ⚠️ 部分 |
| SEC03-J | 不要泄露敏感数据 | error-stack-trace-leak | ✅ 完全 |
| SEC04-J | 在执行特权操作前调用 accessController | privilege-escalation | ⚠️ 部分 |
| SEC05-J | 不要使用反射来增加可访问性 | privilege-escalation | ⚠️ 部分 |
| SEC06-J | 不要在签名/加密中使用已知的弱密钥 | insufficient-key-length | ✅ 完全 |
| SEC07-J | 调用 privileged 块时遵守最小权限原则 | privilege-escalation | ⚠️ 部分 |
| SEC08-J | 不要在 URLClassLoader 中使用不安全的设置 | — | ❌ 未覆盖 |

### 覆盖统计

| 类别 | 规则数 | 已映射 | 覆盖率 |
|------|--------|--------|--------|
| IDS | 11 | 9 | 82% |
| ERR | 10 | 2 | 20% |
| SEC | 9 | 7 | 78% |
| FIO | 5 | 4 | 80% |

**总计: 22/35 核心规则已映射 (63%)**
