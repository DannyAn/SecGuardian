> **定位**: 防退步回归锚点 — 回答"我们历史上漏过什么？增强后还能检出吗？" | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)
>
> 本文件记录线上漏检的缺陷模式。每个锚点对应一个可复现的检测增强，AI 在调查信号时应对照这些模式确认检出能力是否退化。

# 漏检回归锚点 (False Negative Anchors)

## FN-001: pointer_param_missing_null_check

- **模式**: 函数接收指针入参（非 system/popen/getenv 类），无 NULL 校验直接解引用
- **漏检根因层**: L2 Rule Gap — signal_source 仅覆盖 call_sites[cat="exec"]，不覆盖通用指针参数
- **增强措施**: 扩展 signal_source 至 pointer_validations[cat="param_check" ...]
- **应检出**: `exec.input_validation`
- **期望 severity**: High (CWE-20)
- **增强日期**: 2026-07-10

```c
// 漏检示例：指针 p 来自调用者，无 NULL 检查直接解引用
void process_record(Record *p) {
    p->id = 42;            // 未校验 p != NULL
    printf("id=%d\n", p->id);
}
```

- [ ] 索引器产出 pointer_validations 信号
- [ ] 规则触发并判定 CONFIRMED/SUSPICIOUS
- [ ] P2 不误抑制（无 RAII 包装器、无显式 NULL 检查）

---

## FN-002: path_traversal_no_realpath_validation

- **模式**: 用户提供的文件路径直接拼接后 fopen，无 realpath 校验
- **漏检根因层**: L1 Signal Gap — 已通过现有 call_sites 覆盖，但需要 signal_source 更精确匹配
- **增强措施**: 规则已有此覆盖，此为回归锚点
- **应检出**: `exec.input_validation`
- **期望 severity**: High (CWE-22)
- **增强日期**: 2026-07-10

```c
// 漏检示例：filename 来自用户，直接拼接到路径
char path[512];
snprintf(path, sizeof(path), "/var/data/%s", filename);
FILE *f = fopen(path, "r");  // filename = "../../etc/passwd"
```

- [ ] 索引器产出 call_sites 信号（fopen + argv/外部输入路径）
- [ ] 规则判定路径穿越模式
- [ ] P2 检查 realpath/前缀校验不存在
