---
category: protocol
version: "1.1"
standard: "SARIF 2.1.0 (OASIS Standard)"
---

# SecGuardian SARIF 输出协议

SecGuardian 所有命令可选的 SARIF 2.1.0 输出格式。SARIF 是 GitHub Code Scanning、GitLab SAST、Azure DevOps 等平台的原生输入格式。

## 启用方式

在执行 `/secguard`、`/secaudit`、`/secreview` 时附加 `--sarif` 参数，将在 `manifest.json` 同级目录生成 `results.sarif`。

```
.codeagent/<extension-name>/scans/<scan-id>/
├── manifest.json
├── results.sarif          # SARIF 2.1.0 标准输出
└── findings/
```

## v1.1 新增要求

| 字段 | v1.0 状态 | v1.1 要求 | 说明 |
|------|----------|----------|------|
| `message.markdown` | 不存在 | **必须** | 完整四段式富文本（📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix） |
| `relatedLocations[]` | 不存在 | **必须**（如有数据流） | Source → Propagation → Sink 路径标注 |
| `taxa[]` | 不存在 | 推荐 | CWE 分类引用 |
| `contextRegion` | 已支持 | 增强（前后 3 行） | 更多代码上下文 |
| `properties` | 已支持 | 增强 | 增加 `cvss_vector`, `verification` |

### message.markdown 模板

每个 result 的 `message.markdown` 必须包含完整四段式：

```markdown
## 📍 Location
| 属性 | 值 |
|------|-----|
| **文件** | `src/parser.c:42` |
| **函数** | `parse_input()` |
| **检测器** | `memory.buffer-overflow` |
| **CWE** | [CWE-120](https://cwe.mitre.org/data/definitions/120.html) |
| **CVSS** | 9.8 (Critical) |

## 📋 Evidence
判定依据说明...

```c
char buf[64];
strcpy(buf, user_input);  // ← 漏洞点
process(buf);
```

**数据流**: `argv[1]` → `user_input` → `strcpy(buf, ...)` → 栈溢出

## ⚠️ Impact
攻击场景描述...

**CVSS 3.1 Vector**: AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H

## 🔧 Fix
```c
// ❌ Before
strcpy(buf, user_input);

