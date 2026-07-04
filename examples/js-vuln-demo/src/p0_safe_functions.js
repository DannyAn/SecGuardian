// P0 — 安全函数
const crypto = require('crypto');
const { execFile } = require('child_process');
const path = require('path');

// P0-01: 参数化查询（模拟）
function safeQuery(db, userId) {
    return db.query('SELECT * FROM users WHERE id = ?', [userId]);
}

// P0-02: crypto.randomBytes — 密码学安全
function generateToken() {
    return crypto.randomBytes(32).toString('hex');
}

// P0-03: execFile 列表参数 — 非注入
function safeExec() {
    execFile('ls', ['-l'], (err, stdout) => {});
}

// P0-04: console.log 占位符 — 安全
function logEvent(user) {
    console.log('User login: %s', user);
}

// P0-05: path.normalize — 路径遍历防御
function isSafePath(base, input) {
    const resolved = path.resolve(base, input);
    return resolved.startsWith(path.resolve(base));
}

// P0-06: JSON.stringify — 安全序列化
function safeStringify(data) {
    return JSON.stringify(data);
}
