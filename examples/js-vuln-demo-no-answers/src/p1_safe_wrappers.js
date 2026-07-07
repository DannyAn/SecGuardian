

class SafeQuery {
    static query(db, sql, ...params) {
        return db.query(sql, params);
    }
}


function findUser(db, userId) {
    return SafeQuery.query(db, 'SELECT * FROM users WHERE id = ?', userId);
}


function safeRead(base, name) {
    const path = require('path');
    const resolved = path.resolve(base, path.basename(name));
    if (!resolved.startsWith(path.resolve(base))) {
        throw new Error('Path traversal');
    }
    return require('fs').readFileSync(resolved, 'utf8');
}