// ✅ After
strncpy(buf, user_input, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';
```

**工作量**: ~5 min | **风险**: 无 | **验证**: 输入 > 64 字节测试

**参考**: [CWE-120](https://cwe.mitre.org/data/definitions/120.html) | [SEI CERT STR31-C](https://wiki.sei.cmu.edu/confluence/x/1dUxBQ)
```

## 严重度映射

| SecGuardian | SARIF level | GitHub 标签 |
|-------------|-------------|------------|
| critical | error | 阻断合并 |
| high | error | 阻断合并 |
| medium | warning | 警告 |
| low | note | 备注 |
| info | none | 信息 |

## SARIF Schema 完整示例

```json
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "SecGuardian",
          "fullName": "SecGuardian - AI-Native Security Guardian",
          "version": "0.1.0",
          "informationUri": "https://secguardian.dev",
          "organization": "SecGuardian",
          "rules": [
            {
              "id": "SECGUARD-memory-buffer-overflow",
              "name": "BufferOverflow",
              "shortDescription": {
                "text": "缓冲区溢出检测 — 固定大小缓冲区写入可能超出容量"
              },
              "fullDescription": {
                "text": "检查 strcpy/strcat/sprintf/memcpy 等操作是否可能导致目标缓冲区溢出，覆盖相邻内存。"
              },
              "helpUri": "https://cwe.mitre.org/data/definitions/120.html",
              "properties": {
                "cwe": "CWE-120",
                "cvss": 9.8,
                "category": "memory",
                "precision": "medium",
                "confidence-level": "AI-assisted"
              }
            },
            {
              "id": "SECGUARD-system-command-injection",
              "name": "CommandInjection",
              "shortDescription": {
                "text": "命令注入 — 不可信输入传递给 shell 执行函数"
              },
              "fullDescription": {
                "text": "检查 system()/popen()/exec*() 的参数是否来自用户输入或外部数据源。"
              },
              "helpUri": "https://cwe.mitre.org/data/definitions/77.html",
              "properties": {
                "cwe": "CWE-77",
                "cvss": 9.8,
                "category": "system",
                "precision": "high"
              }
            }
          ]
        }
      },
      "invocations": [
        {
          "executionSuccessful": true,
          "startTimeUtc": "2026-05-24T10:30:00Z",
          "endTimeUtc": "2026-05-24T10:30:02Z"
        }
      ],
      "results": [
        {
          "ruleId": "SECGUARD-memory-buffer-overflow",
          "ruleIndex": 0,
          "level": "error",
          "message": {
            "text": "📍 src/parser.c:42 parse_input() [Critical] CWE-120: strcpy(buf, user_input) 缓冲区溢出 — user_input 来自 argv[1]，无长度检查",
            "markdown": "## 📍 Location\n\n| 属性 | 值 |\n|------|----|\n| **文件** | `src/parser.c:42` |\n| **函数** | `parse_input()` |\n| **CWE** | [CWE-120](https://cwe.mitre.org/data/definitions/120.html) |\n| **CVSS** | 9.8 (Critical) |\n\n## 📋 Evidence\n\n**判定依据**: `strcpy()` 的目标缓冲区 `buf[64]` 是固定大小栈缓冲区，源 `user_input` 来自 `argv[1]`（攻击者完全可控），拷贝无任何长度检查。\n\n```c\nchar buf[64];\nstrcpy(buf, user_input);  // ← 漏洞点\nprocess(buf);\n```\n\n**数据流**: `argv[1]` → `user_input` → `strcpy(buf, ...)` → 栈溢出\n\n## ⚠️ Impact\n\n攻击者可构造超长输入（>64字节）覆盖栈帧返回地址 → **远程代码执行 (RCE)**。\n\n**CVSS 3.1**: 9.8 (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H)\n\n## 🔧 Fix\n\n```c\n// ❌ Before\nstrcpy(buf, user_input);\n\n// ✅ After\nstrncpy(buf, user_input, sizeof(buf) - 1);\nbuf[sizeof(buf) - 1] = '\\0';\n```\n\n**工作量**: ~5 min | **风险**: 无 | **验证**: 输入 > 64 字节测试 | **参考**: [CWE-120](https://cwe.mitre.org/data/definitions/120.html) | [SEI CERT STR31-C](https://wiki.sei.cmu.edu/confluence/x/1dUxBQ)"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "src/parser.c",
                  "uriBaseId": "%SRCROOT%"
                },
                "region": {
                  "startLine": 42,
                  "startColumn": 10,
                  "endLine": 42,
                  "endColumn": 35,
                  "snippet": {
                    "text": "    strcpy(buf, user_input);"
                  }
                },
                "contextRegion": {
                  "startLine": 40,
                  "endLine": 44,
                  "snippet": {
                    "text": "char buf[64];\nif (input) {\n    strcpy(buf, user_input);\n    process(buf);\n}"
                  }
                }
              }
            }
          ],
          "relatedLocations": [
            {
              "physicalLocation": {
                "artifactLocation": { "uri": "src/parser.c" },
                "region": { "startLine": 38, "snippet": { "text": "char buf[64];" } }
              },
              "message": { "text": "📋 目标缓冲区: 64字节栈缓冲区 buf" }
            },
            {
              "physicalLocation": {
                "artifactLocation": { "uri": "src/main.c" },
                "region": { "startLine": 15, "snippet": { "text": "parse_input(argv[1]);" } }
              },
              "message": { "text": "⬆️ Source: user_input = argv[1] (攻击者可控)" }
            }
          ],
          "fixes": [
            {
              "description": {
                "text": "将 strcpy 替换为 strncpy，确保 null 终止"
              },
              "artifactChanges": [
                {
                  "artifactLocation": {
                    "uri": "src/parser.c"
                  },
                  "replacements": [
                    {
                      "deletedRegion": {
                        "startLine": 42,
                        "startColumn": 5,
                        "endLine": 42,
                        "endColumn": 35
                      },
                      "insertedContent": {
                        "text": "strncpy(buf, user_input, sizeof(buf) - 1);\nbuf[sizeof(buf) - 1] = '\\0';"
                      }
                    }
                  ]
                }
              ]
            }
          ],
          "properties": {
            "finding_id": "C-001",
            "confidence": "high",
            "impact": "攻击者可构造超长输入实现任意代码执行 (RCE)",
            "effort": "low",
            "risk_of_fix": "none",
            "detector_namespace": "memory",
            "detector_name": "buffer-overflow"
          }
        },
        {
          "ruleId": "SECGUARD-system-command-injection",
          "ruleIndex": 1,
          "level": "error",
          "message": {
            "text": "[Critical] 命令注入: popen(user_cmd, \"r\") 中 user_cmd 直接来自 HTTP 请求参数，未经过滤。攻击者可注入任意系统命令。"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "src/executor.c",
                  "uriBaseId": "%SRCROOT%"
                },
                "region": {
                  "startLine": 89,
                  "startColumn": 18,
                  "endLine": 89,
                  "endColumn": 37,
                  "snippet": {
                    "text": "FILE *fp = popen(user_cmd, \"r\");"
                  }
                }
              }
            }
          ],
          "fixes": [
            {
              "description": {
                "text": "使用白名单校验命令，或 execve 传递结构化参数"
              },
              "artifactChanges": [
                {
                  "artifactLocation": {
                    "uri": "src/executor.c"
                  },
                  "replacements": [
                    {
                      "deletedRegion": {
                        "startLine": 89,
                        "endLine": 89
                      },
                      "insertedContent": {
                        "text": "// Validate command against allowlist before execution\nif (!is_command_allowed(user_cmd)) { return ERROR; }\nFILE *fp = popen(user_cmd, \"r\");"
                      }
                    }
                  ]
                }
              ]
            }
          ],
          "properties": {
            "finding_id": "C-002",
            "confidence": "high",
            "impact": "攻击者可执行任意系统命令",
            "effort": "medium",
            "risk_of_fix": "none",
            "detector_namespace": "system"
          }
        }
      ],
      "columnKind": "utf16CodeUnits",
      "newlineSequences": ["\r\n", "\n"]
    }
  ]
}
```

## SARIF 字段映射速查

| SecGuardian finding.json | SARIF result |
|--------------------------|-------------|
| `id` | `properties.finding_id` |
| `severity` | `level` (critical/high→error, medium→warning, low→note, info→none) |
| `title` | `message.text` (格式: `📍 {FILE}:{LINE} {FUNC}() [{SEVERITY}] {CWE}: {TITLE} — {EVIDENCE_SUMMARY}`，SARIF viewer 主要展示) |
| `detector.name` | `ruleId` (格式: `SECGUARD-{namespace}-{detector}`) |
| `detector.cwe` | `driver.rules[].properties.cwe` |
| `detector.cvss` | `driver.rules[].properties.cvss` |
| `location.file` | `artifactLocation.uri` |
| `location.line` | `region.startLine` |
| `location.column` | `region.startColumn` |
| `code.snippet` | `region.snippet.text` |
| `code.context` | `contextRegion` (before + vulnerable + after) |
| `analysis.description` | `message.text` (合并到消息中) |
| `analysis.impact` | `properties.impact` |
| `analysis.confidence` | `properties.confidence` |
| `remediation.code_before` | `fixes[].artifactChanges[].replacements[].deletedRegion` |
| `remediation.code_after` | `fixes[].artifactChanges[].replacements[].insertedContent` |
| `remediation.effort` | `properties.effort` |
| `diff_status` | `properties.diff_status` (扩展属性) |

## 与 GitHub Code Scanning 集成

GitHub Code Scanning 消费 SARIF 文件的关键要求：

1. **`ruleId` 必须唯一且稳定** — 同一种漏洞类型应始终使用相同的 ruleId
2. **`level` 必须明确** — error/warning/note/none，不可省略
3. **`artifactLocation.uri` 必须相对于仓库根目录**
4. **结果去重** — GitHub 使用 `ruleId + artifactLocation.uri + startLine` 三元组去重

### GitHub Actions 中上传 SARIF

```yaml
- name: Upload SecGuardian SARIF results
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: .codeagent/secaudit-secguardian/scans/latest/results.sarif
    category: secguardian-security-audit
