/**
 * execlike.js — Code execution & injection vulnerability examples (Node.js)
 *






 */

const { exec, execSync, spawn } = require('child_process');
const vm = require('vm');

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badExecShell(userInput) {

    const cmd = `ping -c 1 ${userInput}`;
    return execSync(cmd).toString();
    // Attacker: userInput = '8.8.8.8; cat /etc/passwd'
}

function badExecOptions(userCmd) {

    const child = exec(userCmd, { shell: true }, (err, stdout, stderr) => {
        console.log(stdout);
    });
    // Attacker: userCmd = 'rm -rf /'
}

function badSpawnShell(userInput) {

    const parts = userInput.split(' ');
    const child = spawn(parts[0], parts.slice(1), { shell: true });
    return child;
}

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badEval(userExpr) {

    return eval(userExpr);
    // Attacker: userExpr = 'process.exit()' or 'require("child_process").exec("id")'
}

function badFunctionConstructor(userCode) {

    const fn = new Function('data', userCode);
    return fn({});
    // Attacker: userCode = 'return require("fs").readFileSync("/etc/passwd","utf8")'
}

function badSetTimeout(userCode) {

    setTimeout(userCode, 1000);
    // Attacker: userCode = 'require("child_process").exec("rm -rf /")'
}

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badVMRun(userCode) {

    const sandbox = { result: null };
    vm.createContext(sandbox);
    vm.runInContext(userCode, sandbox);
    // Even with sandbox, prototype chain can escape
    return sandbox.result;
}

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badMerge(target, source) {

    for (const key in source) {
        if (typeof source[key] === 'object' && source[key] !== null) {
            if (!target[key]) target[key] = {};
            badMerge(target[key], source[key]);
        } else {
            target[key] = source[key];  // __proto__.isAdmin = true possible!
        }
    }
    return target;
}

function badSetNestedProperty(obj, path, value) {

    const parts = path.split('.');
    let current = obj;
    for (let i = 0; i < parts.length - 1; i++) {
        if (!current[parts[i]]) current[parts[i]] = {};
        current = current[parts[i]];
    }
    current[parts[parts.length - 1]] = value;
    // Attacker: path = '__proto__.isAdmin', value = true
    return obj;
}

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badUpdateUser(id, userInput) {

    const updates = { ...userInput };
    return db.users.update({ id }, { $set: updates });
    // Attacker sends: {"role": "admin", "isAdmin": true, "verified": true}
}

function badCreateUser(userInput) {

    const user = {
        username: userInput.username,
        password: userInput.password,
        role: userInput.role || 'user',       // role from client!
        isAdmin: userInput.isAdmin || false,   // isAdmin from client!
        credits: userInput.credits || 0        // credits from client!
    };
    return db.users.insert(user);
}

// ═══════════════════════════════════════════
// CORRECTED VERSIONS
// ═══════════════════════════════════════════

function goodExecPing(host) {
    // Use execFile (no shell) with argument array
    const { execFileSync } = require('child_process');
    if (!/^[a-zA-Z0-9.-]+$/.test(host)) {
        throw new Error('Invalid host');
    }
    return execFileSync('ping', ['-c', '1', host]).toString();
}

function goodSafeEval(expression) {
    // Use a math-only expression parser, never eval
    const allowed = /^[\d\s+\-*/().]+$/;
    if (!allowed.test(expression)) {
        throw new Error('Expression contains disallowed characters');
    }
    return Function('"use strict"; return (' + expression + ')')();
}

function goodMerge(target, source) {
    // Block __proto__, constructor, prototype keys
    const blocked = ['__proto__', 'constructor', 'prototype'];
    for (const key in source) {
        if (blocked.includes(key)) continue;
        if (typeof source[key] === 'object' && source[key] !== null && !Array.isArray(source[key])) {
            if (!target[key] || typeof target[key] !== 'object') target[key] = {};
            goodMerge(target[key], source[key]);
        } else {
            target[key] = source[key];
        }
    }
    return target;
}

function goodCreateUser(userInput) {
    // Whitelist approach: only extract expected fields
    const user = {
        username: userInput.username,
        password: userInput.password,
        role: 'user',        // Always default, never from client
        isAdmin: false,       // Always false for new users
        credits: 0            // Always 0 for new users
    };
    return db.users.insert(user);
}

module.exports = {
    badExecShell, badExecOptions, badSpawnShell,
    badEval, badFunctionConstructor, badSetTimeout, badVMRun,
    badMerge, badSetNestedProperty, badUpdateUser, badCreateUser,
    goodExecPing, goodSafeEval, goodMerge, goodCreateUser
};
