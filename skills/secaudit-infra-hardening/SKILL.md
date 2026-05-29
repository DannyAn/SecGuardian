---
name: secaudit-infra-hardening
description: 审计容器、Kubernetes、云资源和CI/CD管道的基础设施安全配置，检测配置缺陷和加固缺失
category: domain
topic: system
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。

# 基础设施加固审计

## 审计概览

基础设施即代码（IaC）的安全配置直接影响所有上层应用的安全。审计覆盖：
- **容器安全**：Dockerfile、镜像、运行时配置
- **K8s 安全**：集群配置、RBAC、网络策略、Pod 安全
- **云资源安全**：安全组、IAM、存储、密钥管理
- **CI/CD 安全**：流水线权限、凭证管理、构建隔离

## 审计流程

### Phase 1: 容器安全

#### 检查清单

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 容器是否以 root 运行 | 检查 Dockerfile `USER` 指令和 k8s `runAsNonRoot` |
| [C] | 是否使用 latest 标签 | `image: nginx:latest` 可能引入未经审计的变更 |
| [H] | 镜像是否经过签名 | Docker Content Trust / Cosign / Notary 验证 |
| [H] | 文件系统是否只读 | `readOnlyRootFilesystem: true` |
| [H] | capabilities 是否最小化 | 检查 `--cap-drop=ALL --cap-add=NET_BIND_SERVICE` |
| [H] | 是否允许特权容器 | `privileged: true` 应禁止 |
| [H] | 资源是否有限制 | CPU/Memory limits 防止 DoS |
| [M] | 基础镜像是否最小化 | distroless / alpine vs ubuntu/debian full |
| [M] | 是否使用了多阶段构建 | 减少最终镜像的攻击面 |

```dockerfile
# BAD: 典型的不安全 Dockerfile
FROM ubuntu:latest
RUN apt-get update && apt-get install -y nginx
COPY . /app
CMD ["nginx", "-g", "daemon off;"]
# 问题: root 运行、latest tag、全量 ubuntu 镜像、无健康检查

# GOOD: 安全加固的 Dockerfile
FROM nginx:1.25-alpine@sha256:abc123
RUN addgroup -S app && adduser -S app -G app
COPY --chown=app:app . /app
USER app
HEALTHCHECK --interval=30s CMD wget -q http://localhost/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

### Phase 2: Kubernetes 安全

#### 检查清单

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | RBAC 是否最小权限 | 检查 ClusterRoleBinding 中是否有过度宽松的权限 |
| [C] | Pod Security Standards | 检查是否使用 restricted profile |
| [H] | NetworkPolicy 是否配置 | 检查是否限制了 Pod 间通信 |
| [H] | Secret 是否加密存储 | 检查 etcd 是否启用 encryption at rest |
| [H] | ServiceAccount 是否自动挂载 | `automountServiceAccountToken: false` 适用于不需要的 Pod |
| [H] | API Server 是否暴露 | 检查 k8s API 的公网可达性 |
| [H] | 是否限制了 hostPath/hostNetwork | 防止容器逃逸 |
| [M] | 容器镜像仓库是否私有 | 检查是否允许从公网拉取任意镜像 |
| [M] | 审计日志是否启用 | k8s API audit log |

#### 关键检查模式

```yaml
# BAD: Deployment 缺少安全上下文
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:latest
        # 无 securityContext!
        # 无 resources limits!
        # 无 readOnlyRootFilesystem!

# GOOD: 安全加固的 Pod
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      serviceAccountName: app-sa  # 专用 SA，非 default
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: app
        image: myapp:1.2.3@sha256:def456
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        resources:
          limits:
            cpu: "1"
            memory: "512Mi"
          requests:
            cpu: "100m"
            memory: "128Mi"
```

### Phase 3: 云资源安全

#### 检查清单

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | S3/对象存储是否公开 | 检查 Bucket Policy 中的 `Principal: *` |
| [C] | 安全组是否开放了敏感端口 | 22(SSH)/3389(RDP)/3306(MySQL) 对 0.0.0.0/0 |
| [H] | IAM 策略是否最小权限 | 检查是否使用 `*` Resource + `*` Action |
| [H] | IAM 用户是否使用 MFA | 检查所有人类用户的 MFA 状态 |
| [H] | 是否使用临时凭证 | IAM Role (EC2/Lambda) 优先于长期 Access Key |
| [H] | 数据库是否公网可达 | RDS/Redshift 是否在 public subnet |
| [H] | KMS 密钥轮换是否启用 | 检查密钥轮换配置 |
| [M] | CloudTrail 是否启用 | API 调用审计日志 |
| [M] | VPC Flow Logs 是否启用 | 网络流量审计 |

### Phase 4: CI/CD 安全

#### 检查清单

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 流水线是否有未授权的触发者 | fork PR 是否可以触发具有 Secret 访问权限的流水线 |
| [C] | Secret 是否明文在日志中 | 检查 CI 日志输出 |
| [H] | Secret 是否按环境隔离 | dev pipeline 是否有 prod Secret |
| [H] | 构建环境是否隔离 | 每次构建是否使用干净的 runner |
| [H] | 是否有代码审查门禁 | MR/PR 是否需要审批才能合并 |
| [H] | 依赖是否在构建时验证 | 是否检查 checksum/signature |
| [M] | Artifact 是否有签名 | 构建产物是否有数字签名 |

### Phase 5: 输出格式

```markdown
## 基础设施加固审计报告

### 容器安全 (Docker): 7 发现
- [C-01] 5个服务以 root 运行 → runAsNonRoot: true
- [H-01] 3个服务使用 latest 标签 → 固定版本+摘要

### K8s 安全: 5 发现  
- [C-01] default ServiceAccount 挂载到所有 Pod
- [H-01] 无 NetworkPolicy，Pod 间全通

### 云资源 (AWS): 4 发现
- [C-01] 开发 S3 Bucket 公开可读
- [H-01] 2个 IAM 用户超过 90 天未轮换 Access Key

### CI/CD 安全: 3 发现
- [C-01] Fork PR 可触发 main 分支流水线（含生产 Secret）
```
