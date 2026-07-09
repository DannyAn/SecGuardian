# 输入验证跨函数追踪

## 规则

当外部输入值通过函数参数传递到目标函数时，追踪目标函数内部是否执行验证。

### 最大深度: 1 层

```c
void handler(char *input) {
    process_input(input);  // 传入被调用函数
}

void process_input(char *data) {
    // 检查 process_input 内部是否有验证
    // 若无验证则报告
    system(data);  // 无验证 → 命令注入
}
```

### 深度上限

超过 depth 1 的调用链 → 降级为 suspicious。

## 常见转移模式

1. **配置文件读取 → 解析函数**: main() → read_config() → parse_value() → 最终使用
2. **网络数据 → 处理链**: recv() → parse_packet() → process_payload() → 最终使用
3. **环境变量 → 工厂函数**: getenv() → create_ctx() → 使用
