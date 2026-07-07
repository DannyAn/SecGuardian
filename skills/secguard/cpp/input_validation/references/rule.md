# 输入验证规则定义

## 核心规则

所有外部输入（环境变量、标准输入、文件、网络、命令行参数）在使用于安全敏感操作前，必须经过验证。

## 漏洞模式

### 模式 1: getenv 无 NULL 检查
```c
// BAD: getenv 可能返回 NULL
char *home = getenv("HOME");
strcpy(buf, home);  // home=NULL → 段错误

// GOOD
char *home = getenv("HOME");
if (home == NULL) return -1;
if (strlen(home) >= sizeof(buf)) return -1;
strcpy(buf, home);
```

### 模式 2: scanf 无宽度限制
```c
// BAD
scanf("%s", buf);           // 缓冲区溢出

// GOOD
scanf("%63s", buf);         // 限制读入最大 63 字符
```

### 模式 3: atoi/atol 无错误检测
```c
// BAD: atoi 无法区分错误和 0
int n = atoi(argv[1]);
malloc(n);                  // n 可为负或 0

// GOOD: strtol 有错误检测
char *endptr;
long n = strtol(argv[1], &endptr, 10);
if (endptr == argv[1]) return -1;  // 非数字
if (n <= 0 || n > MAX_SIZE) return -1;
malloc((size_t)n);
```

### 模式 4: sscanf 解析后未验证结果
```c
// BAD
int port;
sscanf(input, "%d", &port);
connect(sock, &addr, port);  // port 可被恶意控制

// GOOD
int port;
if (sscanf(input, "%d", &port) != 1) return -1;
if (port < 1024 || port > 65535) return -1;
```

## 安全变体审计

1. getenv 返回值必须检查 NULL 和长度
2. atoi 返回值不能直接用于内存分配/数组索引
3. scanf %s 必须指定宽度
4. strtol 必须检查 endptr 和范围
5. 外部输入用于文件路径时必须做路径遍历防护
