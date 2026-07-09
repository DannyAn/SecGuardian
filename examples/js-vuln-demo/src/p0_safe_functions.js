
const crypto = require('crypto');
const { execFile } = require('child_process');
const path = require('path');


function safeQuery(db, userId) {
    return db.query('SELECT * FROM users WHERE id = ?', [userId]);
}


function generateToken() {
    return crypto.randomBytes(32).toString('hex');
}


function safeExec() {
    execFile('ls', ['-l'], (err, stdout) => {});
}


function logEvent(user) {
    console.log('User login: %s', user);
}


function isSafePath(base, input) {
    const resolved = path.resolve(base, input);
    return resolved.startsWith(path.resolve(base));
}


function safeStringify(data) {
    return JSON.stringify(data);
}
