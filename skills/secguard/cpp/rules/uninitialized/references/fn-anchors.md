> **定位**: 防退步回归锚点 — 回答"我们历史上漏过什么？增强后还能检出吗？" | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 漏检回归锚点 (False Negative Anchors)

## FN-001: heap_struct_partial_init

- **模式**: malloc 分配结构体后仅初始化部分字段，未初始化字段被读取
- **漏检根因层**: L1 Signal Gap — 索引器无 struct_init 信号 + L2 Rule Gap — memory.uninitialized 规则不存在
- **增强措施**: 新增 S9 StructInit 信号 + 创建 memory.uninitialized 规则
- **应检出**: `memory.uninitialized`
- **期望 severity**: High (CWE-908)
- **增强日期**: 2026-07-10

```c
struct Config {
    char *path;
    int flags;        // 未初始化
    int debug_level;  // 未初始化
};
struct Config *cfg = malloc(sizeof(struct Config));
cfg->path = strdup("/etc/app");
printf("debug=%d\n", cfg->debug_level);  // 读取未初始化字段
```

- [ ] 索引器产出 struct_inits[category="partial_init"] 信号
- [ ] memory.uninitialized 规则触发（Scenario 1）
- [ ] P2 检查无 calloc/memset 抑制

---

## FN-002: stack_struct_partial_init

- **模式**: 栈上声明结构体，仅初始化部分字段，未初始化字段被读取
- **漏检根因层**: 同上（L1+L2）
- **增强措施**: 同上
- **应检出**: `memory.uninitialized`
- **期望 severity**: High (CWE-457)
- **增强日期**: 2026-07-10

```c
void parse() {
    struct Request req;     // 栈变量，内存未定义
    req.client_ip = get_ip();
    if (req.method == POST) {  // 读取未初始化字段
        handle_post(&req);
    }
}
```

- [ ] 索引器产出 struct_inits[category="no_init"] 信号
- [ ] memory.uninitialized 规则触发（Scenario 2）
- [ ] P2 检查无 ={0}/memset 抑制

---

## FN-003: local_var_read_before_write

- **模式**: 局部栈变量未赋值即被读取
- **漏检根因层**: L1 Signal Gap — 索引器无 variable_write 信号
- **增强措施**: 新增 S10 VariableWrite 信号
- **应检出**: `memory.uninitialized`
- **期望 severity**: High (CWE-457)
- **增强日期**: 2026-07-10

```c
int process_flag() {
    int flag;             // 未初始化
    if (flag == 1) {      // UB: 读前未写
        return 1;
    }
    return 0;
}
```

- [ ] 索引器产出 variable_writes[category="read_before_write"] 信号
- [ ] memory.uninitialized 规则触发（Scenario 3）
- [ ] P2 检查无声明时初始化器抑制
