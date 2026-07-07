// TP — True Positives: 真实漏洞
const { exec } = require('child_process');

// TP-01: SQL 注入 — 模板字符串拼接
function vulnerableQuery(db, userId) {
    return db.query(`SELECT * FROM users WHERE id = ${userId}`);
}

// TP-02: 命令注入 — shell 拼接
function vulnerableExec(input) {
    exec(`ping ${input}`, (err, stdout) => {});
}
