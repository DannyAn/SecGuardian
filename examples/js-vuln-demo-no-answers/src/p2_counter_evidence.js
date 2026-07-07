


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


async function safeIncrement() {
    while (counterLock) await new Promise(r => setTimeout(r, 1));
    counterLock = true;
    counter++;
    counterLock = false;
    return counter;
}


function safeCopy(dst, src, len) {
    for (let i = 0; i < len && i < dst.length && i < src.length; i++) {
        dst[i] = src[i];
    }
}


function processId(input) {
    if (!Number.isInteger(input)) throw new Error('Invalid');
    return input;
}