```

## 与 GitLab SAST 集成

GitLab SAST 要求：

1. SARIF 文件输出到约定的 artifact 路径
2. `ruleId` 不要求特定前缀
3. 支持 `GitLab` 扩展属性

```yaml
secguardian-scan:
  artifacts:
    reports:
      sast: .codeagent/secaudit-secguardian/scans/latest/results.sarif
```

## 生成规则

执行扫描时生成 SARIF 的规则：

1. **必须生成 `driver.rules[]`** — 列出本次扫描所有使用的检测器/分析方法，每个条目包含 `id`、`name`、`shortDescription`、`properties.cwe`
2. **每个 finding 映射为一个 `result`** — `ruleId` 引用 `rules[].id`，`ruleIndex` 引用数组索引
3. **合并多条发现的 message** — 如果同一行有多个相关发现，合并为一条 result，使用多行 message
4. **置信度字段** — 在每个 result 的 `properties.confidence` 中标识 AI 判断的置信度：`high`（确定）/ `medium`（可能）/ `low`（待确认），方便用户按置信度过滤
5. **必须包含 `partialFingerprints`** — 使用 `ruleId + file + line + snippet_hash` 生成稳定指纹，支持 GitHub 的结果追踪
6. **message.markdown 必须包含完整四段式** — 格式见上文 `message.markdown 模板`，不可省略任何一段
