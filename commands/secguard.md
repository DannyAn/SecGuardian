# /secguard - 安全加固项排查

对源码执行安全加固扫描。支持全量扫描和 Git diff 增量扫描，支持命名空间过滤和逗号组合。

## 使用方式

```
/secguard <path> [mode] [filters]

全量扫描:
  /secguard ./src                                    # 全部检测器
  /secguard ./src memory.*                           # 内存检测器
  /secguard ./src memory.null-dereference            # 单个检测器
  /secguard ./src memory.*,system.*,crypto.*         # 多过滤器组合

增量扫描:
  /secguard ./src git diff                           # 工作区变更
  /secguard ./src git diff HEAD~1                    # 最近一次提交
  /secguard ./src git diff main                      # 当前分支 vs main
  /secguard ./src git diff main...feature            # 分支差异
  /secguard ./src git diff HEAD~1 memory.*           # 增量 + 过滤

SARIF 输出 (CI/CD 集成):
  /secguard ./src --sarif                            # 附加 SARIF 2.1.0 输出
  /secguard ./src memory.*,system.* --sarif          # 过滤 + SARIF
```

## 输出

扫描结果写入 `.codeagent/secguard-secguardian/scans/<scan-id>/`：

```
.codeagent/secguard-secguardian/scans/2026-05-23T14-30-00-a1b2/
├── manifest.json            # 扫描摘要 + 检出索引
└── findings/
    ├── C-001.json            # Critical 检出
    ├── H-001.json            # High 检出
    └── ...
```

### 输出协议

遵循 [Scan Output Protocol 1.0](../../knowledge/protocols/scan-output.md)。

**执行完毕后必须输出扫描摘要和 scan-id：**

```
## secguard 扫描完成

Scan ID: 2026-05-23T14-30-00-a1b2
Path: ./src
Mode: git diff HEAD~1
Filters: memory.*, system.*

### 结果
- 扫描文件: 12 (变更行: 95)
- 检测器: 18 matched, 8 executed
- 检出: 3 (Critical: 1, High: 2)

### 检出
| ID | Severity | Detector | File |
|----|----------|----------|------|
| C-001 | Critical | memory.buffer-overflow | src/parser.c:42 |
| H-001 | High | memory.null-dereference | src/network.c:305 |
| H-002 | High | system.command-injection | src/executor.c:89 |

输出目录: .codeagent/secguard-secguardian/scans/2026-05-23T14-30-00-a1b2/
```

## 命名空间

| Namespace | 覆盖范围 | 检测器数 |
|-----------|---------|---------|
| `memory` | 内存安全 + 内存管理 | 12 |
| `concurrency` | 并发安全 | 4 |
| `system` | 系统安全 | 6 |
| `crypto` | 加密与密钥 | 4 |
| `critical` | 所有 Critical 严重度 | 跨 namespace |
| `*` (默认) | 全部 | 26 |

## 派发规则

1. 解析 `path`、`mode`、`filters` → 语言检测
2. Filter 解析（逗号分割 → detector-index 匹配 → 去重合并）
3. 按严重度排序执行匹配到的检测器
4. 增量模式下仅分析 diff 中的 `+` 行
5. 按协议 1.0 写入输出目录
