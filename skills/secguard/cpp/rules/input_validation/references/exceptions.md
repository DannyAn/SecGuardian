> **定位**: 定义哪些看似缺少输入验证的场景实际是安全的 | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 输入验证例外规则

## 安全模式（不报告）

1. **已知安全来源**: 输入来自受信任的内部函数、编译期常量、配置文件（非用户可写路径）→ 不报告
2. **双重验证**: 输入已经过长度 + 类型 + 范围检查 → 不报告
3. **白名单过滤**: 输入已通过白名单验证（只允许特定字符集）→ 不报告
4. **固定格式**: 输入来自固定格式的内部数据结构（如序列化的枚举值）→ 不报告

## 可信调用者与上游验证

以下场景表明数据已经过可信路径验证，**不报告**：

1. **受信任内部调用者**: 函数仅被同一编译单元内的内部函数调用，调用者在调用前已完成验证
   ```c
   // 不报告：internal_user() 是唯一调用者，已验证输入
   static void internal_user(void) {
       char buf[64];
       if (read_and_validate(buf, sizeof(buf))) {  // 已验证
           process_data(buf);  // process_data 接收已验证数据
       }
   }
   ```
2. **编译期常量输入**: 输入值在编译期确定，不可被外部篡改
   ```c
   // 不报告：max_size 是编译期常量
   const size_t max_size = 1024;
   char buf[max_size];
   // buf 大小由编译期常量决定，非外部输入
   ```
3. **上游已验证**: 输入经过上层验证框架（如请求过滤器、网关）处理
   ```c
   // 不报告：filter 已对所有输入执行验证
   if (security_filter(input)) {  // 已验证
       handler(input);  // handler 接收已验证数据
   }
   ```
   - 注意：需要确认 `security_filter()` 的验证是充分的（白名单/类型/范围/长度）
4. **白名单强制的枚举**: 输入通过枚举/switch 映射到有限安全值集合
   ```c
   // 不报告：输入被映射到预定义的安全动作集合
   action_t resolve_action(const char *name) {
       for (int i = 0; actions[i].name; i++) {
           if (strcmp(name, actions[i].name) == 0)
               return actions[i].id;  // 仅返回已知安全值
       }
       return ACTION_DEFAULT;  // 默认安全值
   }
   ```

## 边界情况

1. **strtol 的 endptr 检查不完整**: 如果只检查 `endptr == input` 但不检查 `*endptr != '\0'`，部分解析会被接受 → 降级为 suspicious
2. **errno 检查替代**: 只用 errno 判断 strtol 错误（errno 需在调用前清零）→ 降级为 suspicious
3. **间接验证**: 输入先通过查找表映射后再使用 → 如果映射失败会返回错误，则安全

## CWE 映射

| CWE | 说明 | 本规则覆盖 |
|-----|------|-----------|
| CWE-20 | Improper Input Validation | 核心覆盖 |
| CWE-129 | Improper Validation of Array Index | 索引验证 |
| CWE-190 | Integer Overflow or Wraparound | 数值验证 |
| CWE-1284 | Improper Validation of Specified Quantity in Input | 数量验证 |

## SEI CERT C 参考

- **STR31-C**: Guarantee that storage for strings has sufficient space for character data and the null terminator
- **STR32-C**: Do not pass a non-null-terminated character sequence to a library function that expects a string
- **INT04-C**: Enforce limits on integer values originating from tainted sources
- **ARR30-C**: Do not form or use out-of-bounds pointers or array subscripts
