// P2 — 反证搜寻

// P2-01: try/finally 资源释放 — 非泄漏
function safeResource() {
    const handle = { close: () => {} };
    try {
        // 使用资源
    } finally {
        handle.close();
    }
}

let counter = 0;
let counterLock = false;

// P2-02: 锁保护 — 非竞争
async function safeIncrement() {
    while (counterLock) await new Promise(r => setTimeout(r, 1));
    counterLock = true;
    counter++;
    counterLock = false;
    return counter;
}

// P2-03: for 循环边界检查 — 非溢出
function safeCopy(dst, src, len) {
    for (let i = 0; i < len && i < dst.length && i < src.length; i++) {
        dst[i] = src[i];
    }
}

// P2-04: Number.isInteger 类型检查 — 非注入
function processId(input) {
    if (!Number.isInteger(input)) throw new Error('Invalid');
    return input;
}
