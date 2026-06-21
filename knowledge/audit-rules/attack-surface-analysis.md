---
name: attack-surface-analysis
description: 系统性地分析代码库的攻击面，识别所有暴露的入口点、接口和数据通道，评估每个暴露面的风险等级。当用户请求安全审计、攻击面评估、暴露面分析、入口点识别、架构安全评审时使用。
category: analysis
topic: [web]
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。
> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。

# 攻击面分析

## 分析方法概述

攻击面是系统所有可能被攻击者利用的入口点的集合。攻击面分析的目标是：
1. **枚举**所有暴露在信任边界之外的接口、端口、API、文件路径
2. **评估**每个暴露面的可达性和影响范围
3. **削减**不必要的暴露面

## 分析流程

### Phase 1: 拓扑识别

构建系统的完整交互拓扑图：

```
外部访问层:
□ 负载均衡/反向代理入口
□ API Gateway 路由
□ CDN 边缘节点
□ DNS 解析入口

应用层:
□ REST/GraphQL/gRPC 端点清单
□ WebSocket 连接点
□ 静态资源路径 (HTML/JS/CSS/图片)
□ 管理后台/控制台入口
□ 健康检查/监控端点

数据层:
□ 数据库端口和协议
□ 消息队列端点
□ 缓存服务接口
□ 对象存储端点

基础设施层:
□ SSH/RDP 管理端口
□ 容器编排 API (K8s API Server)
□ CI/CD Runner 暴露面
□ 监控/日志系统接口 (Prometheus, Grafana, ELK)

内部服务间:
□ 微服务间 RPC 调用
□ 服务网格 sidecar
□ 共享存储/NFS
□ 消息总线
```

### Phase 2: 可达性分析

对每个识别出的入口点，评估：

| 维度 | 评估方法 |
|------|---------|
| 网络可达性 | 公网 vs 内网 vs VPC，是否经过 WAF/防火墙 |
| 认证要求 | 匿名可访问 vs 需要认证 vs 需要特定角色 |
| 协议复杂度 | HTTP/1.1、HTTP/2、WebSocket、TCP、UDP |
| 输入复杂度 | 简单键值对 vs 嵌套 JSON/XML vs 文件上传 vs 二进制协议 |
| 第三方依赖 | 调用了哪些外部服务/数据库/缓存 |

**风险矩阵：**

| 可达性 \ 认证 | 无认证 | 弱认证 | 强认证 |
|--------------|--------|--------|--------|
| 公网 | **Critical** | High | Medium |
| 内网 | High | Medium | Low |
| VPC/内部 | Medium | Low | Low |

### Phase 3: 攻击面削减

对每个暴露面提出削减建议：

```
削减策略（按优先级）:
1. 关闭：不需要的端口、未使用的 API、已下线的服务
2. 限制：将公网访问改为内网，将全量数据改为分页
3. 加固：对必须保留的暴露面添加认证、限流、输入验证
4. 监控：对关键暴露面添加异常检测和告警
```

### Phase 4: 输出

```markdown
## 攻击面分析报告

### 总览
- 识别入口点: X 个
- 高风险暴露面: X 个 (公网可达 + 无/弱认证)
- 建议关闭: X 个 (无需保留的入口点)
- 建议限制: X 个 (可转为内网访问)

### 高风险暴露面清单

| # | 入口 | 协议 | 可达性 | 认证 | 风险 | 建议 |
|---|------|------|--------|------|------|------|
| 1 | /api/admin/debug | HTTP | 公网 | 无 | Critical | 关闭或添加认证 |
| 2 | :9090/metrics | HTTP | 公网 | 无 | High | 改为仅内网 |
| 3 | :5432/postgres | TCP | 公网 | 密码 | High | 改为仅 VPC |
```

## 常见暴露面遗漏

- Actuator 端点 (`/actuator/heapdump`, `/actuator/env`)
- Swagger/OpenAPI 文档 (`/swagger-ui.html`, `/api-docs`)
- GraphQL introspection (`/graphql?query={__schema{types{name}}}`)
- 调试端点 (`/debug/pprof`, `/debug/vars`)
- 错误页面泄露 (`/error`, 堆栈跟踪)
- 默认凭证 (Jenkins, RabbitMQ, Redis 无密码)
