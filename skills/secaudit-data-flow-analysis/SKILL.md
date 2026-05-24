---
name: secaudit-data-flow-analysis
description: 追踪数据在系统中的完整传播路径，识别从输入点到输出点的所有数据流，发现隐式的数据依赖和潜在的数据泄露通道
category: analysis
---

# 数据流分析 (Data Flow Analysis)

## 分析方法概述

数据流分析追踪数据在系统中的完整生命周期：从哪里进来、经过了哪些处理、最终到达哪里。与污点分析不同的是，数据流分析关注**所有数据的流向**（不仅是不可信数据），目的是理解数据架构中的安全风险。

适用于：
- 审计敏感数据（PII、密钥）的传播范围
- 验证数据最小化原则（不该看到数据的组件是否确实看不到）
- 发现意外的数据共享（缓存、日志、监控中的数据泄露）

## 分析流程

### Phase 1: 数据分类

首先对系统中的所有数据进行分类标记：

| 分类 | 级别 | 示例 |
|------|------|------|
| 公开数据 | L0 | 新闻内容、产品列表、公开 API 响应 |
| 内部数据 | L1 | 内部文档、非敏感配置、聚合统计 |
| 敏感数据 | L2 | 用户个人信息、行为日志、邮件地址 |
| 机密数据 | L3 | 密码、Token、私钥、支付信息 |
| 高度机密 | L4 | 根密钥、主密钥、HSM 中的密钥材料 |

### Phase 2: 流向追踪

对每个 L2-L4 级别的数据，追踪其在系统中的完整流向：

```
追踪模型:
  数据源 (Data Source)
    → 采集 (Collection): HTTP handler, MQ consumer, cron job
    → 处理 (Processing): service layer, pipeline, ETL
    → 存储 (Storage): database, cache, file system, object store
    → 传输 (Transfer): internal RPC, external API call, async message
    → 展示 (Presentation): API response, UI render, report export
    → 销毁 (Destruction): TTL, retention policy, explicit delete
```

**每个环节记录：**
```
□ 哪个组件在使用这个数据
□ 数据是否被复制（副本数）
□ 是否传给了第三方
□ 是否被缓存（缓存多久）
□ 是否进入了日志/监控系统
□ 处理过程中是否被脱敏
```

### Phase 3: 异常流检测

搜索不符合数据分类级别的"异常流向"：

| 异常模式 | 风险 |
|---------|------|
| L3 机密数据进入日志系统 | 密钥泄露到 ELK/Splunk |
| L2 敏感数据传给第三方分析 | 用户数据泄露到 Google Analytics、Mixpanel |
| L3 密钥出现在环境变量中 | 容器编排面板可能显示明文 |
| L2 数据经过未加密的内部通道 | 服务间 mTLS 未启用 |
| L2 数据缓存在共享 Redis | 其他服务可能读取 |
| L4 密钥材料存储在数据库 | 应使用专用 KMS/HSM |

### Phase 4: 数据流图

输出每个敏感数据类型的完整流向图：

```
用户密码 (L3):
  [用户浏览器] --HTTPS--> [API Gateway] --gRPC--> [Auth Service]
    → bcrypt 哈希存储到 [PostgreSQL - users 表]
    → 明文密码已销毁
  ✓ 正常流向

  ⚠ 异常发现: Auth Service 日志中记录了请求体
    → [ELK] 可搜索到明文密码 → HIGH RISK
```

### Phase 5: 输出

```markdown
## 数据流分析报告

### 总览
- 追踪敏感数据类型: X 种 (L2: X, L3: X, L4: X)
- 异常流向: X 条 (Critical: X, High: X)

### 异常流向清单

#### [C-01] 明文密码进入日志
- 类型: L3 机密数据 → 日志系统
- 路径: AuthHandler → log.Info(requestBody) → ELK
- 影响: 运维人员可查看明文密码
- 修复: 日志脱敏中间件，过滤 password/passwd/secret 字段
```
