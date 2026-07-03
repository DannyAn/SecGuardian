# 07 — 容器与 Kubernetes 安全 (Container & K8s Security)

> **对应 Sheet:** `07_Container_K8s`
> **牵引方向:** SecGuardian 容器/K8s 安全扫描能力——覆盖镜像安全、运行时保护、RBAC、网络安全和密钥管理。

---

## 1. 概述

容器与 Kubernetes 环境的攻击面远大于传统部署。本 sheet 涵盖 **5 大安全分类**，每类 16~18 条要求，共计 **80+ 条控制项**。

---

## 2. 分类体系

| 分类 | 控制目标 | 严重度分布 | 业界对标 |
|---|---|---|---|
| **Image** (镜像安全) | 确保容器镜像无漏洞、无恶意软件、最小化 | 6×Medium, 6×High, 4×Critical | CIS Docker Benchmark |
| **Runtime** (运行时安全) | 限制容器运行时能力，防止逃逸 | 6×Medium, 6×High, 4×Critical | NIST SP 800-190 |
| **RBAC** (访问控制) | 最小权限的 Kubernetes RBAC | 4×Medium, 6×High, 6×Critical | NSA/Kubernetes Hardening Guide |
| **Network** (网络安全) | 网络隔离与微分区策略 | 6×Medium, 6×High, 4×Critical | Calico / Cilium NetworkPolicy |
| **Secrets** (密钥管理) | 容器化密钥的安全存储与注入 | 6×Medium, 6×High, 4×Critical | External Secrets Operator / Vault |

---

## 3. 分类详解与最佳实践

### 3.1 镜像安全 (Image Security)

**CIS Docker Benchmark 关键项：**

| 控制项 | 检测点 | 严重度 |
|---|---|---|
| IMG-01 | 基础镜像不包含已知 CVE | Critical |
| IMG-02 | 禁止 root 用户运行容器 | High |
| IMG-03 | 镜像签名验证 (Docker Content Trust) | High |
| IMG-04 | 最小化镜像 (Alpine/distroless) | Medium |
| IMG-05 | 不包含调试工具 (curl/vi/netcat) | Medium |
| IMG-06 | 定期 (月度) 基础镜像更新 | Medium |
| IMG-07 | 多阶段构建清理 | Medium |

**镜像安全扫描流程：**

```
Registry Push 触发
   │
   ├─ 漏洞扫描 (Trivy/Grype)
   ├─ 配置检查 (Dockerfile lint → hadolint)
   ├─ 许可证扫描
   └─ 签名验证 (cosign verify)
   │
   ▼
  结果 → 阻断策略 (Critical CVE → 禁止部署)
```

### 3.2 运行时安全 (Runtime Security)

**原则：** 不可变基础设施 + 最小特权。

| 控制项 | 要求 | 严重度 |
|---|---|---|
| RNT-01 | 禁止 privileged 容器 | Critical |
| RNT-02 | 禁止 hostPID/hostNetwork/hostIPC 共享 | Critical |
| RNT-03 | 配置 readOnlyRootFilesystem | High |
| RNT-04 | 设置 CPU/Memory limits 和 requests | Medium |
| RNT-05 | 禁止 allowPrivilegeEscalation | High |
| RNT-06 | 使用 Seccomp / AppArmor / SELinux | Medium |
| RNT-07 | 容器禁止 mount docker.sock | Critical |
| RNT-08 | 设置 SecurityContext (runAsNonRoot) | High |

**运行时威胁检测：**

- Falco 规则集（文件系统异常/网络异常/进程异常）
- 容器逃逸检测（如 `--privileged` 启动的容器检查 namespace 可达性）

### 3.3 RBAC（访问控制）

**最小权限原则：**

