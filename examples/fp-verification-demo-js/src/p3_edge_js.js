// P3 — Edge Cases: 部分保护不充分
const { exec } = require('child_process');

const BLACKLIST = ['rm', 'shutdown', 'del'];

// P3-01: 黑名单过滤但不充分
function execCommand(input) {
    for (const bad of BLACKLIST) {
        if (input.includes(bad)) return 'blocked';
    }
    exec(input, (err, stdout) => {});  // shell=true 可绕过
}

// P3-02: 部分验证
function validateUrl(url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
        return fetch(url);  // 未校验 SSRF
    }
    throw new Error('Invalid URL');
}
