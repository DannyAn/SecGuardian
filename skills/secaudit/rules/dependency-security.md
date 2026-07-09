---
name: dependency-security
description: 审计项目第三方依赖的安全性，检测已知漏洞、供应链攻击风险、许可证合规和过时依赖问题。当用户请求依赖安全审计、供应链安全、开源漏洞检测、SBOM审查、第三方库风险评估时使用。
category: domain
topic: [system]
severity: Medium
cwe: CWE-000
mapped_to: OWASP ASVS V14 (Dependency)
cvss: 5.5
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。
> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。


# 依赖安全审计

## 审计概览

现代应用 80%+ 的代码来自第三方依赖。审计覆盖：
- **已知漏洞 (CVE)**：依赖中是否存在已披露的漏洞
- **供应链风险**：依赖来源是否可信、构建过程是否安全
- **维护状态**：依赖是否被活跃维护、是否已废弃
- **许可证合规**：依赖许可证是否与项目兼容

## 审计流程

### Phase 1: 依赖清单

生成完整的依赖树：

```bash
# Java (Maven)
mvn dependency:tree -DoutputFile=deps.txt

# Java (Gradle)
gradle dependencies --configuration runtimeClasspath

# Python
pipdeptree --json > deps.json

# Go
go mod graph

# Node.js
npm ls --all --json

# C/C++
# CMake find_package 和 FetchContent 清单
# Conan/Vcpkg 依赖文件
```

### Phase 2: 检查清单

#### 2.1 已知漏洞

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 是否存在 Critical/High CVE 依赖 | 使用 OWASP Dependency-Check / Snyk / Trivy / OSV Scanner |
| [C] | 漏洞是否有可用的修复版本 | 检查 CVE 对应 CVE 的 Fixed Version |
| [H] | 是否存在可被远程利用的漏洞 | 检查 CVE Vector String (AV:N + UI:N) |
| [H] | 间接依赖是否包含漏洞 | 传递依赖（transitive deps）常常被忽略 |
| [H] | 是否存在未申报的依赖 | 检查 vendor/、lib/、dll/ 等手动管理的依赖 |

#### 2.2 供应链安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 是否使用了废弃/恶意的包 | 检查是否有 typo-squatting、突然更换维护者的包 |
| [H] | 是否校验依赖完整性 | Maven/Gradle checksum、npm integrity、Go sumdb |
| [H] | 是否使用私有仓库代理 | 是否有内部 Nexus/Artifactory 代理外部仓库 |
| [H] | 是否锁定依赖版本 | pom.xml/package.json 是否有版本范围（^1.0.0） |
| [M] | CI/CD 中是否检查依赖 | 每次构建是否运行依赖扫描 |

#### 2.3 维护状态

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | 是否存在已废弃 (EOL) 的依赖 | 检查依赖的上一个发布日期 |
| [H] | 是否依赖了个人维护的库 | 单维护者、低 star 数、无 CI/CD |
| [M] | 是否需要升级主版本 | 是否还在用 Spring Boot 2.x / Django 3.x 等旧主线 |

#### 2.4 许可证合规

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | 是否存在 Copyleft 许可证冲突 | GPL/AGPL 与商业闭源软件的兼容性 |
| [M] | 是否有未知许可证 | LICENSE 文件缺失或 License 字段为空 |
| [M] | 是否遵守了署名要求 | MIT/Apache 等许可证要求在分发时保留版权声明 |

### Phase 3: 常见风险模式

#### 模式 1: 传递依赖中的高危漏洞

```xml
<!-- pom.xml 仅声明了直接依赖 -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <version>2.7.0</version>
</dependency>

<!-- 但传递依赖中包含了：
  - spring-beans 5.3.20 (CVE-2022-22965, Spring4Shell, CVSS 9.8)
  - jackson-databind 2.13.3 (CVE-2022-42003, CVSS 7.5)
  - logback 1.2.11 (CVE-2021-42550, CVSS 8.5)
-->
```

#### 模式 2: 版本范围漂移

```json
// package.json — BAD: 使用了 ^ 版本范围
{
    "dependencies": {
        "express": "^4.17.0"   // 实际可能安装了 4.19.2，引入了新漏洞
    }
}

// GOOD: 使用精确版本 + lockfile
{
    "dependencies": {
        "express": "4.17.21"
    }
}
// package-lock.json 锁定所有传递依赖的精确版本
```

#### 模式 3: 废弃维护者的包劫持

```
审计发现: npm 包 `left-pad` 维护者已删除并转移给新维护者
- 新版本 1.5.0 中插入了恶意代码
- 项目未锁定版本，CI 自动安装了最新版
- 代码已进入生产环境

检查方法: 对比当前版本和历史版本的 git diff/行为差异
```

### Phase 4: 输出

```markdown
## 依赖安全审计报告

### 总览
- 总依赖数: X (直接依赖: X, 传递依赖: X)
- Critical CVE: X, High CVE: X, Medium CVE: X
- 过期依赖: X (EOL: X, 1+ 年未更新: X)

### 高危发现

#### [C-01] Log4Shell (CVE-2021-44228) — log4j-core 2.14.1
- 依赖链: spring-boot-starter-log4j2 → log4j-core 2.14.1
- CVSS: 10.0 — 远程代码执行
- 修复: 升级到 2.17.1+

#### [C-02] jackson-databind 反序列化 (CVE-2022-42003)
- 依赖链: spring-boot-starter-web → jackson-databind 2.13.3
- CVSS: 7.5 — DoS
- 修复: 升级到 2.13.4.2
```