| 控制项 | 要求 | 严重度 |
|---|---|---|
| RBAC-01 | 禁止 cluster-admin 角色用于非管理服务 | Critical |
| RBAC-02 | 使用 role 而非 clusterRole（限制 namespace） | High |
| RBAC-03 | 每个 ServiceAccount 绑定最小权限 role | High |
| RBAC-04 | 定期审计 RBAC 绑定关系 | Medium |
| RBAC-05 | 禁止匿名用户/未认证访问 | Critical |
| RBAC-06 | 创建服务账号专用，不共享默认的 default SA | Medium |

**Kubernetes RBAC 安全模型：**

```
Subject (User/SA) → RoleBinding/ClusterRoleBinding → Role/ClusterRole → Resources + Verbs
```

**最小权限示例：**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: myapp
rules:
- apiGroups: [""]
  resources: ["pods", "configmaps"]
  verbs: ["get", "list", "watch"]  # 不需要 create/delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
subjects:
- kind: ServiceAccount
  name: myapp-sa
roleRef:
  kind: Role
  name: myapp-role
```

### 3.4 网络安全 (Network Security)

**控制项要求：**

| 控制项 | 要求 | 严重度 |
|---|---|---|
| NET-01 | 默认 Deny 所有入口流量 | High |
| NET-02 | 默认 Deny 所有出口流量 | High |
| NET-03 | 只开放必要端口 | Medium |
| NET-04 | 命名空间间流量受 NetworkPolicy 控制 | Critical |
| NET-05 | 传输加密 (mTLS) 服务间通信 | Medium |
| NET-06 | 禁止对外暴露管理端口 | High |

**NetworkPolicy 最佳实践：**

```yaml
# 默认拒绝所有入口
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
# 允许特定端口
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api
spec:
  podSelector:
    matchLabels:
      app: myapp
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
```

### 3.5 密钥管理 (Secrets Management)

| 控制项 | 要求 | 严重度 |
|---|---|---|
| SEC-01 | 禁止 K8s Secrets 落盘加密 | Critical |
| SEC-02 | 使用 External Secrets Operator / Vault 注入 | High |
| SEC-03 | secrets 不存储在 ConfigMap 中 | Critical |
| SEC-04 | ETCD 配置加密 | High |
| SEC-05 | 密钥自动轮转 | Medium |
| SEC-06 | 审计密钥访问日志 | Medium |

---

## 4. 业界工具对标

| 工具 | 场景 | 开源/商业 |
|---|---|---|
| **Trivy** | 镜像漏洞扫描 | 开源 |
| **Falco** | 运行时威胁检测 | 开源/CNCF |
| **Kube-bench** | CIS 基准检测 | 开源 |
| **Kube-hunter** | 渗透测试 | 开源 |
| **OPA / Gatekeeper** | K8s 准入控制策略 | 开源/CNCF |
| **Kyverno** | K8s 策略引擎 | 开源/CNCF |
| **External Secrets Operator** | 密钥管理 | 开源/CNCF |

---

## 5. SecGuardian 牵引方向

### 5.1 当前缺口

SecGuardian 当前聚焦代码级安全，**容器/K8s 安全能力完全缺失**。

### 5.2 发展路线

| 阶段 | 能力建设 | 关键集成 |
|---|---|---|
| **Phase 1** | K8s 资源清单静态分析 | 集成 kube-bench 规则 / OPA 策略 |
| **Phase 2** | 镜像安全扫描 | 集成 Trivy |
| **Phase 3** | 运行时安全接入 | 集成 Falco 告警 |
| **Phase 4** | 准入控制器策略 | 集成 Gatekeeper / Kyverno |

### 5.3 与 secguard skill 融合

```
secguard — 安全基线扫描
   │
   ├─ 代码基线 (CIS 编码)  [已存在]
   ├─ K8s 配置基线 (CIS K8s)  [Phase 1]
   ├─ 镜像安全基线 (CIS Docker)  [Phase 2]
   └─ 运行时安全基线 (NIST 800-190)  [Phase 3]
```

---

> **本文档指引 SecGuardian 扩展至容器与 K8s 安全领域。**
> 与 [08_Cloud_Security](08_Cloud_Security.md) 的云层安全配置形成"容器+云"一体化防护。
