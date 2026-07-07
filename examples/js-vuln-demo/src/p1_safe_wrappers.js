// P1 — 安全框架抑制

class SafeQuery {
    static query(db, sql, ...params) {
        return db.query(sql, params);
    }
}

// P1-01: SafeQuery 包装保证参数化
function findUser(db, userId) {
    return SafeQuery.query(db, 'SELECT * FROM users WHERE id = ?', userId);
}

// P1-02: 路径安全拼接
function safeRead(base, name) {
    const path = require('path');
    const resolved = path.resolve(base, path.basename(name));
    if (!resolved.startsWith(path.resolve(base))) {
        throw new Error('Path traversal');
    }
    return require('fs').readFileSync(resolved, 'utf8');
}
